/**
 * CP-4: Walk History & Statistics
 * 
 * Cloud Functions for:
 * 1. onWalkStarted - Send confirmation prompt to participants
 * 2. onWalkEnded - Mark walk as complete, calculate stats
 * 3. onWalkAutoComplete - Auto-complete walk after grace period
 * 4. onUserLeftWalkEarly - Handle participant leaving early
 */

const admin = require("firebase-admin");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { sendNotificationToUser } = require("./index");

// ===== BADGE CATALOG (mirrors Flutter badge catalog) =====
// metric options: totalWalksCompleted | totalDistanceKm | totalWalksHosted
const badgeCatalog = [
  { id: "first_walk", title: "First Steps", description: "Complete your first walk.", metric: "totalWalksCompleted", target: 1 },
  { id: "five_walks", title: "Getting Going", description: "Complete 5 walks.", metric: "totalWalksCompleted", target: 5 },
  { id: "ten_walks", title: "Consistent Walker", description: "Complete 10 walks.", metric: "totalWalksCompleted", target: 10 },
  { id: "twentyfive_walks", title: "Trail Regular", description: "Complete 25 walks.", metric: "totalWalksCompleted", target: 25 },
  { id: "fifty_walks", title: "Walk Centurion", description: "Complete 50 walks.", metric: "totalWalksCompleted", target: 50 },
  { id: "hundred_walks", title: "Habit Master", description: "Complete 100 walks.", metric: "totalWalksCompleted", target: 100 },
  { id: "km_20", title: "20 km", description: "Walk 20 km in total.", metric: "totalDistanceKm", target: 20 },
  { id: "km_42", title: "Marathon Mindset", description: "Walk 42 km in total.", metric: "totalDistanceKm", target: 42 },
  { id: "km_100", title: "Century Club", description: "Walk 100 km in total.", metric: "totalDistanceKm", target: 100 },
  { id: "km_250", title: "Quarter to 1k", description: "Walk 250 km in total.", metric: "totalDistanceKm", target: 250 },
  { id: "km_500", title: "Half to 1k", description: "Walk 500 km in total.", metric: "totalDistanceKm", target: 500 },
  { id: "first_host", title: "First Host", description: "Host your first walk.", metric: "totalWalksHosted", target: 1 },
  { id: "five_hosts", title: "Community Leader", description: "Host 5 walks.", metric: "totalWalksHosted", target: 5 },
  { id: "ten_hosts", title: "Super Host", description: "Host 10 walks.", metric: "totalWalksHosted", target: 10 },
];

// ===== CP-4: Helper function to send confirmation prompt =====

/**
 * Send walk start confirmation prompt to all participants
 * Trigger: /walks/{walkId} updated with status: "starting"
 */
exports.onWalkStarted = onDocumentUpdated(
  "walks/{walkId}",
  async (event) => {
    const db = admin.firestore();
    const walkId = event.params.walkId;
    const walkAfter = event.data.after.data();
    const walkBefore = event.data.before.data();

    // Only proceed if status changed to "starting"
    if (walkBefore.status === "starting" || walkAfter.status !== "starting") {
      return;
    }

    try {
      console.log(`🚀 Walk ${walkId} started by host`);

      // Get all participants (joinedUserUids)
      const participants = walkAfter.joinedUserUids || [];
      const hostUid = walkAfter.hostUid;

      // Notify all participants except host
      const participantsToNotify = participants.filter(uid => uid !== hostUid);

      if (participantsToNotify.length === 0) {
        console.log(`No participants to notify for walk ${walkId}`);
        return;
      }

      // Send confirmation prompt to each participant
      await Promise.all(
        participantsToNotify.map((uid) =>
          db
            .collection("users")
            .doc(uid)
            .collection("fcmTokens")
            .get()
            .then(async (tokensSnapshot) => {
              if (tokensSnapshot.empty) return;

              const tokens = tokensSnapshot.docs.map((doc) => doc.data().token);
              const message = {
                notification: {
                  title: `${walkAfter.title} has started!`,
                  body: "Are you joining this walk now?",
                },
                data: {
                  action: "walk_confirmation_prompt",
                  walkId: walkId,
                  type: "confirmation_needed",
                },
                tokens: tokens,
              };

              const response = await admin.messaging().sendEachForMulticast(message);
              console.log(`✅ Sent confirmation prompts to ${uid}`);

              // Clean up invalid tokens
              if (response.failureCount > 0) {
                const batch = db.batch();
                response.responses.forEach((resp, idx) => {
                  if (!resp.success && tokens[idx]) {
                    const tokenRef = db
                      .collection("users")
                      .doc(uid)
                      .collection("fcmTokens")
                      .doc(tokens[idx]);
                    batch.delete(tokenRef);
                  }
                });
                await batch.commit();
              }
            })
        )
      );

      console.log(`✅ Walk start confirmation sent to ${participantsToNotify.length} participants`);
    } catch (error) {
      console.error("❌ Error in onWalkStarted:", error);
    }
  }
);

