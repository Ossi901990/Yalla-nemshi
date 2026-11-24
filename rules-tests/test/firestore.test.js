// Firestore security rules tests. Run with `npm test` in rules-tests/
// (starts the Firestore + Storage emulators).
const { describe, it, before, after, beforeEach } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where,
  getDocs, limit, arrayUnion, arrayRemove, increment, serverTimestamp,
  writeBatch, runTransaction, Timestamp, deleteField,
} = require("firebase/firestore");

let env;
const HOST = "host";
const ALICE = "alice";
const BOB = "bob";
const MALLORY = "mallory";

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

function walk(overrides = {}) {
  return {
    hostUid: HOST,
    title: "Morning walk",
    visibility: "open",
    cancelled: false,
    joinedUserUids: [],
    joinedUids: [],
    joinedUserNames: [],
    joinedCount: 0,
    participantStates: {},
    dateTime: Timestamp.fromDate(new Date(Date.now() + 86400000)),
    ...overrides,
  };
}

async function seed(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-yalla-nemshi",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

after(async () => env && env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (f) => {
    await setDoc(doc(f, "walks/open1"), walk());
    await setDoc(doc(f, "walks/priv1"), walk({ visibility: "private" }));
    await setDoc(doc(f, "walks/priv1/private/invite"), {
      hostUid: HOST, walkId: "priv1", shareCode: "ABC123",
    });
  });
});

// ---------------------------------------------------------------------------
describe("user profiles (no public email)", () => {
  const profile = (uid, extra = {}) => ({
    uid, displayName: "Alice", createdAt: Timestamp.now(), ...extra,
  });

  it("can create a profile without an email", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), "users/alice"), profile(ALICE)));
  });

  it("cannot create a profile that stores an email", async () => {
    await assertFails(setDoc(doc(db(ALICE), "users/alice"),
      profile(ALICE, { email: "alice@example.com" })));
  });

  it("cannot add an email to an existing profile", async () => {
    await seed((f) => setDoc(doc(f, "users/alice"), profile(ALICE)));
    await assertFails(updateDoc(doc(db(ALICE), "users/alice"),
      { email: "alice@example.com" }));
  });

  it("legacy profiles can remove their email and still update other fields", async () => {
    await seed((f) => setDoc(doc(f, "users/alice"),
      profile(ALICE, { email: "alice@example.com" })));
    await assertSucceeds(updateDoc(doc(db(ALICE), "users/alice"), { bio: "hi" }));
    await assertFails(updateDoc(doc(db(ALICE), "users/alice"),
      { email: "other@example.com" }));
    await assertSucceeds(updateDoc(doc(db(ALICE), "users/alice"),
      { email: deleteField() }));
  });
});

// ---------------------------------------------------------------------------
describe("private walks", () => {
  it("strangers cannot read a private walk", async () => {
    await assertFails(getDoc(doc(db(MALLORY), "walks/priv1")));
  });

  it("strangers cannot list walks without a visibility filter", async () => {
    await assertFails(getDocs(query(collection(db(MALLORY), "walks"),
      where("cancelled", "==", false))));
  });

  it("listing open walks works and never returns private ones", async () => {
    const snap = await assertSucceeds(getDocs(query(collection(db(MALLORY), "walks"),
      where("visibility", "==", "open"), where("cancelled", "==", false))));
    if (snap.docs.some((d) => d.id === "priv1")) throw new Error("private walk leaked");
  });

  it("host can list own walks (including private)", async () => {
    await assertSucceeds(getDocs(query(collection(db(HOST), "walks"),
      where("hostUid", "==", HOST))));
  });

  it("joined users can list walks they joined", async () => {
    await seed((f) => updateDoc(doc(f, "walks/priv1"), { joinedUserUids: [ALICE] }));
    await assertSucceeds(getDocs(query(collection(db(ALICE), "walks"),
      where("joinedUserUids", "array-contains", ALICE))));
  });

  it("invite code is unreadable to non-hosts and readable to host", async () => {
    await assertFails(getDoc(doc(db(MALLORY), "walks/priv1/private/invite")));
    await assertSucceeds(getDoc(doc(db(HOST), "walks/priv1/private/invite")));
  });

  it("users who redeemed an invite can read the walk", async () => {
    await seed((f) => setDoc(doc(f, "walks/priv1/allowed/alice"), { uid: ALICE }));
    await assertSucceeds(getDoc(doc(db(ALICE), "walks/priv1")));
  });

  it("host can create a private walk + invite in one transaction", async () => {
    const f = db(HOST);
    await assertSucceeds(runTransaction(f, async (tx) => {
      const ref = doc(f, "walks/newPriv");
      await tx.get(ref);
      tx.set(ref, walk({ visibility: "private" }));
      tx.set(doc(f, "walks/newPriv/private/invite"), {
        hostUid: HOST, walkId: "newPriv", shareCode: "ZZZ999",
      });
    }));
  });

  it("shareCode can no longer be written onto the walk doc", async () => {
    await assertFails(setDoc(doc(db(HOST), "walks/w2"), walk({ shareCode: "X" })));
    await assertFails(updateDoc(doc(db(HOST), "walks/open1"), { shareCode: "X" }));
  });

  it("walk create requires a visibility value", async () => {
    const w = walk(); delete w.visibility;
    await assertFails(setDoc(doc(db(HOST), "walks/w3"), w));
  });

  it("unauthenticated users cannot read anything", async () => {
    await assertFails(getDoc(doc(anon(), "walks/open1")));
  });
});

