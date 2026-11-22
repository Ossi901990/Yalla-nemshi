# Handoff: continue work here

**Last updated:** 2026-11-22
**Branch:** `claude/inspiring-goldberg-xlwagq` (not merged into `main` yet)
**Firebase plan:** Spark (free) for now. **The owner will pay for Blaze when the app is
published.** Build everything so it works on Spark today, with paid features ready
to switch on (the `AppFeatures` setting plus the "⭐ When upgrading" checklist below).
**Testing setup:** the owner works alone, with no phone/emulator. Testing is done on
the web build with two accounts (see "How to test" below).

## Where we are

Manual testing: **steps 1–6 passed; resume at step 7.** On 2026-11-22 a batch of
fixes landed (see "Fixed on 2026-11-22"), so re-check the items marked 🔁 too.

| Item | Status |
|---|---|
| Firestore rules (`firestore.rules`) | ✅ Deployed 2026-11-22 (email, notification and route rules) |
| Firestore indexes (`firestore.indexes.json`) | ✅ Deployed, all **Enabled** |
| Storage rules / Cloud Functions | ❌ Not deployed; need Blaze |
| `flutter analyze` / `flutter test` | ✅ No issues / 22 passing |
| Rules tests | ✅ 73 passing |
| In-app notifications (Option A) | ✅ Built, ⏳ not tested in the app |
| Per-walker GPS routes | ✅ Built, ⏳ needs a real phone to test properly |
| Manual test pass | ⏳ Steps 1–6 passed, 7–8 + 🔁/🆕 items left |

## How to test (solo, web)

1. Start the app, either way (same app):
   - `flutter run -d web-server --web-port 5050` (**default since 2026-11-22**): open
     `http://localhost:5050` in your normal Chrome for account **A** (stays signed
     in). App errors show in the browser console (F12), not in the terminal.
   - `flutter run -d chrome --web-port 5050`: opens its own Chrome window (fresh
     profile, sign in each launch) and errors show in the terminal, so Claude can
     watch them. On 2026-11-22 it once failed with "Failed to establish connection
     with the application instance in Chrome"; if that repeats, close leftover
     debug Chrome windows and retry, or use web-server mode.
2. Open `http://localhost:5050` in an **Incognito** window for account **B**.
3. A third account (for "stranger" checks) = log out in Incognito and sign up again.
4. Desktop isn't supported: the `windows/`, `macos/` and `linux/` folders were removed
   (regenerate with `flutter create --platforms=windows .` if ever needed).

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
6. ✅ **Review a walk (B)** after the walk ended: saved, and A's profile shows the host
   rating, hosted/joined counts, total stats, past walk, name and photo (after the
   fix below, `29a50ec`).
7. ⏭️ **Friend request A → B, accept on B.** Both should see each other as friends.
   🔁 Open B's profile from A's friend list: name, stats and B's open walks should
   show (previously empty on Spark). No emails should appear anywhere.
8. ⬜ **Block / report a user.** Should succeed without errors.
9. 🔁 **Edit Profile → change name.** Then join a walk / check the friend list from the
   other account: the new name should appear.
10. 🔁 **Create walk:** both tabs (Point to point / Loop) switch correctly and save.
    🆕 The "Photos (Optional)" section should be **hidden** (paid-plan feature).
11. 🆕 **In-app notifications** (bell / notifications screen):
    - B joins A's walk → A gets "New walker joined! 🎉". B leaves → "Walker left 👋".
    - B sends a walk chat message → A gets it (and vice versa).
    - A cancels the walk → B gets "Walk cancelled ❌".
    - A starts the walk (only works near its start time) → B gets "Walk starting ⏰".
    - DM between friends → the other person gets it.
    - If A blocks B, B's actions no longer notify A.
12. 🆕 **No photo buttons** in walk chat, DMs, or the review form (paid-plan feature).
13. 🆕 **GPS routes** (best on a real phone; Chrome can share location but you'd have to
    walk with the laptop): start a walk near its time, confirm as B, walk a bit, end
    it. Each person's summary map should show **their own** route; the host's distance
    appears on the walk. In Firestore: `walks/{id}/routes/{uid}/chunks/*`.

If a friend-profile walk list fails with `failed-precondition` / "requires an index",
follow the link in the error to create it, then add it to `firestore.indexes.json`.

Expected to fail on Spark (not bugs): **phone push** notifications, "walk ended"
notifications, and walk auto-completion. Photo uploads are hidden, not broken.

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
- **Cleanup** (`867f5e1`): mojibake fixed (some user-facing), unused broken
  leaderboard queries removed.
- **README** rewritten (`50639bd`). `rules-tests` `npm test` now works on Windows.
- **In-app notifications without functions** (`536563a`, Option A chosen by the owner):
  see "Notifications" below.
