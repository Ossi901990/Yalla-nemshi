# Security rules & deployment

Everything here works on the free **Spark** plan. No Cloud Functions are needed
for invites or ratings.

## What the rules enforce

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
- **Friendships** can only be created by the user accepting a pending request;
  each edge carries the `requestId` it was accepted from.
- **Host ratings** are computed in the app with an average query over the
  host's reviews; nobody can write a rating directly.
- **Storage**: walk photos are host-only writes; chat images are participant-only;
  all uploads must be images under 10 MB. (Storage itself needs the Blaze plan on
  newer projects.)

## Running the tests

Requires Node 22+ and Java 21+.

```bash
cd rules-tests
npm ci
npm test
```

## Deploying (Spark plan)

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Optional, only if Storage is enabled on the project:

```bash
firebase deploy --only storage
```

Cloud Functions (notifications, friend profile sync, walk completion) need the
Blaze plan and are not required for the features above.
