const admin = require("firebase-admin");
admin.initializeApp();

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten, onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
// TODO: Uncomment when ready to add SendGrid for email digests (free tier: 100 emails/day)
// const { defineSecret } = require("firebase-functions/params");
// const sgMail = require("@sendgrid/mail");

const db = admin.firestore();
const friendProfiles = require("./friend_profiles")(admin);
const {
  FRIEND_STATS_DOC_ID,
  refreshFriendProfile,
  deleteFriendProfile,
  collectShareableUserRoles,
  upsertWalkSummaryForUser,
  deleteWalkSummaryForUser,
  enforceWalkSummaryLimit,
} = friendProfiles;

// TODO: Uncomment when ready to add SendGrid
// const sendgridApiKey = defineSecret("SENDGRID_API_KEY");
// const DIGEST_FROM_EMAIL = process.env.DIGEST_FROM_EMAIL || "no-reply@yallanemshi.app";
// const DIGEST_FROM_NAME = "Yalla Nemshi";

// ===== SET GLOBAL REGION FOR HTTPS AND HTTPS-CALLABLE FUNCTIONS =====
// HTTPS functions can be in europe-west1 (closer to Middle East)
// Firestore-triggered functions will override this in cp4_walk_completion.js
setGlobalOptions({ region: "europe-west1" });

// ===== HELPER FUNCTIONS =====

/**
 * Send FCM notification to a user
 * @param {string} userId - User ID to send notification to
 * @param {Object} notification - Notification object with title and body
 * @param {Object} data - Optional data payload
 * @param {string} context - String used for log correlation
 */
