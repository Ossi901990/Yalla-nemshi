# Handoff: continue work here

**Branch:** `claude/inspiring-goldberg-xlwagq` (not merged into `main` yet)
**Firebase plan:** Spark (free). The owner does not want paid plans for now, so avoid
anything that needs Cloud Functions or Storage.
**Testing setup:** the owner is working alone, with no second account or device yet.

## Current status (as of the last session)

| Item | Status |
|---|---|
| Firestore rules (`firestore.rules`) | ✅ Deployed |
| Firestore indexes (`firestore.indexes.json`) | ⏳ Deployed, still building in the console |
| Old test walks | ✅ Deleted (no migration needed) |
| Storage rules (`storage.rules`) | ❌ Not deployed; Storage likely needs Blaze |
| Cloud Functions | ❌ Not deployed; needs Blaze |
| App tested on a device | ❌ Not yet |

Deploy command (Spark): `firebase deploy --only firestore:rules,firestore:indexes`.
If the CLI returns a 401 error, run `firebase login --reauth`.
When asked to delete indexes that aren't in the file, answer **N**. The exception
is the old `walks (shareCode, cancelled)` index, which is unused and safe to delete.

## Next step: test the app alone

Once all indexes show **Enabled**, run `flutter run`. Walk-throughs that need
another user can be done with a **second test account** (sign up with another
email) on a second emulator, a web build (`flutter run -d chrome`), or by logging
out and back in. Check these:

1. **Create an open walk.** It should appear on the home screen.
2. **Create a private walk.** The invite card should show a code (read from
   `walks/{id}/private/invite`), and it should NOT appear on account B's home screen.
3. **Join with the code (account B).** Use search → "enter invite code", or an
   invite link. B should then see the walk and be able to join.
4. **Regenerate / extend the code (host).** The old code should stop working.
5. **Walk chat (text).** Should work for host and joined users.
6. **Review a walk** after joining. It should save, and the host rating on
   their profile should update.
7. **Friend request A → B, accept on B.** Both should see each other as friends.
8. **Block / report a user.** Should succeed without errors.

Expected to fail on Spark (not bugs): photo uploads (walk photos, chat images,
review photos), push notifications, friend profile snapshots (`friend_profiles`
is written by a function), and walk auto-completion.

If something fails with `permission-denied`, compare the write against
`firestore.rules` and add a test in `rules-tests/test/firestore.test.js`.

## What was done

1. **Cleanup & CI:** removed ~45 MB of zips/backups, moved old docs into
   `docs/archive/`, replaced 4 broken workflows with `.github/workflows/flutter_ci.yml`
   (Flutter 3.50.0: analyze, tests, rules tests, web build), and fixed the 4 failing
   unit tests.
2. **Security rules rewrite** (see `docs/SECURITY_RULES.md`):
   - Private walks are hidden from strangers. List queries must filter on
     `visibility == 'open'`, `hostUid`, or `joinedUserUids`.
   - Users can only join or leave a walk themselves. A private walk needs a
     redeemed invite.
   - Friendships require a real pending request (`requestId` on each edge).
   - DM threads are private to their participants. Block and report now work.
   - Reviews live at `walks/{id}/reviews/{uid}` (previously every write was denied).
3. **Spark-friendly invites:** `invite_codes/{CODE}` (get-only) and a host-only
   `walks/{id}/private/invite`. A user redeems by writing `walks/{id}/allowed/{uid}`
   with the code, and the rules validate it. Code: `lib/services/invite_service.dart`.
4. **Host rating:** an average/count aggregate over the host's reviews
   (`lib/services/host_rating_service.dart`). No function involved.
5. **Other fixes:** walk chat image message rules, chat notification trigger path,
   `WalkEvent.toMap` now writes `visibility`, and the friend accept flow is atomic.

## How to verify changes

```bash
flutter analyze          # expect 0 errors/warnings (about 47 infos, mostly a material.dart deprecation)
flutter test             # 14 tests
cd rules-tests && npm ci && npm test   # 53 rules tests; needs Node 22+ and Java 21+
```

Every rules change should come with a test in `rules-tests/test/`.

## Backlog (rough priority)

1. **Hide user emails.** `users/{uid}` (including `email`) is readable by any
   signed-in user, and `friend_list_screen.dart` shows other users' emails. Move
   email to a private subdoc and update `FirestoreUser`, `firestore_sync_service`,
   `profile_migration_service`, and the friend list UI.
2. **Spark gaps:** decide what to do about features that rely on functions:
   - `friend_profiles`: could be read from `users` + stats directly instead.
   - Walk completion: CP4 functions in `functions/cp4_walk_completion.js`.
   - Notifications: in-app only for now.
3. **GPS tracking:** every participant writes `walks/{id}/tracking/point_N`, so
   their points collide. The rules currently allow the host only. If participants
   should track too, use per-user paths.
4. **Leaderboards:** `UserStatsService.getTopWalkers/getTopHosts` query
   `collectionGroup('walkStats')`, but `walkStats` is a doc id, so the result is
   always empty (nothing calls it today).
5. **Refactor huge screens:** `home_screen.dart` (~3.5k lines),
   `create_walk_screen.dart`, `event_details_screen.dart`, `profile_screen.dart`.
   Move the Firestore logic into repositories/providers (Riverpod is already a
   dependency).
6. **Restrict API keys** in Google Cloud Console (Maps/Geocoding keys are hardcoded
   in `main.dart`, `geocoding_service.dart`, `map_pick_screen.dart`, and
   `AndroidManifest.xml`).
7. **Minor:** fix mojibake comments in `home_screen.dart` (e.g. `Γ£à`), trim the
   ~250 `debugPrint` calls, and replace the template README intro.

## When it's ready

Once the device testing passes, open a PR from this branch into `main` and merge it.
