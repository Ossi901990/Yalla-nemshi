// Storage security rules tests (cross-service rules read Firestore walk docs).
const { describe, it, before, after, beforeEach } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc } = require("firebase/firestore");
const { ref, uploadBytes, deleteObject } = require("firebase/storage");

let env;
const img = new Uint8Array([0xff, 0xd8, 0xff]);
const jpeg = { contentType: "image/jpeg" };
const st = (uid) => env.authenticatedContext(uid).storage();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-yalla-nemshi",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, "../../storage.rules"), "utf8"),
    },
  });
});

after(async () => env && env.cleanup());

beforeEach(async () => {
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "walks/w1"), {
      hostUid: "host", visibility: "open", joinedUserUids: ["alice"],
    });
    await uploadBytes(ref(ctx.storage(), "walks/w1/0.jpg"), img, jpeg);
  });
});

describe("storage", () => {
  it("host can upload walk photos", async () => {
    await assertSucceeds(uploadBytes(ref(st("host"), "walks/w1/1.jpg"), img, jpeg));
  });

  it("strangers cannot overwrite or delete walk photos", async () => {
    await assertFails(uploadBytes(ref(st("mallory"), "walks/w1/0.jpg"), img, jpeg));
    await assertFails(deleteObject(ref(st("mallory"), "walks/w1/0.jpg")));
  });

  it("non-image uploads are rejected", async () => {
    await assertFails(uploadBytes(ref(st("host"), "walks/w1/x.jpg"), img,
      { contentType: "application/octet-stream" }));
  });

  it("participants can upload chat images (path had no rule before)", async () => {
    await assertSucceeds(uploadBytes(
      ref(st("alice"), "walk_chats/w1/images/123_alice.jpg"), img, jpeg));
  });

  it("chat images: non-participants and impersonation are rejected", async () => {
    await assertFails(uploadBytes(
      ref(st("mallory"), "walk_chats/w1/images/123_mallory.jpg"), img, jpeg));
    await assertFails(uploadBytes(
      ref(st("alice"), "walk_chats/w1/images/123_bob.jpg"), img, jpeg));
  });
});