- **GPS routes rewritten** (`d8b5496`): see "GPS tracking" below.
- **Paid-plan setting** (`lib/config/app_features.dart`): photo upload buttons hidden
  until Blaze.
- **Profile stats + finished walks** (`29a50ec`, found in step 6): the profile counted
  only walks on the home list (upcoming/active), so finished walks never counted and
  the host-rating card stayed hidden; nothing marked walks completed on Spark; the
  name came only from device storage. Now `WalkCompletionService` counts each finished
  walk once on the user's own device (history + `walkStats` + badges), triggered when
  the host ends a walk, when the walk summary opens, and as a catch-up when the
  profile opens. The profile loads hosted/joined counts, total km and this week from
  Firestore, and the name falls back to the account profile.
- **Code cleanup:** removed 16 unused Dart files (old screens, widgets, providers,
  helpers), the desktop platform folders, one-time migration scripts, the
  friend-profile Cloud Functions, and unused config files (`.env.example`,
  `codecov.yml`, `copilot-instructions.md`). Verified: analyze, unit, rules tests and
  web build pass, and the compiled web app is **byte-identical** to before the cleanup
  (so no screen changed).

Running the rules tests locally: system Java is 1.8, so point at Android Studio's
bundled JDK 21 for that shell:
`$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"; $env:Path="$env:JAVA_HOME\bin;$env:Path"`

## Backlog (rough priority)

1. **Invite links don't open anything yet.** Hosts can share
   `https://yalla-nemshi-app.firebaseapp.com/invite?walkId=…&code=…`, but nothing
   handles it: there's no web hosting at that URL and no app-link setup.
   `lib/services/deep_link_service.dart` already has the handler (redeem code, open
   the walk); it just isn't called. Needs: read `Uri.base` on web startup, add the
   `app_links` package + Android/iOS link config for phones, and deploy web hosting
   (free on Spark). Entering the code by hand works today.
2. **Badge leaderboards** (`leaderboards/*`) are written only by functions, so they
   are empty on Spark.
3. **Walk completion** lives in `functions/cp4_walk_completion.js` (Blaze).
4. **Refactor huge screens:** `home_screen.dart` (~3.5k lines),
   `create_walk_screen.dart`, `event_details_screen.dart`, `profile_screen.dart`.
   Move the Firestore logic into repositories/providers (Riverpod is already a
   dependency).
5. **Restrict API keys** in Google Cloud Console (owner task: Maps/Geocoding keys are
   hardcoded in `main.dart`, `geocoding_service.dart`, `map_pick_screen.dart`, and
   `AndroidManifest.xml`; restrict by HTTP referrer / Android app signature).
6. **Minor:** ~250 `debugPrint` calls could be trimmed or routed through a logger.

### Product decisions on record

- **Address search (Google Places autocomplete): postponed.** Costs about $7 per
  1,000 lookups; walks use map pin picking + Geocoding (free tier) instead.
- **Offline maps: not supported.** Google Maps for Flutter can't download map tiles
  for offline use. If needed later, the cheap option is caching a static map image
  of each walk (Static Maps API) to show when offline.

## Docs

Only these are kept up to date: this file, [`ESRA.md`](ESRA.md) (a short, plain-English
version of this file for the owner's partner; **update it whenever this file changes**),
[`SECURITY_RULES.md`](SECURITY_RULES.md),
[`GOOGLE_SIGNIN_MOBILE_SETUP.md`](GOOGLE_SIGNIN_MOBILE_SETUP.md) (needed when building
for Android/iOS), and the root [`README.md`](../README.md). Older docs were removed on
2026-11-22 because they were out of date; they're still in git history before that
date if ever needed.

## Notifications (how they work now)

On Spark there are no Cloud Functions, so **the user who causes an event writes the
notification into the other user's list** (`NotificationSender`). In-app only: they
show on the notifications screen and bell when the app is open. No phone push.

| Event | Sent by → to | Type | Hook |
|---|---|---|---|
| Join / leave a walk | walker → host | `walkJoined` / `walkLeft` | `home_screen.dart` join toggle |
| Walk cancelled | host → joined walkers | `walkCancelled` | `WalkControlService.cancelWalk` |
| Walk started | host → joined walkers | `walkStarting` | `WalkControlService.startWalk` |
| Walk chat message | sender → other members | `walkChatMessage` | `walk_chat_screen.dart` |
| Direct message | sender → other person | `dmMessage` | `DmThreadService.sendMessage` |

Rules (`isValidPeerNotification`): sender must be `userId`, fixed fields only, title
≤120 / message ≤300 chars, `timestamp` = server time, expiry ≤31 days, and the
sender must really be linked to the recipient by that walk/DM. Blocked users can't
notify the person who blocked them. Recipients can read/mark read/delete; nobody
else can read or edit them.

The owner decided **no pop-up banners** for chat while the app is open; in-app list +
bell is enough until push arrives with Blaze.

Not covered yet: "walk ended" (needs walk completion, i.e. functions), friend
request/accepted notifications (types exist; could be added the same way), and
walk time/place changes (there's no edit-walk screen; the rule already accepts
`walkRescheduled` / `walkLocationChanged` from the host).

## GPS tracking (how it works now)

Every walker records **their own** route once they confirm (host when starting).
`GPSTrackingService` buffers points on the phone (one every 5 m) and `RouteStore`
saves them in chunks of 30, each written once:

```
walks/{walkId}/routes/{uid}                    summary: distanceKm, averageSpeed, maxSpeed,
                                               durationMinutes, pointsCount
walks/{walkId}/routes/{uid}/chunks/c{millis}   up to 30 points (id = first point's time)
```

About 35 writes per walker for a 5 km walk (the old code used ~17,000 and broke past
~2.5 km). The host's route also fills the walk doc (`actualDistanceKm`,
`routePointsCount`, ...). The summary map and the "latest route" preview show the
viewer's own route, else the host's, else the old `walks/{id}/tracking/point_N` data.
Rules: each walk member writes only their own route; members read all routes.

