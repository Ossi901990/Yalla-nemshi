# Handoff: continue work here

**Last updated:** 2026-11-16
**Branch:** `claude/inspiring-goldberg-xlwagq` (not merged into `main` yet)
**Firebase plan:** Spark (free). The owner does not want paid plans for now, so avoid
anything that needs Cloud Functions or Storage.
**Testing setup:** the owner works alone, with no phone/emulator. Testing is done on
the web build with two accounts (see "How to test" below).

## Where we are

Device testing is **in progress: steps 1–5 passed, resume at step 6.**

| Item | Status |
|---|---|
| Firestore rules (`firestore.rules`) | ✅ Deployed |
| Firestore indexes (`firestore.indexes.json`) | ✅ Deployed, all **Enabled** |
| Old test walks | ✅ Deleted (no migration needed) |
| Storage rules / Cloud Functions | ❌ Not deployed; need Blaze |
| `flutter analyze` / `flutter test` | ✅ No issues / 14 passing (2026-11-16) |
| Manual test pass | ⏳ Steps 1–5 passed, 6–8 left |

### Uncommitted change

- `lib/screens/create_walk_screen.dart`: `DefaultTabController` `length: 3` → `2`.
  The "Free walk" tab had been removed but the length wasn't updated, which threw
  "Controller's length property (3) does not match the number of tabs (2)" and
  broke the create-walk tab bar. Commit this with the next batch of fixes.

## How to test (solo, web)

1. `flutter run -d chrome --web-port 5050` opens account **A** in its own Chrome window
   (fresh profile each launch, so sign in again after every restart).
2. Open `http://localhost:5050` in an **Incognito** window for account **B**.
3. A third account (for "stranger" checks) = log out in Incognito and sign up again.
4. Windows desktop is not an option: `main.dart` only has a hardcoded config for web.

Harmless log noise: `NetworkImageLoadException ... statusCode: 429` from
`lh3.googleusercontent.com` (Google profile photos are rate-limited on localhost).

## Test checklist

1. ✅ **Open walk** shows on A's home and in B's Nearby walks.
2. ✅ **Private walk** shows the invite code to A, hidden from B.
3. ✅ **Join with code (B)** via search → "enter invite code". A sees the join, B sees the walk.
4. ✅ **Regenerate code (host).** Passed per owner; not 100% confirmed that the *old*
   code was tried and rejected (rules tests cover it). Re-check if convenient.
5. ✅ **Walk chat (text)** works both ways in real time.
6. ⏭️ **Review a walk (B)** without a photo. It should save, and A's profile host
   rating should update. If the review button only appears after a walk ends,
   check that condition.
7. ⬜ **Friend request A → B, accept on B.** Both should see each other as friends.
8. ⬜ **Block / report a user.** Should succeed without errors.