// ===== CP-4: Calculate stats when walk ends =====

/**
 * Mark walk as complete and calculate user stats
 * Trigger: /walks/{walkId} updated with status: "completed" and completedAt set
 */
exports.onWalkEnded = onDocumentUpdated(
  "walks/{walkId}",
  async (event) => {
    const db = admin.firestore();
    const walkId = event.params.walkId;
    const walkAfter = event.data.after.data();
    const walkBefore = event.data.before.data();

    // Only proceed if status changed to "completed"
    if (walkBefore.status === "completed" || walkAfter.status !== "completed") {
      return;
    }

    try {
      console.log(`✅ Walk ${walkId} completed by host`);

      // Calculate actual duration
      const startedAt = walkAfter.startedAt?.toDate() || new Date();
      const completedAt = walkAfter.completedAt?.toDate() || new Date();
      const actualDurationMinutes = Math.round(
        (completedAt - startedAt) / 1000 / 60
      );

      // Get all "actively_walking" participants
      const participationSnapshot = await db
        .collectionGroup("walks")
        .where("walkId", "==", walkId)
        .where("status", "==", "actively_walking")
        .get();

      console.log(`Found ${participationSnapshot.docs.length} active participants`);

      // Update each participant's completion status
      const batch = db.batch();
      const userStatsToUpdate = [];

      participationSnapshot.docs.forEach((doc) => {
        const participation = doc.data();
        const userId = participation.userId;
        const confirmedAt = participation.confirmedAt?.toDate() || startedAt;

        // Calculate user's actual duration
        const userActualDurationMinutes = Math.round(
          (completedAt - confirmedAt) / 1000 / 60
        );

        // Update participation record
        batch.update(doc.ref, {
          status: "completed",
          completedAt: admin.firestore.Timestamp.fromDate(completedAt),
          actualDurationMinutes: userActualDurationMinutes,
        });

        userStatsToUpdate.push({
          userId,
          actualDurationMinutes: userActualDurationMinutes,
          actualDistanceKm: walkAfter.distanceKm || 0,
        });
      });

      await batch.commit();
      console.log(`✅ Updated ${participationSnapshot.docs.length} participation records`);

      // Calculate stats for each user
      await Promise.all(
        userStatsToUpdate.map(async (update) => {
          await updateUserStats(db, update.userId, update.actualDurationMinutes, update.actualDistanceKm, false, sendNotificationToUser);
        })
      );

      console.log(`✅ Updated stats for ${userStatsToUpdate.length} users`);
    } catch (error) {
      console.error("❌ Error in onWalkEnded:", error);
    }
  }
);

// ===== CP-4: Auto-complete walk after grace period =====

/**
 * Auto-complete walk if host forgets to end it manually
 * Trigger: Scheduled function (runs every 5 minutes)
 * Implementation note: This would be done via Cloud Scheduler
 */