Fixed along the way: tracking used to stop after any 10 s without movement
(`timeLimit`), participants' routes were silently rejected, and an app restart
mid-walk overwrote earlier points.

## ⭐ When upgrading to the paid Blaze plan

Do these together, in this order:

1. **Make the functions push-only, to avoid DUPLICATE notifications.** These functions
   in `functions/index.js` also write an in-app notification doc, which the app now
   writes itself: `onWalkJoined`, `onWalkLeft`, `onWalkCancelled`, `onWalkUpdated`,
   `onDmMessageCreated`, `onChatMessage`. In each one, **delete the
   `db.collection("users").doc(...).collection("notifications").add({...})` block
   and keep only `sendNotificationToUser(...)`** (the FCM phone push).
   - `onWalkUpdated` / `cp4_walk_completion.js` "walk ended": keep their in-app docs
     only for events the app doesn't send (`walkEnded`; time/location changes).
     Remove the in-app doc for `walkStarting`, which the app sends.
   - The old chat function used type `"chatMessage"`, which the app doesn't
     recognise (it showed as "system maintenance"). The app uses `walkChatMessage`.
2. ~~Remove the friend-profile functions~~ (done 2026-11-22: the app builds friend
   profiles itself).
3. The app already saves FCM tokens to `users/{uid}/fcmTokens` (`NotificationService`).
   Test push on a real Android device (web push also needs a VAPID key).
4. Deploy: `firebase deploy --only functions,storage`. Storage enables photo uploads.
5. **Turn on paid features in the app:** set `paidPlanFeatures = true` in
   `lib/config/app_features.dart`. That shows the photo buttons again (create walk,
   walk chat, DMs, reviews) **and hands walk completion to the functions**
   (`serverWalkCompletion`): the app stops counting finished walks itself, so the
   CP-4 functions in `cp4_walk_completion.js` must be deployed in the same step.
   Walks already counted by the app carry `statsCounted: true` and status
   `completed` in `users/{uid}/walks`, so the functions (which look for
   `actively_walking`) won't count them again. Test each upload, then ship a new
   app build.
6. **GPS (already prepared in `functions/`):** `cleanupOldGpsData` deletes routes of
   walks finished/cancelled 30+ days ago (both formats), and walk completion
   (`cp4_walk_completion.js`) credits each walker with **their own** route distance
   (falls back to the walk's distance). Deploying the functions turns both on.
7. Optional: walk auto-completion + "walk ended" (`functions/cp4_walk_completion.js`),
   badge leaderboards, the monthly email digest (needs SendGrid).
8. Keep `NotificationSender` and its rules. In-app notifications keep working the same
   way, and push gets added on top.

## Deploying

Deploy command (Spark): `firebase deploy --only firestore:rules,firestore:indexes`.
If the CLI returns a 401 error, run `firebase login --reauth`.
When asked to delete indexes that aren't in the file, answer **N**. The exception
is the old `walks (shareCode, cancelled)` index, which is unused and safe to delete.

## How to verify changes

```bash
flutter analyze          # expect no issues
flutter test             # 22 tests
cd rules-tests && npm ci && npm test   # 73 rules tests; needs Node 22+ and Java 21+
```

Every rules change should come with a test in `rules-tests/test/`.

## What was done (earlier sessions)

1. **Cleanup & CI:** removed ~45 MB of zips/backups, moved old docs into
   `docs/archive/` (since deleted), replaced 4 broken workflows with `.github/workflows/flutter_ci.yml`
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