Expected to fail on Spark (not bugs): photo uploads, push notifications, **all
in-app notifications** (see backlog #2), friend profile snapshots (`friend_profiles`),
and walk auto-completion.

If something fails with `permission-denied`, compare the write against
`firestore.rules` and add a test in `rules-tests/test/firestore.test.js`.

## Findings from testing (not yet fixed)

- **Participant names aren't shown** on the walk details screen. It only shows avatars
  and a count (`event_details_screen.dart` ~L2037–2148). Names are saved in
  `joinedUserNames` but only `active_walk_screen.dart` displays them. Idea: a tappable
  participant list on the details screen.
- **Email sign-ups have no display name**, so they're stored as `User <uid prefix>`
  (`home_screen.dart` ~L1340). Idea: add a name field at sign-up.
- **Avatars with no photo / a failed load** render blank. Add an `errorBuilder` /
  initials fallback.
- **`create_walk_screen.dart`** still has the dead "Free walk" UI branch
  (`_walkTypeIndex == 2`), and it calls `tabController.addListener` inside `build`,
  which adds a new listener on every rebuild.

## Backlog (rough priority)

1. **Hide user emails.** `users/{uid}` (including `email`) is readable by any
   signed-in user, and `friend_list_screen.dart` shows other users' emails. Move
   email to a private subdoc and update `FirestoreUser`, `firestore_sync_service`,
   `profile_migration_service`, and the friend list UI.
2. **Notifications on Spark.** Every notification doc is created by a Cloud Function;
   the client only reads and marks them, and the rules (`users/{uid}/notifications`)
   only let the owner write. So nothing appears in-app today. Options:
   - Let the sender's client write a notification for another user, with rules
     limited to valid cases (same walk/chat, fixed types, `fromUid == auth.uid`).
   - Unread badges derived from chat `lastMessage` time vs the user's last-read time.
3. **Other Spark gaps:** `friend_profiles` could be read from `users` + stats directly;
   walk completion lives in `functions/cp4_walk_completion.js`.
4. **Participant names / display names** (see Findings).
5. **GPS tracking:** every participant writes `walks/{id}/tracking/point_N`, so
   their points collide. The rules currently allow the host only. If participants
   should track too, use per-user paths.
6. **Leaderboards:** `UserStatsService.getTopWalkers/getTopHosts` query
   `collectionGroup('walkStats')`, but `walkStats` is a doc id, so the result is
   always empty (nothing calls it today).
7. **Refactor huge screens:** `home_screen.dart` (~3.5k lines),
   `create_walk_screen.dart`, `event_details_screen.dart`, `profile_screen.dart`.
   Move the Firestore logic into repositories/providers (Riverpod is already a
   dependency).
8. **Restrict API keys** in Google Cloud Console (Maps/Geocoding keys are hardcoded
   in `main.dart`, `geocoding_service.dart`, `map_pick_screen.dart`, and
   `AndroidManifest.xml`).
9. **Minor:** fix mojibake comments in `home_screen.dart` (e.g. `Γ£à`), trim the
   ~250 `debugPrint` calls, and replace the template README intro.

## Deploying

Deploy command (Spark): `firebase deploy --only firestore:rules,firestore:indexes`.
If the CLI returns a 401 error, run `firebase login --reauth`.
When asked to delete indexes that aren't in the file, answer **N**. The exception
is the old `walks (shareCode, cancelled)` index, which is unused and safe to delete.

## How to verify changes

```bash
flutter analyze          # expect no issues
flutter test             # 14 tests
cd rules-tests && npm ci && npm test   # 53 rules tests; needs Node 22+ and Java 21+
```

Every rules change should come with a test in `rules-tests/test/`.

## What was done (earlier sessions)

1. **Cleanup & CI:** removed ~45 MB of zips/backups, moved old docs into
   `docs/archive/`, replaced 4 broken workflows with `.github/workflows/flutter_ci.yml`
   (Flutter 3.50.0: analyze, tests, rules tests, web build), and fixed the 4 failing
   unit tests.
2. **Security rules rewrite** (see `docs/SECURITY_RULES.md`): private walks hidden
   from strangers (list queries must filter on `visibility == 'open'`, `hostUid`, or
   `joinedUserUids`); users only join/leave themselves; private walks need a redeemed
   invite; friendships need a real pending request; DM threads private; block and
   report work; reviews at `walks/{id}/reviews/{uid}`.
3. **Spark-friendly invites:** `invite_codes/{CODE}` (get-only) and a host-only
   `walks/{id}/private/invite`. A user redeems by writing `walks/{id}/allowed/{uid}`
   with the code, and the rules validate it. Code: `lib/services/invite_service.dart`.
4. **Host rating:** an average/count aggregate over the host's reviews
   (`lib/services/host_rating_service.dart`). No function involved.
5. **Other fixes:** walk chat image message rules, chat notification trigger path,
   `WalkEvent.toMap` writes `visibility`, and the friend accept flow is atomic.

## When it's ready

Once steps 6–8 pass, commit the outstanding fix, open a PR from this branch into
`main`, and merge it.
