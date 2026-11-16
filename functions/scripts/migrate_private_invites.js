/**
 * One-time migration for the private-walk security fix.
 *
 * For every walk document:
 *  - moves shareCode / shareCodeExpiresAt into walks/{id}/private/invite
 *    (host-only) + invite_codes/{CODE}, and deletes them from the walk doc
 *  - sets visibility to 'open' when it is missing (listing queries now
 *    filter on visibility == 'open', so walks without it would disappear)
 *
 * Safe to run more than once. Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json \
 *     npm run migrate:privateInvites
 * or, after `gcloud auth application-default login`:
 *   npm run migrate:privateInvites
 */
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const BATCH_SIZE = 150; // up to 3 writes per walk

async function migrate() {
  console.log('⏳ Migrating walk invite codes and visibility...');
  let processed = 0;
  let movedCodes = 0;
  let fixedVisibility = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection('walks')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    let writes = 0;

    snapshot.forEach((doc) => {
      processed += 1;
      const data = doc.data();
      const walkUpdate = {};

      if (data.shareCode !== undefined || data.shareCodeExpiresAt !== undefined) {
        if (data.shareCode) {
          batch.set(
            doc.ref.collection('private').doc('invite'),
            {
              walkId: doc.id,
              hostUid: data.hostUid || null,
              shareCode: data.shareCode,
              shareCodeExpiresAt: data.shareCodeExpiresAt || null,
            },
            { merge: true },
          );
          batch.set(
            db.collection('invite_codes').doc(String(data.shareCode).toUpperCase()),
            {
              walkId: doc.id,
              hostUid: data.hostUid || null,
              expiresAt: data.shareCodeExpiresAt || null,
            },
          );
          writes += 2;
          movedCodes += 1;
        }
        walkUpdate.shareCode = admin.firestore.FieldValue.delete();
        walkUpdate.shareCodeExpiresAt = admin.firestore.FieldValue.delete();
      }

      if (data.visibility !== 'open' && data.visibility !== 'private') {
        walkUpdate.visibility = 'open';
        fixedVisibility += 1;
      }

      if (Object.keys(walkUpdate).length > 0) {
        batch.update(doc.ref, walkUpdate);
        writes += 1;
      }
    });

    if (writes > 0) await batch.commit();
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }

  console.log(
    `✅ Done. Walks scanned: ${processed}, invite codes moved: ${movedCodes}, ` +
    `visibility fixed: ${fixedVisibility}`,
  );
}

migrate().catch((error) => {
  console.error('❌ Migration failed:', error);
  process.exit(1);
});
