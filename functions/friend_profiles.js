module.exports = function setupFriendProfiles(admin) {
  if (!admin || typeof admin.firestore !== "function") {
    throw new Error("A configured firebase-admin instance is required");
  }

  const db = admin.firestore();
  const FRIEND_STATS_DOC_ID = "walkStats";
  const MAX_WALK_SUMMARIES_PER_USER = 40;

  function sanitizeNullableString(value, maxLength = 500) {
    if (typeof value !== "string") {
      return null;
    }
    const trimmed = value.trim();
    if (!trimmed) {
      return null;
    }
    return trimmed.slice(0, maxLength);
  }

  function coerceNumber(value, fallback = 0, precision = 2) {
    const num = Number(value);
    if (!Number.isFinite(num)) {
      return fallback;
    }
    const factor = 10 ** precision;
    return Math.round(num * factor) / factor;
  }

  function buildFriendProfilePayload(uid, userData = {}, statsData = {}) {
    const displayName = sanitizeNullableString(userData.displayName, 120) || "Walker";
    const bio = sanitizeNullableString(userData.bio || userData.about, 280);
    const photoUrl = sanitizeNullableString(userData.photoUrl || userData.photoURL, 2000);
    const hostRatingSource = statsData.hostRating ?? statsData.averageHostRating ?? userData.hostRating;

    const totals = {
      hosted: statsData.totalWalksHosted ?? statsData.hostedWalks ?? 0,
      joined: statsData.totalWalksJoined ?? statsData.joinedWalks ?? statsData.totalWalks ?? 0,
      distanceKm: statsData.totalDistanceKm ?? statsData.totalDistance ?? 0,
      minutes: statsData.totalMinutes ?? statsData.totalDurationMinutes ?? 0,
    };

    const lastActiveAt = userData.lastActiveAt || statsData.lastCompletedAt || statsData.lastWalkAt || null;

    return {
      uid,
      displayName,
      photoUrl: photoUrl || null,
      bio,
      hostRating: coerceNumber(hostRatingSource, null),
      totalWalksHosted: coerceNumber(totals.hosted, 0, 0),
      totalWalksJoined: coerceNumber(totals.joined, 0, 0),
      totalDistanceKm: coerceNumber(totals.distanceKm, 0),
      totalMinutes: coerceNumber(totals.minutes, 0, 0),
      lastActiveAt: lastActiveAt || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  }

  async function refreshFriendProfile(uid) {
    const userRef = db.collection("users").doc(uid);
    const statsRef = userRef.collection("stats").doc(FRIEND_STATS_DOC_ID);

    const [userSnap, statsSnap] = await Promise.all([userRef.get(), statsRef.get()]);

    if (!userSnap.exists) {
      console.warn(`⚠️ Friend profile sync skipped: user ${uid} missing`);
      await db.collection("friend_profiles").doc(uid).delete().catch(() => {});
      return;
    }

    const payload = buildFriendProfilePayload(
      uid,
      userSnap.data() || {},
      statsSnap.exists ? statsSnap.data() || {} : {}
    );
    await db.collection("friend_profiles").doc(uid).set(payload, { merge: true });
    console.log(`✅ Synced friend profile for ${uid}`);
  }

  async function deleteFriendProfile(uid) {
    await db.collection("friend_profiles").doc(uid).delete().catch(() => {});
    console.log(`🗑️ Removed friend profile for ${uid}`);
  }

  function normalizeTimestamp(value) {
    if (!value) {
      return null;
    }
    if (value instanceof admin.firestore.Timestamp) {
      return value;
    }
    if (typeof value.toDate === "function") {
      return value;
    }
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) {
      return null;
    }
    return admin.firestore.Timestamp.fromDate(date);
  }

  function determineWalkCategory(walkData, startTimestamp) {
    if (!walkData) {
      return "unknown";
    }
    if (walkData.cancelled) {
      return "cancelled";
    }
    const status = (walkData.status || "").toLowerCase();
    if (status === "completed" || status === "past") {
      return "past";
    }
    const nowMs = Date.now();
    const startMs = startTimestamp
      ? startTimestamp.toMillis
        ? startTimestamp.toMillis()
        : startTimestamp.toDate().getTime()
      : null;
    if (startMs != null && startMs <= nowMs) {
      return "past";
    }
    return "upcoming";
  }

  function shouldShareWalk(walkData) {
    if (!walkData) {
      return false;
    }
    if ((walkData.visibility || "open") === "private") {
      return false;
    }
    if (walkData.hideFromFriends === true) {
      return false;
    }
    return true;
  }

  function collectShareableUserRoles(walkData) {
    const roles = new Map();
    if (!shouldShareWalk(walkData)) {
      return roles;
    }

    const hostUid = typeof walkData?.hostUid === "string" ? walkData.hostUid : null;
    if (hostUid) {
      roles.set(hostUid, "host");
    }

    const participantArrays = [
      Array.isArray(walkData?.joinedUserUids) ? walkData.joinedUserUids : [],
      Array.isArray(walkData?.joinedUids) ? walkData.joinedUids : [],
    ];

    participantArrays.flat().forEach((uid) => {
      if (typeof uid === "string" && uid) {
        if (!roles.has(uid)) {
          roles.set(uid, uid === hostUid ? "host" : "participant");
        }
      }
    });

    return roles;
  }

  function buildWalkSummaryPayload(walkId, walkData, role) {
    if (!walkData) {
      return null;
    }

    const startTimestamp = normalizeTimestamp(
      walkData.dateTime || walkData.startTime || walkData.startedAt || walkData.startAt
    );
    const endTimestamp = normalizeTimestamp(
      walkData.completedAt || walkData.endTime || walkData.endsAt
    );

    const category = determineWalkCategory(walkData, startTimestamp);

    return {
      walkId,
      role,
      title: sanitizeNullableString(walkData.title, 140) || "Walk",
      visibility: walkData.visibility || "open",
      status: walkData.status || null,
      meetingPlaceName: sanitizeNullableString(
        walkData.meetingPlaceName || walkData.meetingPointName || walkData.meetingPlace,
        120
      ),
      startTime: startTimestamp,
      endTime: endTimestamp,
      category,
      distanceKm: coerceNumber(walkData.distanceKm ?? walkData.distance ?? walkData.lengthKm, 0),
      estimatedDurationMinutes: coerceNumber(
        walkData.plannedDurationMinutes ?? walkData.expectedDurationMinutes ?? walkData.estimatedDurationMinutes,
        null,
        0
      ),
      coverPhotoUrl: sanitizeNullableString(
        walkData.coverPhotoUrl || walkData.photoUrl || walkData.heroImageUrl,
        2000
      ),
      hostUid: walkData.hostUid || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  }

  async function upsertWalkSummaryForUser(uid, walkId, walkData, role) {
    const payload = buildWalkSummaryPayload(walkId, walkData, role);
    if (!payload) {
      await deleteWalkSummaryForUser(uid, walkId);
      return;
    }

    await db
      .collection("friend_profiles")
      .doc(uid)
      .collection("walk_summaries")
      .doc(walkId)
      .set(payload, { merge: true });
  }

  async function deleteWalkSummaryForUser(uid, walkId) {
    await db
      .collection("friend_profiles")
      .doc(uid)
      .collection("walk_summaries")
      .doc(walkId)
      .delete()
      .catch(() => {});
  }

  async function enforceWalkSummaryLimit(uid, maxDocs = MAX_WALK_SUMMARIES_PER_USER) {
    if (!maxDocs || maxDocs <= 0) {
      return;
    }
    const summariesRef = db.collection("friend_profiles").doc(uid).collection("walk_summaries");
    const overflowSnapshot = await summariesRef
      .orderBy("updatedAt", "desc")
      .offset(maxDocs)
      .limit(25)
      .get();

    if (overflowSnapshot.empty) {
      return;
    }

    const batch = db.batch();
    overflowSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    console.log(`🧹 Pruned ${overflowSnapshot.size} excess summaries for ${uid}`);
  }

  return {
    FRIEND_STATS_DOC_ID,
    MAX_WALK_SUMMARIES_PER_USER,
    sanitizeNullableString,
    coerceNumber,
    buildFriendProfilePayload,
    refreshFriendProfile,
    deleteFriendProfile,
    collectShareableUserRoles,
    upsertWalkSummaryForUser,
    deleteWalkSummaryForUser,
    enforceWalkSummaryLimit,
  };
};
