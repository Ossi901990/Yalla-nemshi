const { onDocumentWritten } = require("firebase-functions/v2/firestore");

/**
 * Host ratings are derived from walk reviews server-side so hosts cannot set
 * their own rating (users/{uid}/stats/hostRating is not client-writable).
 *
 * Trigger: any create/update/delete of walks/{walkId}/reviews/{reviewerId}.
 * Action: recompute the host's average from all of their reviews. Recomputing
 * (instead of incrementing) keeps the result correct even when a trigger is
 * delivered more than once.
 */
module.exports = (admin) => {
  const db = admin.firestore();

  async function recomputeHostRating(hostUid) {
    const snap = await db
      .collectionGroup("reviews")
      .where("hostUid", "==", hostUid)
      .get();

    let total = 0;
    let count = 0;
    snap.forEach((doc) => {
      const d = doc.data();
      const rating = Number(d.hostRating);
      // Hosts don't rate themselves; ignore malformed values.
      if (d.userId === hostUid || !Number.isFinite(rating)) return;
      if (rating < 1 || rating > 5) return;
      total += rating;
      count += 1;
    });

    const ref = db
      .collection("users")
      .doc(hostUid)
      .collection("stats")
      .doc("hostRating");

    // No reviews left: remove the doc so the app shows its default rating.
    if (count === 0) {
      await ref.delete();
      return;
    }

    await ref.set({
        rating: Math.round((total / count) * 100) / 100,
        reviewCount: count,
        totalRatingPoints: total,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  }

  const onWalkReviewWritten = onDocumentWritten(
    "walks/{walkId}/reviews/{reviewerId}",
    async (event) => {
      const before = event.data?.before?.data();
      const after = event.data?.after?.data();

      const hosts = new Set(
        [before?.hostUid, after?.hostUid].filter(
          (h) => typeof h === "string" && h.length > 0,
        ),
      );

      // Skip writes that don't touch the rating (e.g. "helpful" votes).
      if (
        before && after &&
        before.hostUid === after.hostUid &&
        before.hostRating === after.hostRating
      ) {
        return;
      }

      for (const hostUid of hosts) {
        try {
          await recomputeHostRating(hostUid);
        } catch (error) {
          console.error(`❌ Failed to recompute host rating for ${hostUid}:`, error);
        }
      }
    },
  );

  return { onWalkReviewWritten, recomputeHostRating };
};