// ---------------------------------------------------------------------------
describe("joining walks", () => {
  // Mirrors the update sent by HomeScreen._toggleJoin.
  const joinUpdate = (uid, name = uid) => ({
    joinedUids: arrayUnion(uid),
    joinedUserUids: arrayUnion(uid),
    joinedUserNames: arrayUnion(name),
    joinedCount: increment(1),
    [`participantStates.${uid}`]: "joined",
  });

  it("a user can join an open walk", async () => {
    await assertSucceeds(updateDoc(doc(db(ALICE), "walks/open1"), joinUpdate(ALICE)));
  });

  it("a user can leave a walk", async () => {
    await seed((f) => updateDoc(doc(f, "walks/open1"), {
      joinedUids: [ALICE], joinedUserUids: [ALICE], joinedUserNames: [ALICE],
      joinedCount: 1, participantStates: { alice: "joined" },
    }));
    await assertSucceeds(updateDoc(doc(db(ALICE), "walks/open1"), {
      joinedUids: arrayRemove(ALICE),
      joinedUserUids: arrayRemove(ALICE),
      joinedUserNames: arrayRemove(ALICE),
      joinedCount: increment(-1),
      "participantStates.alice": "left",
    }));
  });

  it("joining a private walk without an invite is denied", async () => {
    await assertFails(updateDoc(doc(db(MALLORY), "walks/priv1"), joinUpdate(MALLORY)));
  });

  it("joining a private walk after redeeming an invite works", async () => {
    await seed((f) => setDoc(doc(f, "walks/priv1/allowed/alice"), { uid: ALICE }));
    await assertSucceeds(updateDoc(doc(db(ALICE), "walks/priv1"), joinUpdate(ALICE)));
  });

  it("a user cannot add someone else", async () => {
    await assertFails(updateDoc(doc(db(MALLORY), "walks/open1"), joinUpdate(BOB)));
  });

  it("a user cannot remove someone else", async () => {
    await seed((f) => updateDoc(doc(f, "walks/open1"), {
      joinedUids: [BOB], joinedUserUids: [BOB], joinedCount: 1,
    }));
    await assertFails(updateDoc(doc(db(MALLORY), "walks/open1"), {
      joinedUids: [], joinedUserUids: [], joinedCount: 0,
    }));
  });

  it("a user cannot change someone else's participant state", async () => {
    await assertFails(updateDoc(doc(db(MALLORY), "walks/open1"), {
      "participantStates.bob": "declined",
    }));
  });

  it("joinedCount must match the change", async () => {
    await assertFails(updateDoc(doc(db(ALICE), "walks/open1"), {
      ...joinUpdate(ALICE), joinedCount: increment(5),
    }));
  });

  it("non-hosts cannot edit other walk fields", async () => {
    await assertFails(updateDoc(doc(db(MALLORY), "walks/open1"), { title: "pwned" }));
  });

  it("participant can set own state to confirmed (walk history batch)", async () => {
    await seed((f) => updateDoc(doc(f, "walks/open1"), {
      joinedUids: [ALICE], joinedUserUids: [ALICE], joinedCount: 1,
      participantStates: { alice: "joined" },
    }));
    await assertSucceeds(updateDoc(doc(db(ALICE), "walks/open1"), {
      "participantStates.alice": "confirmed",
    }));
  });
});

