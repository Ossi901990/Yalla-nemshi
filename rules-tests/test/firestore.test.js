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
