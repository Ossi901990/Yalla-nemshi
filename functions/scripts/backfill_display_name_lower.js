const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const USERS_COLLECTION = 'users';
const BATCH_SIZE = 400;

const toLower = (value = '') => value.toString().trim().toLowerCase();

async function backfillDisplayNameLower() {
  console.log('⏳ Starting displayNameLower backfill...');
  let processed = 0;
  let updated = 0;
  let skipped = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection(USERS_COLLECTION)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    let writesInBatch = 0;
    snapshot.forEach((doc) => {
      processed += 1;
      const data = doc.data();
      const displayName = data.displayName;
      const normalized = toLower(displayName);
      const existing = (data.displayNameLower || '').toString();

      if (!displayName || !normalized) {
        skipped += 1;
        return;
      }

      if (existing === normalized) {
        skipped += 1;
        return;
      }

      batch.update(doc.ref, {
        displayNameLower: normalized,
      });
      updated += 1;
      writesInBatch += 1;
    });

    if (writesInBatch > 0) {
      await batch.commit();
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(
      `✅ Page processed: processed=${processed} updated=${updated} skipped=${skipped}`,
    );

    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  console.log('🎉 Backfill finished.');
  console.log(
    `Summary => processed=${processed}, updated=${updated}, skipped=${skipped}`,
  );
}

backfillDisplayNameLower()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Backfill failed', err);
    process.exit(1);
  });
