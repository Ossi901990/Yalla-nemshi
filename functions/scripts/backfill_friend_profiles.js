const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const setupFriendProfiles = require('../friend_profiles');
const {
  refreshFriendProfile,
  collectShareableUserRoles,
  upsertWalkSummaryForUser,
  enforceWalkSummaryLimit,
} = setupFriendProfiles(admin);

const USERS_BATCH_SIZE = 200;
const WALKS_BATCH_SIZE = 100;

async function backfillProfiles() {
  console.log('⏳ Starting friend profile backfill...');
  const summaryUsersTouched = new Set();
  await backfillProfileDocs();
  await backfillWalkSummaries(summaryUsersTouched);
  await pruneSummaries(summaryUsersTouched);
  console.log('🎉 Friend profile backfill complete.');
}

async function backfillProfileDocs() {
  console.log('➡️ Backfilling top-level friend profiles...');
  let processed = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection('users')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(USERS_BATCH_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    await Promise.all(
      snapshot.docs.map(async (doc) => {
        try {
          await refreshFriendProfile(doc.id);
        } catch (error) {
          console.error(`❌ Failed to sync friend profile for ${doc.id}`, error);
        }
      })
    );

    processed += snapshot.size;
    console.log(`   • Profiles processed: ${processed}`);
    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    if (snapshot.size < USERS_BATCH_SIZE) {
      break;
    }
  }

  console.log('✅ Friend profile documents refreshed.');
}

async function backfillWalkSummaries(summaryUsersTouched) {
  console.log('➡️ Backfilling walk summary snapshots...');
  let processed = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection('walks')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(WALKS_BATCH_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    for (const doc of snapshot.docs) {
      const walkId = doc.id;
      const walkData = doc.data();
      const roles = collectShareableUserRoles(walkData);

      if (roles.size === 0) {
        continue;
      }

      const tasks = [];
      roles.forEach((role, uid) => {
        summaryUsersTouched.add(uid);
        tasks.push(upsertWalkSummaryForUser(uid, walkId, walkData, role));
      });

      try {
        await Promise.all(tasks);
      } catch (error) {
        console.error(`❌ Failed to upsert walk summary ${walkId}`, error);
      }

      processed += 1;
      if (processed % 50 === 0) {
        console.log(`   • Walks processed: ${processed}`);
      }
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    if (snapshot.size < WALKS_BATCH_SIZE) {
      break;
    }
  }

  console.log(`✅ Walk summaries processed for ${summaryUsersTouched.size} users.`);
}

async function pruneSummaries(summaryUsersTouched) {
  if (summaryUsersTouched.size === 0) {
    return;
  }

  console.log('➡️ Enforcing walk summary limits...');
  await Promise.all(
    [...summaryUsersTouched].map(async (uid) => {
      try {
        await enforceWalkSummaryLimit(uid);
      } catch (error) {
        console.error(`❌ Failed to prune summaries for ${uid}`, error);
      }
    })
  );
  console.log('✅ Walk summary limits enforced.');
}

backfillProfiles()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Friend profile backfill failed', error);
    process.exit(1);
  });
