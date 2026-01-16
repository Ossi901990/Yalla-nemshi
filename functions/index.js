const admin = require("firebase-admin");
admin.initializeApp();

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");

// ===== SET GLOBAL REGION FOR ALL FUNCTIONS =====
setGlobalOptions({ region: "europe-west1" });

// ===== HELPER FUNCTIONS =====

/**
 * Send FCM notification to a user
 * @param {string} userId - User ID to send notification to
 * @param {Object} notification - Notification object with title and body
 * @param {Object} data - Optional data payload
 */
async function sendNotificationToUser(userId, notification, data = {}) {
  try {
    const db = admin.firestore();
    const tokensSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("fcmTokens")
      .get();

    if (tokensSnapshot.empty) {
      console.log(`No FCM tokens found for user: ${userId}`);
      return;
    }

    const tokens = tokensSnapshot.docs.map((doc) => doc.data().token);

    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: data,
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ Sent ${response.successCount} notifications to user ${userId}`);

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
      console.log(`🗑️ Cleaned up ${response.failureCount} invalid tokens`);
    }
  } catch (error) {
    console.error(`❌ Error sending notification to user ${userId}:`, error);
  }
}

exports.redeemWalkInvite = onCall(async (request) => {
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
    
    // Send notification to host
    await sendNotificationToUser(
      hostUid,
      {
        title: "New walker joined! 🎉",
        body: `${userName} joined your walk "${walk.title}"`,
      },
      {
        type: "walk_joined",
        walkId: walkId,
        userId: userId,
      }
    );
    
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
    await Promise.all(
      participantsToNotify.map((uid) =>
        sendNotificationToUser(
          uid,
          {
            title: "Walk cancelled ❌",
            body: `The walk "${walk.title}" has been cancelled`,
          },
          {
            type: "walk_cancelled",
            walkId: walkId,
          }
        )
      )
    );
    
    console.log(`✅ Notified ${participantsToNotify.length} participants about walk cancellation`);
  } catch (error) {
    console.error("❌ Error in onWalkCancelled:", error);
  }
});

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
  
  // Check if important fields changed
  const importantFields = ["title", "dateTime", "meetingPlaceName", "startLat", "startLng"];
  const hasImportantChange = importantFields.some(
    (field) => before[field] !== after[field]
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
    if (before.dateTime !== after.dateTime) {
      changeDescription = "Time changed";
    } else if (before.meetingPlaceName !== after.meetingPlaceName || 
               before.startLat !== after.startLat) {
      changeDescription = "Location changed";
    } else if (before.title !== after.title) {
      changeDescription = "Title updated";
    }
    
    // Send notifications in parallel
    await Promise.all(
      participantsToNotify.map((uid) =>
        sendNotificationToUser(
          uid,
          {
            title: "Walk updated 📝",
            body: `"${walk.title}" - ${changeDescription}`,
          },
          {
            type: "walk_updated",
            walkId: walkId,
            changeType: changeDescription,
          }
        )
      )
    );
    
    console.log(`✅ Notified ${participantsToNotify.length} participants about walk update`);
  } catch (error) {
    console.error("❌ Error in onWalkUpdated:", error);
  }
});

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
    await Promise.all(
      participantsToNotify.map((uid) =>
        sendNotificationToUser(
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
        )
      )
    );
    
    console.log(`✅ Notified ${participantsToNotify.length} participants about new message`);
  } catch (error) {
    console.error("❌ Error in onChatMessage:", error);
  }
});

// ===== CP-4: WALK COMPLETION FUNCTIONS =====
// Import CP-4 walk tracking functions
const cp4Functions = require("./cp4_walk_completion");

exports.onWalkStarted = cp4Functions.onWalkStarted;
exports.onWalkEnded = cp4Functions.onWalkEnded;
exports.onUserLeftWalkEarly = cp4Functions.onUserLeftWalkEarly;
exports.onWalkAutoComplete = cp4Functions.onWalkAutoComplete;
