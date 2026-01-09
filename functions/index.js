const admin = require("firebase-admin");
admin.initializeApp();

const { onCall, HttpsError } = require("firebase-functions/v2/https");

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