// ---------------------------------------------------------------------------
describe("reviews", () => {
  const review = (uid, extra = {}) => ({
    walkId: "open1", hostUid: HOST, userId: uid, userName: uid,
    userProfileUrl: null, walkRating: 4, hostRating: 5, reviewText: "Nice",
    photoUrls: [], leftEarly: false, reviewerIsHost: false,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    helpfulCount: 0, helpfulBy: [], ...extra,
  });

  beforeEach(async () => {
    await seed((f) => updateDoc(doc(f, "walks/open1"), {
      joinedUserUids: [ALICE], joinedUids: [ALICE], joinedCount: 1,
    }));
  });

  it("a participant can save a review (was always denied before)", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), "walks/open1/reviews/alice"), review(ALICE)));
  });

  it("non-participants cannot review", async () => {
    await assertFails(setDoc(doc(db(MALLORY), "walks/open1/reviews/mallory"), review(MALLORY)));
  });

  it("cannot write a review as someone else", async () => {
    await assertFails(setDoc(doc(db(ALICE), "walks/open1/reviews/bob"), review(BOB)));
  });

  it("rating must be between 1 and 5", async () => {
    await assertFails(setDoc(doc(db(ALICE), "walks/open1/reviews/alice"),
      review(ALICE, { hostRating: 50 })));
  });

  it("others can mark a review helpful once", async () => {
    await seed((f) => setDoc(doc(f, "walks/open1/reviews/alice"),
      { ...review(ALICE), createdAt: Timestamp.now(), updatedAt: Timestamp.now() }));
    await assertSucceeds(updateDoc(doc(db(BOB), "walks/open1/reviews/alice"), {
      helpfulBy: arrayUnion(BOB), helpfulCount: increment(1),
    }));
    await assertFails(updateDoc(doc(db(BOB), "walks/open1/reviews/alice"), {
      helpfulBy: arrayUnion(BOB), helpfulCount: increment(1),
    }));
  });

  it("hosts cannot set their own rating", async () => {
    await assertFails(setDoc(doc(db(HOST), "users/host/stats/hostRating"),
      { rating: 5, reviewCount: 999 }));
  });

  it("users can still write their own walk stats", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), "users/alice/stats/walkStats"),
      { totalWalksJoined: 1 }));
  });
});

// ---------------------------------------------------------------------------
describe("walk chat", () => {
  beforeEach(async () => {
    await seed((f) => updateDoc(doc(f, "walks/open1"), {
      joinedUserUids: [ALICE], joinedUids: [ALICE], joinedCount: 1,
    }));
  });

  it("participants can send text messages", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), "walk_chats/open1/messages/m1"),
      { senderId: ALICE, text: "hi", sentAt: serverTimestamp(), deleted: false }));
  });

  it("participants can send image messages + append walk photo", async () => {
    const f = db(ALICE);
    await assertSucceeds(runTransaction(f, async (tx) => {
      tx.set(doc(f, "walk_chats/open1/messages/m2"), {
        senderId: ALICE, imageUrl: "https://example/img.jpg",
        sentAt: serverTimestamp(), deleted: false,
      });
      tx.set(doc(f, "walk_chats/open1"), { walkId: "open1", lastMessage: "[Image]" },
        { merge: true });
      tx.set(doc(f, "walks/open1"), { photoUrls: arrayUnion("https://example/img.jpg") },
        { merge: true });
    }));
  });

  it("non-participants cannot read or post", async () => {
    await assertFails(getDocs(collection(db(MALLORY), "walk_chats/open1/messages")));
    await assertFails(setDoc(doc(db(MALLORY), "walk_chats/open1/messages/m3"),
      { senderId: MALLORY, text: "spam", sentAt: serverTimestamp() }));
  });
});