async function sendNotificationToUser(userId, notification, data = {}, context = "general") {
  try {
    const db = admin.firestore();
    const tokensSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("fcmTokens")
      .get();

    if (tokensSnapshot.empty) {
      console.log(`[${context}] No FCM tokens found for user: ${userId}`);
      return;
    }

    const tokens = tokensSnapshot.docs.map((doc) => doc.data().token);
    console.log(`📨 [${context}] Preparing notification for user ${userId} (${tokens.length} tokens)`);

    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: data,
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ [${context}] Sent ${response.successCount} notifications to user ${userId}`);

    response.responses.forEach((resp, idx) => {
      const tokenPreview = tokens[idx] ? `${tokens[idx].substring(0, 12)}...` : 'unknown';
      if (resp.success) {
        console.log(`   ↳ Delivered to token ${tokenPreview}`);
      } else {
        console.error(`   ↳ Failed token ${tokenPreview}: ${resp.error?.code || resp.error}`);
      }
    });

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const batch = db.batch();
      response.responses.forEach((resp, idx) => {
        if (!resp.success && tokens[idx]) {
          const tokenRef = db
            .collection("users")
            .doc(userId)
            .collection("fcmTokens")
            .doc(tokens[idx]);
          batch.delete(tokenRef);
        }
      });
      await batch.commit();
      console.log(`🗑️ [${context}] Cleaned up ${response.failureCount} invalid tokens`);
    }
  } catch (error) {
    console.error(`❌ [${context}] Error sending notification to user ${userId}:`, error);
  }
}

// Export sendNotificationToUser for use in other modules
module.exports.sendNotificationToUser = sendNotificationToUser;

exports.redeemInviteCode = onCall(async (request) => {
  // ✅ Must be signed in
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const uid = request.auth.uid;
  const walkId = (request.data?.walkId || "").toString().trim();
  const shareCode = (request.data?.shareCode || "").toString().trim().toUpperCase();

  if (!walkId) {
    throw new HttpsError("invalid-argument", "walkId is required.");
  }
  if (!shareCode) {
    throw new HttpsError("invalid-argument", "shareCode is required.");
  }

  const db = admin.firestore();
  const walkRef = db.collection("walks").doc(walkId);
  const walkSnap = await walkRef.get();

  if (!walkSnap.exists) {
    throw new HttpsError("not-found", "Walk not found.");
  }

  const walk = walkSnap.data() || {};

  // ✅ Only private walks should be redeemable
  if (walk.visibility !== "private") {
    throw new HttpsError("failed-precondition", "This walk is not private.");
  }

  // ✅ Verify code
  const stored = (walk.shareCode || "").toString().trim().toUpperCase();
  if (!stored || stored !== shareCode) {
    throw new HttpsError("permission-denied", "Invalid invite code.");
  }

  const rawExpiry = walk.shareCodeExpiresAt;
  if (rawExpiry) {
    const expiresAt = typeof rawExpiry.toDate === "function"
      ? rawExpiry.toDate()
      : new Date(rawExpiry);

    if (Number.isNaN(expiresAt.getTime())) {
      console.warn(
        `⚠️ shareCodeExpiresAt malformed for walk ${walkId}:`,
        rawExpiry,
      );
    } else if (expiresAt.getTime() < Date.now()) {
      throw new HttpsError("failed-precondition", "This invite has expired.");
    }
  }

  // ✅ Mark this user as allowed (rules allow them to read the walk)
  await walkRef.collection("allowed").doc(uid).set(
    {
      uid,
      walkId,
      redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { ok: true };
});

// Temporary alias to avoid breaking older clients while the app rolls out the new callable name
exports.redeemWalkInvite = exports.redeemInviteCode;

exports.revokeWalkInvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'You must be logged in.');
  }

  const hostUid = request.auth.uid;
  const walkId = (request.data?.walkId || '').toString().trim();
  const targetUid = (request.data?.userId || '').toString().trim();

  if (!walkId) {
    throw new HttpsError('invalid-argument', 'walkId is required.');
  }
  if (!targetUid) {
    throw new HttpsError('invalid-argument', 'userId is required.');
  }

  const db = admin.firestore();
  const walkRef = db.collection('walks').doc(walkId);
  const walkSnap = await walkRef.get();

  if (!walkSnap.exists) {
    throw new HttpsError('not-found', 'Walk not found.');
  }

  const walk = walkSnap.data() || {};
  if (walk.hostUid !== hostUid) {
    throw new HttpsError(
      'permission-denied',
      'Only the host can revoke invites for this walk.',
    );
  }

  const inviteRef = walkRef.collection('allowed').doc(targetUid);
  const inviteSnap = await inviteRef.get();

  if (!inviteSnap.exists) {
    throw new HttpsError('not-found', 'Invite not found.');
  }

  await inviteRef.delete();
  console.log(
    `🔐 Host ${hostUid} revoked invite for ${targetUid} on walk ${walkId}`,
  );

  return { ok: true };
});

// ===== FRIEND PROFILE SNAPSHOTS =====

exports.onFriendProfileUserSync = onDocumentWritten("users/{userId}", async (event) => {
  const uid = event.params.userId;

  if (!event.data?.after?.exists) {
    await deleteFriendProfile(uid);
    return;
  }

  try {
    await refreshFriendProfile(uid);
  } catch (error) {
    console.error(`❌ Failed to sync friend profile (user change) for ${uid}`, error);
  }
});

exports.onFriendProfileStatsSync = onDocumentWritten("users/{userId}/stats/{statId}", async (event) => {
  if (event.params.statId !== FRIEND_STATS_DOC_ID) {
    return;
  }

  const uid = event.params.userId;

  if (!event.data?.after?.exists) {
    // Stats doc removed; still refresh to keep counts in sync
    try {
      await refreshFriendProfile(uid);
    } catch (error) {
      console.error(`❌ Failed to sync friend profile after stats removal for ${uid}`, error);
    }
    return;
  }

  try {
    await refreshFriendProfile(uid);
  } catch (error) {
    console.error(`❌ Failed to sync friend profile (stats change) for ${uid}`, error);
  }
});

exports.onFriendWalkSummarySync = onDocumentWritten("walks/{walkId}", async (event) => {
  const walkId = event.params.walkId;
  const beforeData = event.data?.before?.data();
  const afterData = event.data?.after?.data();

  const beforeRoles = collectShareableUserRoles(beforeData);
  const afterRoles = collectShareableUserRoles(afterData);

  const operations = [];
  const pruneTargets = new Set();

  afterRoles.forEach((role, uid) => {
    operations.push(upsertWalkSummaryForUser(uid, walkId, afterData, role));
    pruneTargets.add(uid);
  });

  beforeRoles.forEach((_, uid) => {
    if (!afterRoles.has(uid)) {
      operations.push(deleteWalkSummaryForUser(uid, walkId));
    }
  });

  if (operations.length === 0) {
    return;
  }

  try {
    await Promise.all(operations);
    if (pruneTargets.size > 0) {
      await Promise.all([...pruneTargets].map((uid) => enforceWalkSummaryLimit(uid)));
    }
  } catch (error) {
    console.error(`❌ Failed syncing friend walk summaries for ${walkId}`, error);
  }
});

// ===== FCM NOTIFICATION TRIGGERS =====

/**
 * Trigger: When a user joins a walk (joins walk/participants subcollection)
 * Action: Notify the walk host
 */
exports.onWalkJoined = onDocumentWritten("users/{userId}/walks/{walkId}", async (event) => {
  const data = event.data?.after?.data();
  
  // Only trigger on creation (user joined)
  if (!event.data?.after?.exists || event.data?.before?.exists) {
    return;
  }

  const userId = event.params.userId;
  const walkId = event.params.walkId;

  try {
    const db = admin.firestore();
    
    // Get walk details
    const walkSnap = await db.collection("walks").doc(walkId).get();
    if (!walkSnap.exists) return;
    
    const walk = walkSnap.data();
    const hostUid = walk.hostUid;
    
    // Don't notify if host joins their own walk
    if (hostUid === userId) return;
    
    // Get user details
    const userSnap = await db.collection("users").doc(userId).get();
    const user = userSnap.exists ? userSnap.data() : {};
    const userName = user.displayName || "Someone";
    
    const notificationData = {
      type: "walk_joined",
      walkId: walkId,
      userId: userId,
    };
    
    // Send FCM notification to host
    await sendNotificationToUser(
      hostUid,
      {
        title: "New walker joined! 🎉",
        body: `${userName} joined your walk "${walk.title}"`,
      },
      notificationData,
      "walk_joined"
    );
    
    // Write notification to Firestore
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // Expire in 30 days
    
    await db.collection("users").doc(hostUid).collection("notifications").add({
      type: "walkJoined",
      title: "New walker joined! 🎉",
      message: `${userName} joined your walk "${walk.title}"`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      walkId: walkId,
      userId: userId,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });
    
    console.log(`✅ Notified host ${hostUid} about ${userId} joining walk ${walkId}`);
  } catch (error) {
    console.error("❌ Error in onWalkJoined:", error);
  }
});

/**
 * Trigger: When a walk is cancelled (cancelled field set to true)
 * Action: Notify all participants
 */
exports.onWalkCancelled = onDocumentUpdated("walks/{walkId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  
  // Only trigger when walk is newly cancelled
  if (!after || after.cancelled !== true || before?.cancelled === true) {
    return;
  }

  const walkId = event.params.walkId;
  
  try {
    const db = admin.firestore();
    const walk = after;
    const hostUid = walk.hostUid;
    const joinedUserUids = walk.joinedUserUids || [];
    
    // Notify all participants except the host
    const participantsToNotify = joinedUserUids.filter(uid => uid !== hostUid);
    
    if (participantsToNotify.length === 0) {
      console.log("No participants to notify for cancelled walk");
      return;
    }
    
    // Send notifications in parallel
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // 30 days expiry
    
    await Promise.all(
      participantsToNotify.map(async (uid) => {
        // Send FCM notification
        await sendNotificationToUser(
          uid,
          {
            title: "Walk cancelled ❌",
            body: `The walk "${walk.title}" has been cancelled`,
          },
          {
            type: "walk_cancelled",
            walkId: walkId,
          }
        );
        
        // Write notification to Firestore
        await db.collection("users").doc(uid).collection("notifications").add({
          type: "walkCancelled",
          title: "Walk cancelled ❌",
          message: `The walk "${walk.title}" has been cancelled`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          walkId: walkId,
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        });
      })
    );
    
    console.log(`✅ Notified ${participantsToNotify.length} participants about walk cancellation`);
  } catch (error) {
    console.error("❌ Error in onWalkCancelled:", error);
  }
});

// ===== MONTHLY DIGEST SCHEDULER =====
const COMPLETED_STATES = new Set([
  "completed",
  "completed_early",
  "completed_late",
  "ended",
]);
const SIX_HOURS_MS = 6 * 60 * 60 * 1000;

// TODO: Uncomment when SendGrid is configured - monthly email digests
/* 
exports.sendMonthlyDigests = onSchedule(
  {
    schedule: "0 6 1 * *", // 06:00 UTC on the first of every month
    region: "europe-west1",
    timeZone: "UTC",
    secrets: [sendgridApiKey],
  },
  async () => {
    const window = getPreviousMonthWindow();
    const apiKey = sendgridApiKey.value();
    if (!apiKey) {
      console.error(
        "❌ [Digest] SENDGRID_API_KEY is not configured. Skipping monthly digests to avoid partial logs."
      );
      return;
    }
    sgMail.setApiKey(apiKey);

    console.log(`📬 [Digest] Starting run for ${window.yearMonth} (${window.label})`);
    const optInSnapshot = await db
      .collection("users")
      .where("monthlyDigestEnabled", "==", true)
      .get();

    console.log(`📬 [Digest] Found ${optInSnapshot.size} opted-in users`);
    for (const userDoc of optInSnapshot.docs) {
      // eslint-disable-next-line no-await-in-loop
      await processMonthlyDigestForUser(userDoc, window);
    }

    console.log(`📬 [Digest] Completed run for ${window.yearMonth}`);
  }
);
*/

/* Temporarily commented out - digest helper functions
async function processMonthlyDigestForUser(userDoc, window) {
  const uid = userDoc.id;
  const userData = userDoc.data() || {};
  const email = (userData.email || "").trim();

  if (!email) {
    console.log(`ℹ️ [Digest] Skipping ${uid} — no email on file.`);
    return;
  }

  const logRef = db.collection("digest_logs").doc(`${uid}_${window.yearMonth}`);
  const logSnap = await logRef.get();
  if (logSnap.exists) {
    const logData = logSnap.data() || {};
    if (logData.status === "sent") {
      console.log(`ℹ️ [Digest] Skipping ${uid} — already sent for ${window.yearMonth}.`);
      return;
    }
    if (
      logData.status === "sending" &&
      logData.updatedAt?.toDate &&
      Date.now() - logData.updatedAt.toDate().getTime() < SIX_HOURS_MS
    ) {
      console.log(`ℹ️ [Digest] Skipping ${uid} — existing run still in progress.`);
      return;
    }
  }

  await logRef.set(
    {
      uid,
      yearMonth: window.yearMonth,
      status: "sending",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  try {
    const walks = await loadMonthlyWalks(uid, window.start, window.end);
    const stats = buildDigestStats(walks, window.monthLabel);

    await sendDigestEmail({
      email,
      displayName: userData.displayName || userData.email,
      monthLabel: window.label,
      stats,
    });

    await logRef.set(
      {
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        totals: {
          totalWalks: stats.totalWalks,
          totalDistanceKm: stats.totalDistanceKm,
          totalMinutes: stats.totalMinutes,
          averagePace: stats.averagePace,
        },
        highlights: {
          bestDay: stats.bestDay,
          bestWeek: stats.bestWeek,
          longestWalk: stats.longestWalk,
          fastestPace: stats.fastestPace,
          mostRecentWalk: stats.mostRecentWalk,
        },
      },
      { merge: true }
    );

    console.log(`✅ [Digest] Sent monthly digest to ${email} for ${window.yearMonth}`);
  } catch (error) {
    console.error(`❌ [Digest] Failed digest for ${uid}`, error);
    await logRef.set(
      {
        status: "error",
        errorMessage: error?.message || String(error),
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
}

async function loadMonthlyWalks(uid, startDate, endDate) {
  const walksRef = db.collection("users").doc(uid).collection("walks");
  const startTs = admin.firestore.Timestamp.fromDate(startDate);
  const endTs = admin.firestore.Timestamp.fromDate(endDate);

  const docs = new Map();

  const [joinedSnap, completedSnap] = await Promise.all([
    walksRef
      .where("joinedAt", ">=", startTs)
      .where("joinedAt", "<", endTs)
      .orderBy("joinedAt")
      .get(),
    walksRef
      .where("completedAt", ">=", startTs)
      .where("completedAt", "<", endTs)
      .orderBy("completedAt")
      .get(),
  ]);

  joinedSnap.forEach((doc) => docs.set(doc.id, doc.data()));
  completedSnap.forEach((doc) => docs.set(doc.id, doc.data()));

  const completed = [];
  docs.forEach((data, id) => {
    if (isCompletedEntry(data)) {
      completed.push({ id, data });
    }
  });

  return completed;
}

function isCompletedEntry(data) {
  if (!data) return false;
  if (data.completed === true) return true;
  if (data.completedAt) return true;
  const status = (data.status || "").toString().toLowerCase();
  return COMPLETED_STATES.has(status);
}

function buildDigestStats(walks, monthLabel) {
  let totalDistance = 0;
  let totalMinutes = 0;
  const dayTotals = new Map();
  const weekTotals = new Map();
  let longestWalk = null;
  let fastestPace = null;
  let mostRecentWalk = null;

  walks.forEach(({ id, data }) => {
    const distance = getDistanceKm(data);
    const durationMinutes = resolveDurationMinutes(data);
    const completedAt = getCompletionDate(data);

    totalDistance += distance;
    totalMinutes += durationMinutes;

    const dayKey = formatShortDate(completedAt);
    dayTotals.set(dayKey, (dayTotals.get(dayKey) || 0) + distance);

    const weekBucket = getWeekBucket(completedAt);
    const existingWeek = weekTotals.get(weekBucket.key) || {
      label: weekBucket.label,
      distance: 0,
    };
    existingWeek.distance += distance;
    weekTotals.set(weekBucket.key, existingWeek);

    if (!longestWalk || distance > longestWalk.distanceKm) {
      longestWalk = {
        walkId: id,
        distanceKm: distance,
        date: completedAt,
      };
    }

    if (distance > 0 && durationMinutes > 0) {
      const pace = durationMinutes / distance;
      if (!fastestPace || pace < fastestPace.pace) {
        fastestPace = {
          walkId: id,
          pace,
          distanceKm: distance,
          date: completedAt,
        };
      }
    }

    if (!mostRecentWalk || completedAt > mostRecentWalk.date) {
      mostRecentWalk = {
        walkId: id,
        distanceKm: distance,
        date: completedAt,
      };
    }
  });

  const averagePace = totalDistance > 0 ? totalMinutes / totalDistance : 0;
  const bestDay = pickTopEntry(dayTotals, (label, distanceKm) => ({
    label,
    distanceKm: distanceKm.toFixed(2),
  }));
  const bestWeek = pickTopEntry(weekTotals, (key, aggregate) => ({
    label: aggregate.label,
    distanceKm: aggregate.distance.toFixed(2),
  }));

  return {
    totalWalks: walks.length,
    totalDistanceKm: Number(totalDistance.toFixed(2)),
    totalMinutes: Math.round(totalMinutes),
    averagePace,
    bestDay,
    bestWeek,
    longestWalk,
    fastestPace,
    mostRecentWalk,
    monthLabel,
  };
}

function pickTopEntry(map, mapper) {
  let bestKey = null;
  let bestValue = -Infinity;
  map.forEach((value, key) => {
    const numeric = typeof value === "number" ? value : value.distance;
    if (numeric > bestValue) {
      bestValue = numeric;
      bestKey = key;
    }
  });

  if (bestKey == null) {
    return null;
  }

  return mapper(bestKey, map.get(bestKey));
}

function getDistanceKm(data) {
  const fields = [
    data.actualDistanceKm,
    data.distanceKm,
    data.plannedDistanceKm,
  ];
  const value = fields.find((num) => typeof num === "number");
  return value ? Number(value) : 0;
}

function resolveDurationMinutes(data) {
  if (typeof data.actualDurationMinutes === "number") {
    return data.actualDurationMinutes;
  }
  if (typeof data.actualDuration === "number") {
    return Math.round(data.actualDuration / 60);
  }
  if (data.confirmedAt?.toDate && data.completedAt?.toDate) {
    const confirmed = data.confirmedAt.toDate();
    const completed = data.completedAt.toDate();
    return Math.max(0, Math.round((completed - confirmed) / 60000));
  }
  if (typeof data.plannedDurationMinutes === "number") {
    return data.plannedDurationMinutes;
  }
  return 0;
}

function getCompletionDate(data) {
  if (data.completedAt?.toDate) {
    return data.completedAt.toDate();
  }
  if (data.joinedAt?.toDate) {
    return data.joinedAt.toDate();
  }
  return new Date();
}

function getWeekBucket(date) {
  const dayOfWeek = date.getUTCDay();
  const diffToMonday = (dayOfWeek + 6) % 7;
  const start = new Date(
    Date.UTC(
      date.getUTCFullYear(),
      date.getUTCMonth(),
      date.getUTCDate() - diffToMonday
    )
  );
  const end = new Date(start.getTime() + 6 * 24 * 60 * 60 * 1000);
  const key = `${start.getUTCFullYear()}-${String(start.getUTCMonth() + 1).padStart(2, "0")}-${String(
    start.getUTCDate()
  ).padStart(2, "0")}`;
  const label = `${formatShortDate(start)} – ${formatShortDate(end)}`;
  return { key, label };
}

function formatShortDate(date) {
  const month = new Intl.DateTimeFormat("en", { month: "short" }).format(date);
  return `${month} ${String(date.getUTCDate()).padStart(2, "0")}`;
}

function formatDuration(totalMinutes) {
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours === 0) {
    return `${minutes} min`;
  }
  return `${hours}h ${minutes}m`;
}

function formatPace(paceMinutes) {
  if (!paceMinutes || !Number.isFinite(paceMinutes)) {
    return "–";
  }
  const minutes = Math.floor(paceMinutes);
  const seconds = Math.round((paceMinutes - minutes) * 60)
    .toString()
    .padStart(2, "0");
  return `${minutes}:${seconds} min/km`;
}

function buildDigestHtml({ displayName, monthLabel, stats }) {
  const highlights = [];
  if (stats.longestWalk) {
    highlights.push(
      `Longest walk: ${stats.longestWalk.distanceKm.toFixed(2)} km on ${formatShortDate(
        stats.longestWalk.date
      )}`
    );
  }
  if (stats.fastestPace) {
    highlights.push(
      `Fastest pace: ${formatPace(stats.fastestPace.pace)} over ${stats.fastestPace.distanceKm.toFixed(
        2
      )} km`
    );
  }
  if (stats.bestDay) {
    highlights.push(`Best day: ${stats.bestDay.label} (${stats.bestDay.distanceKm} km)`);
  }
  if (stats.bestWeek) {
    highlights.push(
      `Most active week: ${stats.bestWeek.label} (${stats.bestWeek.distanceKm} km)`
    );
  }
  if (stats.mostRecentWalk) {
    highlights.push(
      `Most recent walk: ${formatShortDate(stats.mostRecentWalk.date)} (${stats.mostRecentWalk.distanceKm.toFixed(
        2
      )} km)`
    );
  }

  if (highlights.length === 0) {
    highlights.push('No walk highlights this month — lace up and get moving!');
  }

  return `
    <div style="font-family: 'Inter', 'Segoe UI', Arial, sans-serif; max-width: 560px; margin: 0 auto;">
      <h2 style="color:#0f766e;">Hi ${displayName || 'walker'},</h2>
      <p>Here is your ${monthLabel} walking summary with Yalla Nemshi.</p>
      <table style="width:100%; border-collapse:collapse; margin:24px 0;">
        <tr>
          <td style="padding:8px 0; font-weight:600;">Total walks</td>
          <td style="text-align:right;">${stats.totalWalks}</td>
        </tr>
        <tr>
          <td style="padding:8px 0; font-weight:600;">Total distance</td>
          <td style="text-align:right;">${stats.totalDistanceKm.toFixed(2)} km</td>
        </tr>
        <tr>
          <td style="padding:8px 0; font-weight:600;">Total time</td>
          <td style="text-align:right;">${formatDuration(stats.totalMinutes)}</td>
        </tr>
        <tr>
          <td style="padding:8px 0; font-weight:600;">Average pace</td>
          <td style="text-align:right;">${formatPace(stats.averagePace)}</td>
        </tr>
      </table>
      <h3 style="color:#0f766e;">Highlights</h3>
      <ul>
        ${highlights.map((item) => `<li>${item}</li>`).join('')}
      </ul>
      <p>Keep walking and stay safe!<br/>— The Yalla Nemshi team</p>
    </div>
  `;
}

async function sendDigestEmail({ email, displayName, monthLabel, stats }) {
  const html = buildDigestHtml({ displayName, monthLabel, stats });
  await sgMail.send({
    to: email,
    from: {
      email: DIGEST_FROM_EMAIL,
      name: DIGEST_FROM_NAME,
    },
    subject: `Your ${monthLabel} walking summary`,
    html,
  });
}

function getPreviousMonthWindow() {
  const now = new Date();
  const startOfCurrentMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const startOfPreviousMonth = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1)
  );

  const label = new Intl.DateTimeFormat("en", { month: "long", year: "numeric" }).format(
    startOfPreviousMonth
  );
  const yearMonth = `${startOfPreviousMonth.getUTCFullYear()}-${String(
    startOfPreviousMonth.getUTCMonth() + 1
  ).padStart(2, "0")}`;

  return {
    start: startOfPreviousMonth,
    end: startOfCurrentMonth,
    label,
    yearMonth,
    monthLabel: label,
  };
}
*/
// End of commented SendGrid digest functions

/**
 * Trigger: When walk details are updated (title, dateTime, meetingPlace, etc.)
 * Action: Notify all participants
 */
exports.onWalkUpdated = onDocumentUpdated("walks/{walkId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  
  if (!before || !after) return;
  
  // Ignore if walk was just cancelled (handled by onWalkCancelled)
  if (after.cancelled === true && before.cancelled !== true) {
    return;
  }
  
  // Check if important fields changed (compare Timestamp values safely)
  const importantFields = ["title", "dateTime", "meetingPlaceName", "startLat", "startLng"];
  const normalizeValue = (value) =>
    value && typeof value.toMillis === "function" ? value.toMillis() : value;
  const statusChangedToActive = before.status !== after.status && after.status === "active";
  const hasImportantChange = statusChangedToActive || importantFields.some((field) =>
    normalizeValue(before[field]) !== normalizeValue(after[field])
  );
  
  if (!hasImportantChange) {
    return; // No important changes, don't spam notifications
  }

  const walkId = event.params.walkId;
  
  try {
    const walk = after;
    const hostUid = walk.hostUid;
    const joinedUserUids = walk.joinedUserUids || [];
    
    // Notify all participants except the host
    const participantsToNotify = joinedUserUids.filter(uid => uid !== hostUid);
    
    if (participantsToNotify.length === 0) {
      return;
    }
    
    // Determine what changed
    let changeDescription = "Details updated";
    let notificationTitle = "Walk updated 📝";
    let notificationType = "walkUpdated";
    let notificationDataType = "walkUpdated";
    if (statusChangedToActive) {
      changeDescription = "Please confirm you’re joining";
      notificationTitle = "Walk starting ⏰";
      notificationType = "walkStarting";
      notificationDataType = "walkStarting";
    } else if (normalizeValue(before.dateTime) !== normalizeValue(after.dateTime)) {
      changeDescription = "Time changed";
    } else if (before.meetingPlaceName !== after.meetingPlaceName || 
               normalizeValue(before.startLat) !== normalizeValue(after.startLat)) {
      changeDescription = "Location changed";
    } else if (before.title !== after.title) {
      changeDescription = "Title updated";
    }
    
    // Send notifications in parallel
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days expiry for updates
    
    await Promise.all(
      participantsToNotify.map(async (uid) => {
        // Send FCM notification
        await sendNotificationToUser(
          uid,
          {
            title: notificationTitle,
            body: `"${walk.title}" - ${changeDescription}`,
          },
          {
            type: notificationDataType,
            walkId: walkId,
            changeType: changeDescription,
          }
        );
        
        // Write notification to Firestore
        await db.collection("users").doc(uid).collection("notifications").add({
          type: notificationType,
          title: notificationTitle,
          message: `"${walk.title}" - ${changeDescription}`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          walkId: walkId,
          data: { changeType: changeDescription },
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        });
      })
    );
    
    console.log(`✅ Notified ${participantsToNotify.length} participants about walk update`);
  } catch (error) {
    console.error("❌ Error in onWalkUpdated:", error);
  }
});

/**
 * Trigger: New direct message created
 * Action: Notify the other participant(s) in the thread
 */
exports.onDmMessageCreated = onDocumentCreated(
  "dm_threads/{threadId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const senderId = message.senderId;
    if (!senderId) return;

    const threadId = event.params.threadId;

    try {
      const threadSnap = await db.collection("dm_threads").doc(threadId).get();
      if (!threadSnap.exists) {
        return;
      }

      const thread = threadSnap.data() || {};
      const rawParticipants = Array.isArray(thread.participants)
        ? thread.participants
        : Array.isArray(thread.memberIds)
          ? thread.memberIds
          : [];
      const recipients = rawParticipants.filter((uid) => uid && uid !== senderId);
      if (recipients.length === 0) {
        return;
      }

      console.log(
        `💬 DM notification trigger thread=${threadId} message=${event.params.messageId} sender=${senderId} recipients=${recipients.join(",")}`,
      );

      const participantProfiles = thread.participantProfiles || {};
      let senderProfile = participantProfiles[senderId] || {};
      const senderSnap = await db.collection("users").doc(senderId).get();
      if (senderSnap.exists) {
        senderProfile = { ...senderProfile, ...senderSnap.data() };
      }

      const senderName = senderProfile.displayName || "New message";
      const senderPhotoUrl = senderProfile.photoUrl || senderProfile.photoURL || "";

      let body;
      const messageType = message.type || message.mediaType;
      if (messageType === "image") {
        body = `${senderName} sent you a photo`;
      } else {
        const text = (message.text || "").toString();
        body = text.length > 120 ? `${text.substring(0, 117)}...` : text || "New message";
      }

      console.log(`📝 About to create notifications for recipients: ${JSON.stringify(recipients)}`);
      console.log(`📝 Sender ID: ${senderId}`);
      console.log(`📝 All participants from thread: ${JSON.stringify(rawParticipants)}`);

      await Promise.all(
        recipients.map(async (uid) => {
          console.log(`📝 Creating notification for recipient: ${uid}`);
          // Send FCM notification
          await sendNotificationToUser(
            uid,
            {
              title: senderName,
              body,
            },
            {
              type: "dm_message",
              threadId,
              senderId,
              senderName,
              senderPhotoUrl,
            },
            `dm:${threadId}:${event.params.messageId}`,
          );
          
          // Write notification to Firestore
          const expiresAt = new Date();
          expiresAt.setDate(expiresAt.getDate() + 30); // 30 days expiry
          
          await db.collection("users").doc(uid).collection("notifications").add({
            type: "dmMessage",
            title: senderName,
            message: body,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            threadId: threadId,
            userId: senderId,
            data: { senderPhotoUrl },
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          });
        }),
      );

      console.log(`✅ Sent DM notifications for thread ${threadId}`);
    } catch (error) {
      console.error("❌ Error in onDmMessageCreated:", error);
    }
  },
);

/**
 * Trigger: When a new chat message is created
 * Action: Notify all chat participants except the sender
 * 
 * Note: This assumes you have a chat messages collection structure like:
 * /walks/{walkId}/messages/{messageId}
 * 
 * If your chat structure is different, adjust accordingly.
 */
exports.onChatMessage = onDocumentWritten("walks/{walkId}/messages/{messageId}", async (event) => {
  const message = event.data?.after?.data();
  
  // Only trigger on new messages
  if (!event.data?.after?.exists || event.data?.before?.exists) {
    return;
  }

  const walkId = event.params.walkId;
  const senderId = message?.userId || message?.senderId;
  
  if (!senderId) {
    console.log("No sender ID found in message");
    return;
  }

  try {
    const db = admin.firestore();
    
    // Get walk details
    const walkSnap = await db.collection("walks").doc(walkId).get();
    if (!walkSnap.exists) return;
    
    const walk = walkSnap.data();
    const hostUid = walk.hostUid;
    const joinedUserUids = walk.joinedUserUids || [];
    
    // Get all participants (host + joined users)
    const allParticipants = [hostUid, ...joinedUserUids];
    const uniqueParticipants = [...new Set(allParticipants)];
    
    // Notify everyone except the sender
    const participantsToNotify = uniqueParticipants.filter(uid => uid !== senderId);
    
    if (participantsToNotify.length === 0) {
      return;
    }
    
    // Get sender name
    const senderSnap = await db.collection("users").doc(senderId).get();
    const sender = senderSnap.exists ? senderSnap.data() : {};
    const senderName = sender.displayName || "Someone";
    
    // Get message text (truncate if too long)
    const messageText = (message.text || message.content || "sent a message").substring(0, 100);
    
    // Send notifications in parallel
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days expiry for chat
    
    await Promise.all(
      participantsToNotify.map(async (uid) => {
        // Send FCM notification
        await sendNotificationToUser(
          uid,
          {
            title: `${senderName} • ${walk.title}`,
            body: messageText,
          },
          {
            type: "chat_message",
            walkId: walkId,
            senderId: senderId,
            messageId: event.params.messageId,
          }
        );
        
        // Write notification to Firestore
        await db.collection("users").doc(uid).collection("notifications").add({
          type: "chatMessage",
          title: `${senderName} • ${walk.title}`,
          message: messageText,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          walkId: walkId,
          userId: senderId,
          data: { messageId: event.params.messageId },
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        });
      })
    );
    
    console.log(`✅ Notified ${participantsToNotify.length} participants about new message`);
  } catch (error) {
    console.error("❌ Error in onChatMessage:", error);
  }
});

// ===== SCHEDULED MAINTENANCE =====

/**
 * Cleanup old GPS tracking data (runs daily at midnight UTC)
 * Deletes tracking subcollections for walks that ended more than 30 days ago
 * Keeps walk summary stats (distance, speed, etc.) but removes detailed GPS points
 * 
 * Privacy & Cost Optimization: GPS traces contain sensitive location data and 
 * consume significant storage. This function enforces a 30-day retention policy.
 */
exports.cleanupOldGpsData = onSchedule(
  {
    schedule: "0 0 * * *", // Daily at midnight UTC
    region: "europe-west1",
    timeZone: "UTC",
  },
  async () => {
    console.log("🧹 [GPS Cleanup] Starting daily GPS data cleanup");
    
    try {
      // Calculate cutoff date (30 days ago)
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      const cutoffTimestamp = admin.firestore.Timestamp.fromDate(thirtyDaysAgo);
      
      console.log(`🧹 [GPS Cleanup] Cutoff date: ${thirtyDaysAgo.toISOString()}`);
      
      // Find walks that ended more than 30 days ago
      // Use endedAt for walks that have ended, or scheduledDate as fallback
      const walksSnapshot = await db
        .collection("walks")
        .where("status", "in", ["completed", "completed_late", "ended", "cancelled"])
        .where("endedAt", "<=", cutoffTimestamp)
        .get();
      
      if (walksSnapshot.empty) {
        console.log("🧹 [GPS Cleanup] No walks found that need cleanup");
        return;
      }
      
      console.log(`🧹 [GPS Cleanup] Found ${walksSnapshot.size} walks to clean up`);
      
      let totalPointsDeleted = 0;
      let walksProcessed = 0;
      
      // Process walks in batches to avoid timeout
      for (const walkDoc of walksSnapshot.docs) {
        const walkId = walkDoc.id;
        const walkData = walkDoc.data();
        const walkTitle = walkData.title || "Unknown Walk";
        
        try {
          // Get all tracking points for this walk
          const trackingSnapshot = await db
            .collection("walks")
            .doc(walkId)
            .collection("tracking")
            .get();
          
          if (trackingSnapshot.empty) {
            console.log(`  ↳ Walk ${walkId} (${walkTitle}): No tracking data to delete`);
            continue;
          }
          
          const pointCount = trackingSnapshot.size;
          
          // Delete tracking points in batches (Firestore batch limit: 500 operations)
          const batchSize = 500;
          let batch = db.batch();
          let operationsInBatch = 0;
          
          for (const pointDoc of trackingSnapshot.docs) {
            batch.delete(pointDoc.ref);
            operationsInBatch++;
            
            // Commit batch when it reaches the limit
            if (operationsInBatch >= batchSize) {
              await batch.commit();
              batch = db.batch();
              operationsInBatch = 0;
            }
          }
          
          // Commit any remaining operations
          if (operationsInBatch > 0) {
            await batch.commit();
          }
          
          totalPointsDeleted += pointCount;
          walksProcessed++;
          
          console.log(`  ✅ Walk ${walkId} (${walkTitle}): Deleted ${pointCount} GPS points`);
        } catch (error) {
          console.error(`  ❌ Walk ${walkId} (${walkTitle}): Error deleting tracking data:`, error);
          // Continue processing other walks even if one fails
        }
      }
      
      console.log(`🧹 [GPS Cleanup] Complete: Processed ${walksProcessed} walks, deleted ${totalPointsDeleted} GPS points`);
    } catch (error) {
      console.error("❌ [GPS Cleanup] Fatal error during cleanup:", error);
      throw error; // Re-throw to mark function execution as failed
    }
  }
);

// ===== CP-4: WALK COMPLETION FUNCTIONS =====
// Import CP-4 walk tracking functions
const cp4Functions = require("./cp4_walk_completion");

exports.onWalkStarted = cp4Functions.onWalkStarted;
exports.onWalkEnded = cp4Functions.onWalkEnded;
exports.onUserLeftWalkEarly = cp4Functions.onUserLeftWalkEarly;
exports.onWalkAutoComplete = cp4Functions.onWalkAutoComplete;
