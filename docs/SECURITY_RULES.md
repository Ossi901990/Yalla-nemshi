# Security rules & deployment

## What the rules enforce

- **Private walks** are readable only by the host, joined users, and users who
  redeemed an invite (`walks/{id}/allowed/{uid}`). Listing queries must filter on
  `visibility == 'open'`, `hostUid == me`, or `joinedUserUids array-contains me`.
- **Invite codes** live in `walks/{id}/private/invite` (host-only). They are
  verified by the `redeemInviteCode` Cloud Function and are never stored on the
  walk document.
- **Joining**: non-hosts may only add/remove themselves and change their own
  `participantStates` entry. Joining a private walk requires a redeemed invite.
- **Friendships** can only be created by the user accepting a pending request;
  each edge carries the `requestId` it was accepted from.
- **Host ratings** are computed by the `onWalkReviewWritten` function; clients
  cannot write `users/{uid}/stats/hostRating`.
- **Storage**: walk photos are host-only writes; chat images are participant-only;
  all uploads must be images under 10 MB.

## Running the tests

Requires Node 22+ and Java 21+.

```bash
cd rules-tests
npm ci
npm test
```

## Deploying

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

```bash
cd functions && npm ci && firebase deploy --only functions
```

Cloud Functions require the Blaze (pay-as-you-go) plan.

After the first deploy of these rules, run the one-time migration (moves invite
codes off walk documents and fills in missing `visibility`):

```bash
cd functions && npm run migrate:privateInvites
```