exports.onWalkAutoComplete = onDocumentUpdated(
  "walks/{walkId}",
  async (event) => {
    const db = admin.firestore();
    const walkId = event.params.walkId;
    const walkAfter = event.data.after.data();
    const walkBefore = event.data.before.data();

    // Check if walk is still "active" and past grace period
    if (walkAfter.status !== "active" || walkAfter.completed) {
      return;
    }

    try {
      const now = new Date();
      const plannedEndTime = new Date(
        walkAfter.dateTime.toDate().getTime() +
        (walkAfter.plannedDurationMinutes || 120) * 60 * 1000
      );
      const gracePeriod = 30 * 60 * 1000; // 30 minute buffer
      const shouldAutoComplete = now > new Date(plannedEndTime.getTime() + gracePeriod);

      if (!shouldAutoComplete) {
        return;
      }

      console.log(`⏰ Auto-completing walk ${walkId} after grace period`);

      // Auto-complete the walk
      await db.collection("walks").doc(walkId).update({
        status: "completed",
        completedAt: admin.firestore.Timestamp.fromDate(now),
        actualDurationMinutes: Math.round(
          (now - (walkAfter.startedAt?.toDate() || walkAfter.dateTime.toDate())) / 1000 / 60
        ),
      });

      console.log(`✅ Auto-completed walk ${walkId}`);
    } catch (error) {
      console.error("❌ Error in onWalkAutoComplete:", error);
    }
  }
);

// ===== CP-4: Handle early walk departure =====

/**
 * Handle user leaving walk early
 * Trigger: /users/{userId}/walks/{walkId} updated with status: "completed_early"
 */
exports.onUserLeftWalkEarly = onDocumentUpdated(
  "users/{userId}/walks/{walkId}",
  async (event) => {
    const userId = event.params.userId;
    const walkId = event.params.walkId;
    const participationAfter = event.data.after.data();
    const participationBefore = event.data.before.data();

    // Only proceed if status changed to "completed_early"
    if (participationBefore.status === "completed_early" || participationAfter.status !== "completed_early") {
      return;
    }

    try {
      console.log(`👋 User ${userId} left walk ${walkId} early`);

      const confirmedAt = participationAfter.confirmedAt?.toDate();
      const leftAt = participationAfter.completedAt?.toDate() || new Date();

      if (!confirmedAt) {
        console.log(`No confirmation time for user ${userId}, skipping stats update`);
        return;
      }

      // Calculate duration for early leave
      const actualDurationMinutes = Math.round(
        (leftAt - confirmedAt) / 1000 / 60
      );

      // Update user's stats with partial credit
      await updateUserStats(
        admin.firestore(),
        userId,
        actualDurationMinutes,
        participationAfter.actualDistanceKm || 0,
        true, // isPartialCredit
        sendNotificationToUser
      );

      console.log(`✅ Updated stats for user ${userId} (${actualDurationMinutes} min)`);
    } catch (error) {
      console.error("❌ Error in onUserLeftWalkEarly:", error);
    }
  }
);

// ===== CP-4: Helper function to update user stats =====

/**
 * Update user's walking statistics
 * Called when walk completes or user leaves early
 */
