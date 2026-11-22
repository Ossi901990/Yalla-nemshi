# Security rules & deployment

Everything here works on the free **Spark** plan. No Cloud Functions are needed.
The rules live in [`firestore.rules`](../firestore.rules) and
[`storage.rules`](../storage.rules); every rule has tests in
[`rules-tests/test/`](../rules-tests/test/).

## What the rules enforce

- **Public profiles** (`users/{uid}`) are readable by any signed-in user, so they
  must never hold private data. The `email` field is refused on create and can't
  be added later; older profiles may only remove it.
- **Private walks** are readable only by the host, joined users, and users who
  redeemed an invite (`walks/{id}/allowed/{uid}`). Listing queries must filter on
  `visibility == 'open'`, `hostUid == me`, or `joinedUserUids array-contains me`.
- **Invite codes**:
  - `invite_codes/{CODE}` → `{walkId, hostUid, expiresAt}`. Readable by exact
    code only (never listable), so knowing the code is the secret.
  - `walks/{id}/private/invite` → host-only copy for the host's UI.
  - Redeeming = the user writes `walks/{id}/allowed/{uid}` with the code; the
    rules check the code belongs to that walk and hasn't expired.
- **Joining**: non-hosts may only add/remove themselves and change their own
  `participantStates` entry. Joining a private walk requires a redeemed invite.
- **Walk chat** is readable and writable by the host and joined walkers only.
- **Reviews**: one per walker per walk (`walks/{id}/reviews/{uid}`), only by walk
  members. Others may add a single "helpful" vote.
- **Host ratings** are computed in the app with an average query over the
  host's reviews; nobody can write a rating directly.
- **Friendships** can only be created by the user accepting a pending request;
  each edge carries the `requestId` it was accepted from.
- **DM threads** are private to their two participants, who can't be changed.
- **Blocks and reports**: users manage their own block list; reports are
  write-only for clients (read in the Firebase console).
- **Notifications** (`users/{uid}/notifications`): only the owner reads, marks
  read or deletes them. Another user may *create* one only when it's real
  (`isValidPeerNotification`):
  - sender = `userId`, fixed fields, title ≤120 and message ≤300 chars,
    server timestamp, expiry ≤31 days;
  - join/leave → only to the host of a walk the sender is in; cancel/start →
    only from the host to joined walkers; walk chat → only between walk members;
    DM → only between the thread's two participants;
  - never from someone the recipient has blocked.
- **GPS routes**: each walk member writes only their own route
  (`walks/{id}/routes/{uid}` and its `chunks/c{millis}`, ≤60 points each, never
  deleted by clients). All walk members can read every route. The legacy
  `walks/{id}/tracking/*` points stay readable for old walks.
- **Storage** (Blaze only): walk photos are host-only writes; chat images are
  participant-only; all uploads must be images under 10 MB.

## Running the tests

Requires Node 22+ and Java 21+ (on this machine: Android Studio's bundled JDK,
see `docs/HANDOFF.md`).

```bash
cd rules-tests
npm ci
npm test
```

## Deploying (Spark plan)

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Storage rules and Cloud Functions need the Blaze plan. See "When upgrading to the
paid Blaze plan" in [`HANDOFF.md`](HANDOFF.md) before deploying them.