// ---------------------------------------------------------------------------
describe("friends", () => {
  beforeEach(async () => {
    await seed((f) => setDoc(doc(f, "friend_requests/alice/received/req1"), {
      requestId: "req1", fromUserId: BOB, toUserId: ALICE, status: "pending",
    }));
  });

  it("anyone cannot make themselves someone's friend", async () => {
    // Mallory writes herself into Alice's list (worked before the fix).
    await assertFails(setDoc(doc(db(MALLORY), "friends/alice/friendsList/mallory"),
      { friendId: MALLORY, since: serverTimestamp() }));
    // Or adds Alice to her own list to satisfy isFriendOf().
    await assertFails(setDoc(doc(db(MALLORY), "friends/mallory/friendsList/alice"),
      { friendId: ALICE, since: serverTimestamp() }));
  });

  it("forged requestId is rejected", async () => {
    await assertFails(setDoc(doc(db(MALLORY), "friends/alice/friendsList/mallory"),
      { friendId: MALLORY, since: serverTimestamp(), requestId: "req1" }));
  });

  it("accepting a real request writes both edges atomically", async () => {
    const f = db(ALICE);
    const b = writeBatch(f);
    b.set(doc(f, "friends/alice/friendsList/bob"),
      { friendId: BOB, since: serverTimestamp(), requestId: "req1" });
    b.set(doc(f, "friends/bob/friendsList/alice"),
      { friendId: ALICE, since: serverTimestamp(), requestId: "req1" });
    b.delete(doc(f, "friend_requests/alice/received/req1"));
    await assertSucceeds(b.commit());
  });

  it("either friend can remove the friendship", async () => {
    await seed((f) => setDoc(doc(f, "friends/alice/friendsList/bob"), { friendId: BOB }));
    await assertSucceeds(deleteDoc(doc(db(BOB), "friends/alice/friendsList/bob")));
  });
});

// ---------------------------------------------------------------------------
describe("blocks, reports, DMs", () => {
  it("blocking cleans up friend requests in both directions", async () => {
    await seed(async (f) => {
      await setDoc(doc(f, "friend_requests/bob/received/r1"),
        { fromUserId: ALICE, toUserId: BOB, status: "pending" });
      await setDoc(doc(f, "friend_requests/alice/received/r2"),
        { fromUserId: BOB, toUserId: ALICE, status: "pending" });
      await setDoc(doc(f, "friend_requests/bob/received/r3"),
        { fromUserId: MALLORY, toUserId: BOB, status: "pending" });
    });
    const f = db(ALICE);
    // Alice (blocking Bob) can find and withdraw the request she sent Bob...
    const mine = await assertSucceeds(getDocs(query(
      collection(f, "friend_requests/bob/received"), where("fromUserId", "==", ALICE))));
    for (const d of mine.docs) await assertSucceeds(deleteDoc(d.ref));
    // ...and delete Bob's request in her own inbox.
    await assertSucceeds(deleteDoc(doc(f, "friend_requests/alice/received/r2")));
    // She can't see or delete anyone else's requests to Bob.
    await assertFails(getDocs(collection(f, "friend_requests/bob/received")));
    await assertFails(getDoc(doc(f, "friend_requests/bob/received/r3")));
    await assertFails(deleteDoc(doc(f, "friend_requests/bob/received/r3")));
  });

  it("a blocked user can't send a friend request to the blocker", async () => {
    await seed((f) => setDoc(doc(f, "blocks/alice/blocked/bob"), { targetUserId: BOB }));
    const req = { fromUserId: BOB, toUserId: ALICE, status: "pending" };
    await assertFails(setDoc(doc(db(BOB), "friend_requests/alice/received/r9"), req));
    // others still can
    await assertSucceeds(setDoc(doc(db(MALLORY), "friend_requests/alice/received/r8"),
      { ...req, fromUserId: MALLORY }));
  });

  it("no friendship while either side has blocked the other", async () => {
    await seed(async (f) => {
      await setDoc(doc(f, "friend_requests/alice/received/req1"),
        { fromUserId: BOB, toUserId: ALICE, status: "pending" });
      await setDoc(doc(f, "blocks/bob/blocked/alice"), { targetUserId: ALICE });
    });
    await assertFails(setDoc(doc(db(ALICE), "friends/alice/friendsList/bob"),
      { friendId: BOB, since: serverTimestamp(), requestId: "req1" }));
  });

  it("a blocked user can't DM the blocker; the blocker can still read", async () => {
    await seed(async (f) => {
      await setDoc(doc(f, "dm_threads/alice_bob"), { participants: [ALICE, BOB] });
      await setDoc(doc(f, "blocks/alice/blocked/bob"), { targetUserId: BOB });
    });
    const msg = (from) => ({ senderId: from, type: "text", text: "hi", createdAt: serverTimestamp() });
    await assertFails(setDoc(doc(db(BOB), "dm_threads/alice_bob/messages/m1"), msg(BOB)));
    await assertSucceeds(setDoc(doc(db(ALICE), "dm_threads/alice_bob/messages/m2"), msg(ALICE)));
  });

  it("users can block and report (was always denied before)", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), "blocks/alice/blocked/mallory"),
      { targetUserId: MALLORY, blockedAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(db(ALICE), "user_reports/r1"), {
      reportId: "r1", reporterUid: ALICE, targetUid: MALLORY,
      reason: "spam", createdAt: serverTimestamp(),
    }));
  });

  it("reports are not readable by clients", async () => {
    await seed((f) => setDoc(doc(f, "user_reports/r1"), { reporterUid: ALICE }));
    await assertFails(getDoc(doc(db(ALICE), "user_reports/r1")));
  });

  it("DM thread metadata is private to participants", async () => {
    await seed((f) => setDoc(doc(f, "dm_threads/alice_bob"), {
      participants: [ALICE, BOB], lastMessage: "secret",
    }));
    await assertSucceeds(getDoc(doc(db(ALICE), "dm_threads/alice_bob")));
    await assertFails(getDoc(doc(db(MALLORY), "dm_threads/alice_bob")));
  });

  it("participants cannot add others to a DM thread", async () => {
    await seed((f) => setDoc(doc(f, "dm_threads/alice_bob"), { participants: [ALICE, BOB] }));
    await assertFails(updateDoc(doc(db(ALICE), "dm_threads/alice_bob"),
      { participants: [ALICE, MALLORY] }));
  });

  it("users collection cannot be listed without a limit", async () => {
    await assertFails(getDocs(collection(db(MALLORY), "users")));
    await assertSucceeds(getDocs(query(collection(db(MALLORY), "users"), limit(20))));
  });
});

