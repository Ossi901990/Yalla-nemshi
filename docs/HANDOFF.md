# Handoff: continue work here

**Last updated:** 2026-11-22
**Branch:** `claude/inspiring-goldberg-xlwagq` (not merged into `main` yet)
**Firebase plan:** Spark (free). The owner does not want paid plans for now, so avoid
anything that needs Cloud Functions or Storage.
**Testing setup:** the owner works alone, with no phone/emulator. Testing is done on
the web build with two accounts (see "How to test" below).

## Where we are

Manual testing: **steps 1–5 passed; resume at step 6.** On 2026-11-22 a batch of
fixes landed (see "Fixed on 2026-11-22"), so re-check the items marked 🔁 too.

| Item | Status |
|---|---|
| Firestore rules (`firestore.rules`) | ⚠️ **Changed (email rule), not deployed yet** |
| Firestore indexes (`firestore.indexes.json`) | ✅ Deployed, all **Enabled** |
| Storage rules / Cloud Functions | ❌ Not deployed; need Blaze |
| `flutter analyze` / `flutter test` | ✅ No issues / 22 passing |
| Rules tests | ✅ 57 passing |
| Manual test pass | ⏳ Steps 1–5 passed, 6–8 left |

**Deploy the rules before testing the new build** (new sign-ups write profiles
without an email; the old deployed rules require one):
`firebase deploy --only firestore:rules`

## How to test (solo, web)

1. `flutter run -d chrome --web-port 5050` opens account **A** in its own Chrome window
   (fresh profile each launch, so sign in again after every restart).
2. Open `http://localhost:5050` in an **Incognito** window for account **B**.
3. A third account (for "stranger" checks) = log out in Incognito and sign up again.
4. Windows desktop is not an option: `main.dart` only has a hardcoded config for web.

Harmless log noise: `NetworkImageLoadException ... statusCode: 429` from
`lh3.googleusercontent.com` (Google profile photos are rate-limited on localhost).
Most avatars now use `UserAvatar`, which swallows these.

## Test checklist

1. ✅ **Open walk** shows on A's home and in B's Nearby walks.
2. ✅ **Private walk** shows the invite code to A, hidden from B.
3. ✅ **Join with code (B)** via search → "enter invite code". A sees the join, B sees the walk.
   🔁 The walk details "People joining" row should now show B's **name** and avatar
   (initials if no photo); tap it for the full list.
4. ✅ **Regenerate code (host).** Not 100% confirmed the *old* code was rejected
   (rules tests cover it).
5. ✅ **Walk chat (text)** works both ways in real time.
6. ⏭️ **Review a walk (B)** without a photo. It should save, and A's profile host
   rating should update. If the review button only appears after a walk ends,
   check that condition.
7. ⬜ **Friend request A → B, accept on B.** Both should see each other as friends.
   🔁 Open B's profile from A's friend list: name, stats and B's open walks should
   show (previously empty on Spark). No emails should appear anywhere.
8. ⬜ **Block / report a user.** Should succeed without errors.
9. 🔁 **Edit Profile → change name.** Then join a walk / check the friend list from the
   other account: the new name should appear.
10. 🔁 **Create walk:** both tabs (Point to point / Loop) switch correctly and save.

If a friend-profile walk list fails with `failed-precondition` / "requires an index",
follow the link in the error to create it, then add it to `firestore.indexes.json`.

Expected to fail on Spark (not bugs): photo uploads, push notifications, **all
in-app notifications** (see backlog #1), and walk auto-completion.

If something fails with `permission-denied`, compare the write against
`firestore.rules` and add a test in `rules-tests/test/firestore.test.js`.

## Fixed on 2026-11-22

All committed on this branch:

- **Emails are private** (`f6fcc84`): no `email` in `users/{uid}`; rules refuse adding
  it; existing profiles have it removed on next sign-in (`FirestoreSyncService`).
  Friend list/search no longer show emails. Debug logs no longer print them.
- **Participant names + avatars** (`0fa3928`): new `ParticipantsRow` and `UserAvatar`
  widgets; walk details shows names from profiles.
- **Edit Profile syncs** (`0fa3928`): it used to save only on the device; now it also
  updates the Auth display name and the Firestore profile.
- **Create walk cleanup** (`8c36081`): dead Free walk branch removed; tab listener
  no longer re-added on every build.
- **Friend profiles without functions** (`d52c652`): `FriendProfileService` builds
  profiles from `users` + stats + host rating, and walk lists from the friend's open
  walks. Also used by the friend activity feed and friend analytics.
- **Cleanup** (`867f5e1`): 59 lines of mojibake fixed (some user-facing), unused
  broken leaderboard queries removed.
- **README** rewritten (`50639bd`). `rules-tests` `npm test` now works on Windows.

Running the rules tests locally: system Java is 1.8, so point at Android Studio's
bundled JDK 21 for that shell:
`$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"; $env:Path="$env:JAVA_HOME\bin;$env:Path"`

## Backlog (rough priority)

1. **Notifications on Spark — needs an owner decision.** Every notification doc is
   created by a Cloud Function; the client only reads them, and the rules only let
   the owner write their own. Options:
   - **A. Sender writes the notification** for the recipient, with rules limited to
     valid cases (same walk/chat or friend request, fixed types, `fromUid == auth.uid`,
     no edits). Brings back the in-app list. Small spam risk from walk members.
   - **B. Unread badges only**, from chat `lastMessage` time vs a per-user last-read
     time. No cross-user writes.
   Push notifications need Blaze either way.
2. **GPS tracking — needs an owner decision.** Only the host may write
   `walks/{id}/tracking/point_N`. If participants should track too, move to
   per-user paths (`tracking/{uid}/points/{n}`) and update rules + reader code.
3. **Badge leaderboards** (`leaderboards/*`) are written only by functions, so they
   are empty on Spark.
4. **Walk completion** lives in `functions/cp4_walk_completion.js` (Blaze).
5. **Refactor huge screens:** `home_screen.dart` (~3.5k lines),
   `create_walk_screen.dart`, `event_details_screen.dart`, `profile_screen.dart`.
   Move the Firestore logic into repositories/providers (Riverpod is already a
   dependency).
6. **Restrict API keys** in Google Cloud Console (owner task: Maps/Geocoding keys are
   hardcoded in `main.dart`, `geocoding_service.dart`, `map_pick_screen.dart`, and
   `AndroidManifest.xml`; restrict by HTTP referrer / Android app signature).
7. **Minor:** ~250 `debugPrint` calls could be trimmed or routed through a logger.

## Deploying

Deploy command (Spark): `firebase deploy --only firestore:rules,firestore:indexes`.
If the CLI returns a 401 error, run `firebase login --reauth`.
When asked to delete indexes that aren't in the file, answer **N**. The exception
is the old `walks (shareCode, cancelled)` index, which is unused and safe to delete.

## How to verify changes

```bash
flutter analyze          # expect no issues
flutter test             # 22 tests
cd rules-tests && npm ci && npm test   # 57 rules tests; needs Node 22+ and Java 21+
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
5. **Create-walk tab crash** (2026-11-16): tab count 3 → 2.

## When it's ready

Once the checklist passes, open a PR from this branch into `main` and merge it.