async function updateUserStats(db, userId, durationMinutes, distanceKm, isPartialCredit = false, sendNotification = null) {
  try {
    const statsRef = db.collection("users").doc(userId).collection("stats").doc("walkStats");
    const statsSnapshot = await statsRef.get();

    let stats;
    if (!statsSnapshot.exists) {
      // Create new stats document
      stats = {
        userId: userId,
        totalWalksCompleted: 1,
        totalWalksJoined: 1,
        totalWalksHosted: 0,
        totalDistanceKm: distanceKm,
        totalDuration: durationMinutes * 60, // in seconds
        totalParticipants: 1,
        averageDistancePerWalk: distanceKm,
        averageDurationPerWalk: durationMinutes * 60,
        lastWalkDate: admin.firestore.Timestamp.now(),
        createdAt: admin.firestore.Timestamp.now(),
        lastUpdated: admin.firestore.Timestamp.now(),
      };
    } else {
      // Update existing stats
      const currentStats = statsSnapshot.data();
      const totalWalks = currentStats.totalWalksCompleted + 1;
      const totalDistance = (currentStats.totalDistanceKm || 0) + distanceKm;
      const totalSeconds = (currentStats.totalDuration || 0) + (durationMinutes * 60);

      stats = {
        totalWalksCompleted: totalWalks,
        totalDistanceKm: totalDistance,
        totalDuration: totalSeconds,
        averageDistancePerWalk: totalDistance / totalWalks,
        averageDurationPerWalk: totalSeconds / totalWalks,
        lastWalkDate: admin.firestore.Timestamp.now(),
        lastUpdated: admin.firestore.Timestamp.now(),
      };
    }

    await statsRef.set(stats, { merge: true });
    console.log(`✅ Updated stats for user ${userId}`);

    // Evaluate and persist badges for this user
    await evaluateBadges(db, userId, {
      totalWalksCompleted: stats.totalWalksCompleted ?? (statsSnapshot.data()?.totalWalksCompleted ?? 0),
      totalDistanceKm: stats.totalDistanceKm ?? (statsSnapshot.data()?.totalDistanceKm ?? 0),
      totalWalksHosted: stats.totalWalksHosted ?? (statsSnapshot.data()?.totalWalksHosted ?? 0),
    }, sendNotification);
  } catch (error) {
    console.error(`❌ Error updating stats for user ${userId}:`, error);
  }
}

function metricValue(metric, stats) {
  switch (metric) {
    case "totalWalksCompleted":
      return stats.totalWalksCompleted || 0;
    case "totalDistanceKm":
      return stats.totalDistanceKm || 0;
    case "totalWalksHosted":
      return stats.totalWalksHosted || 0;
    default:
      return 0;
  }
}

async function evaluateBadges(db, userId, stats, sendNotification = null) {
  try {
    const badgesRef = db.collection("users").doc(userId).collection("badges");
    const existingSnapshot = await badgesRef.get();

    const existing = {};
    existingSnapshot.forEach((doc) => {
      existing[doc.id] = doc.data();
    });

    const batch = db.batch();
    const newBadgesEarned = [];

    badgeCatalog.forEach((badge) => {
      const currentValue = metricValue(badge.metric, stats);
      const progress = badge.target > 0 ? Math.min(1, currentValue / badge.target) : 0;
      const achieved = currentValue >= badge.target - 1e-9;

      const prev = existing[badge.id];
      const alreadyAchieved = prev && prev.achieved === true;

      const earnedAt = achieved
        ? (prev && prev.earnedAt) || admin.firestore.Timestamp.now()
        : null;

      batch.set(
        badgesRef.doc(badge.id),
        {
          title: badge.title,
          description: badge.description,
          progress,
          target: badge.target,
          achieved,
          earnedAt,
          metric: badge.metric,
          updatedAt: admin.firestore.Timestamp.now(),
        },
        { merge: true },
      );

      if (achieved && !alreadyAchieved) {
        console.log(`🎉 Badge earned for ${userId}: ${badge.id}`);
        newBadgesEarned.push(badge);
      }
    });

    await batch.commit();

    // Send notifications for newly earned badges
    if (sendNotification && newBadgesEarned.length > 0) {
      for (const badge of newBadgesEarned) {
        await sendNotification(userId, {
          title: `🎉 Badge Earned!`,
          body: `"${badge.title}" - ${badge.description}`,
        }, {
          action: "badge_earned",
          badgeId: badge.id,
          badgeTitle: badge.title,
        }, "badge_notification");
      }
    }
  } catch (error) {
    console.error(`❌ Error evaluating badges for ${userId}:`, error);
  }
}

module.exports = {
  updateUserStats,
};