// ---------------------------------------------------------------------------
describe("interested walks (star)", () => {
  const star = (walkId) => ({ walkId, createdAt: serverTimestamp() });

  it("users can star and unstar walks for themselves", async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), "users/alice/interested/open1"), star("open1")));
    await assertSucceeds(getDocs(collection(db(ALICE), "users/alice/interested")));
    await assertSucceeds(deleteDoc(doc(db(ALICE), "users/alice/interested/open1")));
  });

  it("nobody else can see or change a user's stars", async () => {
    await seed((f) => setDoc(doc(f, "users/alice/interested/open1"), { walkId: "open1", createdAt: Timestamp.now() }));
    await assertFails(getDocs(collection(db(MALLORY), "users/alice/interested")));
    await assertFails(setDoc(doc(db(MALLORY), "users/alice/interested/open2"), star("open2")));
    await assertFails(deleteDoc(doc(db(MALLORY), "users/alice/interested/open1")));
  });

  it("star records hold only the walk id and time", async () => {
    await assertFails(setDoc(doc(db(ALICE), "users/alice/interested/open1"), star("other")));
    await assertFails(setDoc(doc(db(ALICE), "users/alice/interested/open1"),
      { ...star("open1"), note: "x" }));
  });
});

// ---------------------------------------------------------------------------
describe("client-side walk completion (Spark)", () => {
  const hist = (uid) => ({
    walkId: "open1", userId: uid, joinedAt: Timestamp.now(), completed: true,
    status: "completed", completedAt: Timestamp.now(), actualDistanceKm: 3.1,
    actualDurationMinutes: 45, role: "participant", statsCounted: true,
  });
  const stats = (uid) => ({
    userId: uid, totalWalksCompleted: 1, totalWalksHosted: 0, totalDistanceKm: 3.1,
    totalDuration: 2700, averageDistancePerWalk: 3.1, averageDurationPerWalk: 2700,
    lastWalkDate: Timestamp.now(), lastUpdated: serverTimestamp(),
  });

  it("a user records their own finished walk and stats", async () => {
    const f = db(ALICE);
    const b = writeBatch(f);
    b.set(doc(f, "users/alice/walks/open1"), hist(ALICE), { merge: true });
    b.set(doc(f, "users/alice/stats/walkStats"), stats(ALICE), { merge: true });
    await assertSucceeds(b.commit());
  });

  it("nobody can write another user's history or stats", async () => {
    await assertFails(setDoc(doc(db(MALLORY), "users/alice/walks/open1"), hist(ALICE)));
    await assertFails(setDoc(doc(db(MALLORY), "users/alice/stats/walkStats"), stats(ALICE)));
  });

  it("history needs the owner's userId and a joinedAt time", async () => {
    await assertFails(setDoc(doc(db(ALICE), "users/alice/walks/open1"),
      { ...hist(ALICE), userId: BOB }));
    const { joinedAt, ...noJoinedAt } = hist(ALICE);
    await assertFails(setDoc(doc(db(ALICE), "users/alice/walks/open1"), noJoinedAt));
  });
});

// ---------------------------------------------------------------------------
describe("per-walker GPS routes", () => {
  const t0 = Date.now();
  const chunk = (uid, extra = {}) => ({
    uid,
    firstAt: Timestamp.fromMillis(t0),
    count: 2,
    points: [
      { latitude: 1, longitude: 2, timestamp: Timestamp.fromMillis(t0) },
      { latitude: 1.0001, longitude: 2, timestamp: Timestamp.fromMillis(t0 + 5000) },
    ],
    ...extra,
  });
  const chunkPath = (uid) => `walks/open1/routes/${uid}/chunks/c${t0}`;

  beforeEach(async () => {
    await seed((f) => setDoc(doc(f, "walks/open1"), walk({
      joinedUserUids: [ALICE], joinedUids: [ALICE], joinedCount: 1,
      participantStates: { alice: "joined" },
    })));
  });

  it("host and joined walkers save their own route chunks", async () => {
    await assertSucceeds(setDoc(doc(db(HOST), chunkPath(HOST)), chunk(HOST)));
    await assertSucceeds(setDoc(doc(db(ALICE), chunkPath(ALICE)), chunk(ALICE)));
    // retry of the same chunk is fine
    await assertSucceeds(setDoc(doc(db(ALICE), chunkPath(ALICE)), chunk(ALICE)));
  });

  it("nobody can write someone else's route", async () => {
    await assertFails(setDoc(doc(db(ALICE), chunkPath(HOST)), chunk(HOST)));
    await assertFails(setDoc(doc(db(ALICE), chunkPath(HOST)), chunk(ALICE)));
  });

  it("non-members cannot save a route for the walk", async () => {
    await assertFails(setDoc(doc(db(MALLORY), chunkPath(MALLORY)), chunk(MALLORY)));
  });

  it("chunks are validated", async () => {
    await assertFails(setDoc(doc(db(ALICE), "walks/open1/routes/alice/chunks/point_0"), chunk(ALICE)));
    await assertFails(setDoc(doc(db(ALICE), chunkPath(ALICE)), chunk(ALICE, { count: 5 })));
    await assertFails(setDoc(doc(db(ALICE), chunkPath(ALICE)), chunk(ALICE, {
      points: Array.from({ length: 61 }, () => ({ latitude: 0, longitude: 0 })), count: 61,
    })));
    await assertFails(setDoc(doc(db(ALICE), chunkPath(ALICE)), chunk(ALICE, { extra: 1 })));
  });

  it("chunks cannot be deleted", async () => {
    await seed((f) => setDoc(doc(f, chunkPath(ALICE)), chunk(ALICE)));
    await assertFails(deleteDoc(doc(db(ALICE), chunkPath(ALICE))));
  });

  it("members read routes; strangers cannot", async () => {
    await seed((f) => setDoc(doc(f, chunkPath(ALICE)), chunk(ALICE)));
    const q = (uid) => query(collection(db(uid), "walks/open1/routes/alice/chunks"));
    await assertSucceeds(getDocs(q(HOST)));
    await assertSucceeds(getDocs(q(ALICE)));
    await assertFails(getDocs(q(MALLORY)));
  });

  it("walkers save their own route summary", async () => {
    const summary = {
      uid: ALICE, pointsCount: 120, distanceKm: 3.2, averageSpeed: 2.9,
      maxSpeed: 4.1, durationMinutes: 48, completed: true, updatedAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(db(ALICE), "walks/open1/routes/alice"), summary));
    await assertFails(setDoc(doc(db(HOST), "walks/open1/routes/alice"), summary));
    await assertFails(setDoc(doc(db(ALICE), "walks/open1/routes/alice"), { ...summary, bogus: true }));
  });
});

// ---------------------------------------------------------------------------
describe("peer notifications (no Cloud Functions)", () => {
  const inDays = (d) => Timestamp.fromDate(new Date(Date.now() + d * 86400000));
  const notif = (from, extra = {}) => ({
    type: "walkJoined",
    title: "New walker joined! 🎉",
    message: "Alice joined your walk",
    timestamp: serverTimestamp(),
    isRead: false,
    walkId: "open1",
    userId: from,
    expiresAt: inDays(30),
    ...extra,
  });
  const add = (from, to, data) =>
    setDoc(doc(db(from), `users/${to}/notifications/n_${from}_${Date.now()}`), data);

  beforeEach(async () => {
    await seed(async (f) => {
      // alice joined open1; bob left it; mallory never joined.
      await setDoc(doc(f, "walks/open1"), walk({
        joinedUserUids: [ALICE], joinedUids: [ALICE], joinedCount: 1,
        participantStates: { alice: "joined", bob: "left" },
      }));
      await setDoc(doc(f, "dm_threads/alice_bob"), { participants: [ALICE, BOB] });
    });
  });

  it("a joiner (or leaver) can notify the host", async () => {
    await assertSucceeds(add(ALICE, HOST, notif(ALICE)));
    await assertSucceeds(add(BOB, HOST, notif(BOB, { type: "walkLeft" })));
  });

  it("strangers cannot notify the host about a walk they never joined", async () => {
    await assertFails(add(MALLORY, HOST, notif(MALLORY)));
  });

  it("join notifications only go to the host", async () => {
    await assertFails(add(ALICE, BOB, notif(ALICE)));
  });

  it("the host can notify joined walkers about cancel/start", async () => {
    await assertSucceeds(add(HOST, ALICE, notif(HOST, { type: "walkCancelled" })));
    await assertSucceeds(add(HOST, ALICE, notif(HOST, { type: "walkStarting" })));
    await assertFails(add(HOST, MALLORY, notif(HOST, { type: "walkCancelled" })));
    await assertFails(add(ALICE, HOST, notif(ALICE, { type: "walkCancelled" })));
  });

  it("walk chat notifications only between walk members", async () => {
    await assertSucceeds(add(ALICE, HOST, notif(ALICE, { type: "walkChatMessage" })));
    await assertSucceeds(add(HOST, ALICE, notif(HOST, { type: "walkChatMessage" })));
    await assertFails(add(MALLORY, ALICE, notif(MALLORY, { type: "walkChatMessage" })));
    // bob left, so he is no longer a chat member
    await assertFails(add(BOB, HOST, notif(BOB, { type: "walkChatMessage" })));
  });

  it("DM notifications only between thread participants", async () => {
    const dm = (from) => notif(from, { type: "dmMessage", walkId: null, threadId: "alice_bob" });
    await assertSucceeds(add(ALICE, BOB, dm(ALICE)));
    await assertFails(add(MALLORY, BOB, dm(MALLORY)));
  });

  it("cannot impersonate another sender or forge fields", async () => {
    await assertFails(add(ALICE, HOST, notif(ALICE, { userId: BOB })));
    await assertFails(add(ALICE, HOST, notif(ALICE, { isRead: true })));
    await assertFails(add(ALICE, HOST, notif(ALICE, { timestamp: inDays(-1) })));
    await assertFails(add(ALICE, HOST, notif(ALICE, { expiresAt: inDays(365) })));
    await assertFails(add(ALICE, HOST, notif(ALICE, { message: "x".repeat(301) })));
    await assertFails(add(ALICE, HOST, notif(ALICE, { type: "badgeEarned" })));
    await assertFails(add(ALICE, HOST, notif(ALICE, { extra: "field" })));
  });

  it("blocked users cannot notify the person who blocked them", async () => {
    await seed((f) => setDoc(doc(f, "blocks/host/blocked/alice"), { targetUserId: ALICE }));
    await assertFails(add(ALICE, HOST, notif(ALICE)));
  });

  it("only the owner can read, edit or delete their notifications", async () => {
    await seed((f) => setDoc(doc(f, "users/host/notifications/n1"), notif(ALICE)));
    await assertSucceeds(getDoc(doc(db(HOST), "users/host/notifications/n1")));
    await assertSucceeds(updateDoc(doc(db(HOST), "users/host/notifications/n1"), { isRead: true }));
    await assertFails(getDoc(doc(db(ALICE), "users/host/notifications/n1")));
    await assertFails(updateDoc(doc(db(ALICE), "users/host/notifications/n1"), { message: "edited" }));
    await assertFails(deleteDoc(doc(db(ALICE), "users/host/notifications/n1")));
  });
});

// ---------------------------------------------------------------------------
describe("invite codes (no Cloud Functions)", () => {
  const future = () => Timestamp.fromDate(new Date(Date.now() + 86400000));
  const past = () => Timestamp.fromDate(new Date(Date.now() - 86400000));

  beforeEach(async () => {
    await seed(async (f) => {
      await setDoc(doc(f, "invite_codes/ABC123"), { walkId: "priv1", hostUid: HOST, expiresAt: future() });
      await setDoc(doc(f, "invite_codes/OLD999"), { walkId: "priv1", hostUid: HOST, expiresAt: past() });
      await setDoc(doc(f, "walks/priv2"), walk({ visibility: "private" }));
      await setDoc(doc(f, "invite_codes/OTHER1"), { walkId: "priv2", hostUid: HOST, expiresAt: future() });
    });
  });

  const redeem = (uid, walkId, code) => setDoc(doc(db(uid), `walks/${walkId}/allowed/${uid}`),
    { uid, walkId, code, redeemedAt: serverTimestamp() });

  it("a code can be looked up by exact id but codes can't be listed", async () => {
    await assertSucceeds(getDoc(doc(db(ALICE), "invite_codes/ABC123")));
    await assertFails(getDocs(collection(db(ALICE), "invite_codes")));
  });

  it("redeeming a valid code grants access to the private walk", async () => {
    await assertSucceeds(redeem(ALICE, "priv1", "ABC123"));
    await assertSucceeds(getDoc(doc(db(ALICE), "walks/priv1")));
  });

  it("wrong, foreign, or expired codes are rejected", async () => {
    await assertFails(redeem(MALLORY, "priv1", "NOPE00"));
    await assertFails(redeem(MALLORY, "priv1", "OTHER1"));
    await assertFails(redeem(MALLORY, "priv1", "OLD999"));
  });

  it("cannot redeem on behalf of someone else", async () => {
    await assertFails(setDoc(doc(db(MALLORY), "walks/priv1/allowed/bob"),
      { uid: BOB, walkId: "priv1", code: "ABC123", redeemedAt: serverTimestamp() }));
  });

  it("only the host can create, rotate, and delete codes", async () => {
    await assertFails(setDoc(doc(db(MALLORY), "invite_codes/EVIL01"),
      { walkId: "priv1", hostUid: MALLORY, expiresAt: future() }));
    await assertSucceeds(setDoc(doc(db(HOST), "invite_codes/NEW123"),
      { walkId: "priv1", hostUid: HOST, expiresAt: future() }));
    await assertFails(deleteDoc(doc(db(MALLORY), "invite_codes/ABC123")));
    await assertSucceeds(deleteDoc(doc(db(HOST), "invite_codes/ABC123")));
  });

  it("host can revoke a redeemed invite; the user cannot remove others", async () => {
    await seed((f) => setDoc(doc(f, "walks/priv1/allowed/alice"), { uid: ALICE }));
    await assertFails(deleteDoc(doc(db(MALLORY), "walks/priv1/allowed/alice")));
    await assertSucceeds(deleteDoc(doc(db(HOST), "walks/priv1/allowed/alice")));
  });

  it("host can create walk + private invite + code in one transaction", async () => {
    const f = db(HOST);
    await assertSucceeds(runTransaction(f, async (tx) => {
      const ref = doc(f, "walks/p3");
      const codeRef = doc(f, "invite_codes/P3CODE");
      await tx.get(ref);
      await tx.get(codeRef);
      tx.set(ref, walk({ visibility: "private" }));
      tx.set(doc(f, "walks/p3/private/invite"), { hostUid: HOST, walkId: "p3", shareCode: "P3CODE" });
      tx.set(codeRef, { walkId: "p3", hostUid: HOST, expiresAt: future() });
    }));
  });
});

describe("host rating aggregation", () => {
  it("anyone signed in can aggregate a host's reviews", async () => {
    const { getAggregateFromServer, average, count } = require("firebase/firestore");
    const { collectionGroup } = require("firebase/firestore");
    await seed((f) => setDoc(doc(f, "walks/open1/reviews/alice"), { hostUid: HOST, hostRating: 4 }));
    const q = query(collectionGroup(db(BOB), "reviews"),
      where("hostUid", "==", HOST), where("hostRating", ">=", 1));
    await assertSucceeds(getAggregateFromServer(q, { avg: average("hostRating"), n: count() }));
  });
});
