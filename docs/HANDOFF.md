# Handoff: continue work here

**Last updated:** 2026-11-24
**Branch:** everything up to `607294a` is **merged into `main`** (2026-11-23, after CI passed).
Start new work (e.g. the design overhaul) on a **new branch** from `main`.
**Firebase plan:** Spark (free) for now. **The owner will pay for Blaze when the app is
published.** Build everything so it works on Spark today, with paid features ready
to switch on (the `AppFeatures` setting plus the "⭐ When upgrading" checklist below).
**Testing setup:** the owner works alone, with no phone/emulator. Testing is done on
the web build with two accounts (see "How to test" below).

## Where we are

Manual testing: **steps 1–8 passed** (2026-11-23). Still to re-check in the app: the 🔁 and
🆕 items (9–13). All of it is merged into `main`; the design overhaul comes
next (see "Next up").

| Item | Status |
|---|---|
| Firestore rules (`firestore.rules`) | ✅ Deployed 2026-11-22 (email, notification and route rules) |
| Firestore indexes (`firestore.indexes.json`) | ✅ Deployed, all **Enabled** |
| Storage rules / Cloud Functions | ❌ Not deployed; need Blaze |
| `flutter analyze` / `flutter test` | ✅ No warnings or errors (40 infos, see below) / 22 passing |
| Rules tests | ✅ 80 passing |
| In-app notifications (Option A) | ✅ Built, ⏳ not tested in the app |
| Per-walker GPS routes | ✅ Built, ⏳ needs a real phone to test properly |
| Manual test pass | ✅ Steps 1–8 passed; ⏳ re-check items 9–13 |

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
7. ✅ **Friend request A → B, accept on B.** Both see each other as friends; B's
   profile from A's friend list shows name, stats and open walks, no email.
8. ✅ **Block / report a user.** Report works. Block needed two fixes (below): it used to
   error out, and afterwards the blocked user could still send a friend request.
   Now a blocked user can't send friend requests or DMs to the blocker.
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
- **Blocking** (`7a21d69`, `0643199`, found in step 8): blocking failed while deleting
  the request A had sent to B (only B could read B's inbox); the sender can now see and
  withdraw their own request. Blocks also weren't enforced: rules now refuse friend
  requests to, friendships with, and DMs to someone who blocked you. The app shows
  neutral messages ("This user isn't accepting friend requests", "You can't send
  messages to this user"). Not covered: a blocked user can still join/chat in the
  blocker's public walks (backlog).
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

## Next up

### Design overhaul: home screen DONE and merged into `main` (2026-11-24)

- **Branch:** `design/home-redesign`, approved by the owner and fast-forwarded into
  `main` at `1a598f0` after CI passed. Start the next screen on a new branch from `main`.
- **Mock-ups:** [`design/home-dark.png`](design/home-dark.png),
  [`design/home-light.png`](design/home-light.png).
- **Design system** (reuse for every screen):
  - `lib/theme/app_palette.dart`: `AppPalette` light/dark (ThemeExtension, use
    `AppPalette.of(context)`); accents lime `#C6F432`, coral `#FF8A5B`, blue `#8AB4FF`,
    teal `#58B8B6`, ink `#0D171B`; `AppSpace` spacing/radii (cards 24).
  - `lib/theme/app_theme.dart`: `AppTheme.light/dark`, `AppText.display()` (Bricolage
    Grotesque, variable font via `FontVariation('wght', …)`) and `AppText.body()` (Inter).
    Old text sizes kept so un-redesigned screens don't shift.
  - `lib/theme/theme_controller.dart`: Light/Dark/System saved on the device. **Default
    is Light** until every screen is redesigned; then switch `_defaultMode` to
    `ThemeMode.system`. Selector: Settings → Appearance. (Dark mode never existed
    before; screens had `isDark` branches that could never run.)
  - `lib/widgets/ui/ui_kit.dart`: `AppCard` (optional coral offset shadow),
    `PillButton`, `RoundIconButton` (badge), `PillLabel`, `TimeChip`, `AvatarStack`,
    `SectionHeader`. `lib/widgets/ui/floating_nav_bar.dart`: `FloatingNavBar`
    (Home, Map → Walks tab, raised + → create walk, Calendar → Events tab, Profile);
    pages leave `FloatingNavBar.reservedHeight` at the bottom.
- **Home:** `lib/screens/home/home_tab.dart` is pure UI; `home_screen.dart` keeps state
  and logic (3,554 → ~1,900 lines). Hero card modes: hosting (Start walk in the start
  window / Details), joined ("You're in"), in progress (I'm here / Open walk),
  suggested next open walk ("I'm in" = join), nothing planned (Create / Browse).
  Chip colours: lime = today/tomorrow, blue = other weekdays, coral = weekend.
  "Walking with" card = distinct people in your walks this week (replaces the
  mock-up's untracked "New people"). Added a search button in the header.
- **Removed with the old home UI:** old banners, calendar, tag-based recommendations
  section, Android step-counter ring (the `pedometer`/`table_calendar` packages may now
  be unused elsewhere; check before removing them from pubspec).
- **Tests:** `test/home_tab_test.dart` renders Home in light + dark for every hero state,
  plus a **fit grid**: 7 phone sizes (Galaxy Fold 280, iPhone SE 320/375, Android 360,
  iPhone 14 390, Pixel 7 412, Pro Max 430) × text size 100/130/160% × 5 states × 2
  modes = 210 layouts, failing on any overflow with the widget + source line.
  `flutter test test/home_tab_test.dart --update-goldens` saves screenshots (incl.
  failures and the Galaxy Fold 160% extreme) to `test/goldens/` (git-ignored).
  **Use this grid for every redesigned screen**: Chrome's F12 device view can't
  simulate the phone's text-size setting, which caused most overflows.
- **Responsive rules used:** big headlines follow text size only up to 115%
  (`AppText.headlineScaler`); greeting and walk title also size to the width; numbers
  and chips shrink to fit (`FittedBox`); cards stack when two don't fit side by side;
  badges and avatar initials don't scale; no fixed heights on cards with text.
- **To check in the browser (owner):** both modes (Settings → Appearance); join from
  "Coming up" (+), the hero "I'm in", Start walk near start time, notifications bell,
  profile, the + create walk, map/calendar tabs. Use Chrome DevTools phone view.
- **Next screens** (same style, Claude designs them): chat. Profile and My calendar are done (see below). Then switch the default to System and move from
  `package:flutter/material.dart` to `package:material_ui`.

### My calendar replaces the Events tab, branch `design/calendar` (2026-11-26, not merged yet)

- **Owner's decision:** no separate "big events" screen for now. A big event is just a
  walk with more people; later it could be an "Event" tag on a walk (bigger group,
  cover photo, highlighted on the Walks tab) instead of a second system.
- `lib/screens/calendar_screen.dart` (pure UI, fed by Home's already-loaded `_events`,
  so **no extra Firestore reads**). Shows upcoming walks you host, joined or starred:
  a 14-day strip with coloured dots (coral host, lime joined, blue starred), tap a day
  to see only it; All / Hosting / Joined / Starred filters; walks grouped Today /
  Tomorrow / weekday / date using `WalkRow`. Empty state: Find a walk (→ Walks tab)
  and Create a walk.
- `events_screen.dart` (the "Coming soon" placeholder) deleted; bar label is now "Calendar".
- Branched from `design/profile`, so merging this also merges the profile work.
- Tests: `test/calendar_test.dart` (84 layouts + 4 behaviour checks). 1,138 tests total.
- Limit: it only knows the walks Home has loaded (the same as the Walks tab), so a
  starred walk far beyond the loaded pages won't show until it's loaded.

### Profile redesigned on branch `design/profile` (2026-11-26, not merged yet)

- Layout moved into a pure `ProfileView` (`lib/screens/profile/profile_view.dart`);
  `profile_screen.dart` keeps loading and every action, and passes the sections that
  load their own data (lifetime stats, host rating, badges, past walks) in as widgets.
- New look: "Profile" header with Friends / Notifications / Settings buttons; card with
  lime-ringed photo, name, walker level pill, bio, age/gender chips, Edit profile;
  "This week" goal card (lime bar, %, motivation); lime / coral / blue stat tiles;
  "More" list card (Analytics, safety tips, CSV/PDF export, switch account, red Sign out).
  The old sections were switched to `AppCard`.
- **Bottom bar fixed:** Profile now uses the same floating bar as Home. Tapping a tab
  closes Profile and returns the tab number to Home (`-1` = create a walk). Before,
  it pushed a second Home screen on top. Both ways into Profile now go through
  `HomeScreen._openProfileQuickSheet`, so the weekly-goal callback is always passed.
- Tests: `test/profile_test.dart` (84 layouts + 3 checks). 1,050 tests total.
- **Owner to check in the browser:** real data in the lifetime / host rating / badges /
  past walks sections (the tests use stand-ins), dark mode, Settings → change weekly
  goal → back, and the bottom bar from Profile.

### Walks tab redesigned and merged into `main` (2026-11-26)

- Shared `WalkRow` (`lib/widgets/walk_row.dart`) used by Home "Coming up", My walks and
  Nearby; adds the date for walks > 6 days away.
- `walks_screen.dart` (709 → 362 lines): "Walks" header + search/bell, lime pill tabs.
  **My walks now lists Hosting and Joined** (it used to show hosted only).
- `nearby_walks_screen.dart` (1,179 → 643): same filters/load-more logic, restyled;
  old card and an unused filter card removed. Note: the "distance" filter means the
  walk's **length**, not how far away it is.
- Tests: `test/walks_tab_test.dart` (168 layouts + sections check). 919 tests total.
- **Map (2026-11-26, merged into `main`):** List / Map switch on
  Nearby (`lib/screens/walks/walks_map_view.dart`). Pins at each walk's meeting point
  (lime = open, coral = joined/hosting), camera fits pins, dark map style, tap pin →
  walk row → walk details. Same filtered walks as the list, **plus your own hosted
  walks** (owner's choice; they stay out of the Nearby list). Home's "Open the map →"
  opens straight into it (`openNearbyMap`).
- **Maps use OpenStreetMap, not Google (owner's choice "C", 2026-11-26).** Google Maps
  needs billing on the Cloud project (the key answers "You must enable Billing"), and
  adding billing to the Firebase project would move it to Blaze. Until then:
  - `flutter_map` + `latlong2`; shared pieces in `lib/widgets/osm_map.dart` (tiles,
    dark-mode tiles, `MapPin`, credit label; OSM requires the credit to stay visible).
  - Walks map, Create walk's location picker (`map_pick_screen.dart`, place search via
    Nominatim, fallback centre Amman) and the walk summary route map all on OSM.
  - `GeocodingService` uses **Nominatim** (coords → city; text → place). Google
    geocoding had been failing silently since there was no billing.
  - `google_maps_flutter` stays only for its `LatLng` data type in create-walk code.
  - **Fair use:** OSM tile servers and Nominatim are fine for testing and small apps
    (≤1 Nominatim request/second, identify the app).
  - **Owner's decision: switch back to Google Maps once the paid plan / billing is
    on.** Steps are in "⭐ When upgrading to the paid Blaze plan" (step 9).
- **Android app id is still the placeholder `com.example.yalla_nemshi`**; change it
  before publishing (map requests identify as `com.yallanemshi.app`).

### Create walk redesigned and merged into `main` (2026-11-24)

- Restyle, not a rewrite: `create_walk_screen.dart` keeps all form logic. New frame
  (back button, "New walk" headline, section headings Where / Who & pace / When /
  Details), sticky Create button (`_buildSubmitBar`), form controls themed in
  `_formTheme` (fields, chips, switch, segmented button). Old teal colours gone.
- **Bug fixed:** no double-tap guard on Create (could create the walk twice); now
  `_isSubmitting` + spinner.
- Dropdowns use `isExpanded` (overflowed with large text); Recurring header wraps.
- Tests: `test/create_walk_test.dart` (point / loop / repeating × 7 phones × 3 text
  sizes × 2 modes = 126 layouts + label check). 750 tests total.
- Not restyled yet: date/time picker dialogs (still the old dark-blue colours in
  dark mode), the map picker screen, and the invite-code card styling.

### Walk details redesigned and merged into `main` (2026-11-24)

- `lib/screens/walk_details/walk_details_view.dart` (pure UI) +
  `event_details_screen.dart` (logic, 2,265 → ~1,400 lines). Designed by Claude in the
  home style (no mock-up).
- Layout: top bar (back, ☆ interested, ⋯ → Report); lime hero (status pill, date,
  title, place, who's going); fact chips (km, duration, pace, who can join, private,
  repeats); Meeting point, Host (+rating), Who's going, Photos, About, Repeats; Host
  tools (checked-in count when active, private invite tools, cancel walk / this date
  / whole series).
- Sticky action bar, main button by situation: visitor "I'm in"; joined "Group chat"
  (+ Leave); active not checked in "I'm here" (+ Not coming); checked in "Open walk";
  host "Start walk" / active "End walk" (+ Open walk); cancelled/ended greyed out.
  Chat round button next to it. Secondary action moves to its own line on narrow
  phones / large text.
- Join, Leave and ☆ now **stay on the screen** (owner's choice): the button flips at
  once ("I'm in" ↔ "Group chat") and the live walk update confirms it; if it doesn't
  within 10 s the button falls back to the real state. ☆ flips instantly with a
  "Added to / Removed from interested" message.
- **☆ is now saved** (it used to be in-memory only and reset on restart):
  `users/{uid}/interested/{walkId}` = `{walkId, createdAt}`, owner-only rule (3 rules
  tests, 83 total). `InterestedService` (watch ids / set); `HomeScreen` listens and
  marks walks while parsing; toggling saves and reverts with a message on failure.
  Rule deployed 2026-11-24.
- Tests: `test/walk_details_test.dart` (9 situations × 7 phones × 3 text sizes × 2
  modes = 378 layouts + main-button check). Shared grid helper:
  `test/support/layout_kit.dart` (`fitGrid`); `--update-goldens` also saves an
  iPhone 14 preview of every situation for design review.

## Backlog (rough priority)

0. **Blocks don't cover walks yet.** A blocked user can still join the blocker's public
   walks and chat there. Decide the behaviour (hide the blocker's walks from them? refuse
   the join in rules?) before building.
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

Only these are kept up to date: this file,
[`WHAT_IS_YALLA_NEMSHI.md`](WHAT_IS_YALLA_NEMSHI.md) (a short explainer of the app for
anyone new; keep it current when features change), [`ESRA.md`](ESRA.md) (a short, plain-English
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
9. **Switch the maps back to Google Maps** (owner's decision, 2026-11-26). Maps moved to
   OpenStreetMap only because Google needs billing:
   - In Google Cloud (project `yalla-nemshi-app`), with billing on, enable **Maps
     JavaScript API**, **Maps SDK for Android/iOS** and **Geocoding API**; add a budget
     alert and per-API daily quotas; restrict the keys (backlog item).
   - `web/index.html`: re-add
     `<script src="https://maps.googleapis.com/maps/api/js?key=…"></script>` (web key).
   - Google versions of the code are in git history: the walks map in commit
     `21bff98` (`lib/screens/walks/walks_map_view.dart`); the location picker, walk
     summary route map and Google `GeocodingService` as they were before commit
     `71e4ac4` (`git show 71e4ac4^:lib/screens/map_pick_screen.dart`, etc.).
     Keep the new parts: app-style pins, own-walks pins, Amman fallback, Sarajevo-style
     county handling for city names (Google returns `locality`).
   - Then `flutter_map` / `latlong2` and `lib/widgets/osm_map.dart` can be removed.
   - Update the walks test grid: Google maps can't render in widget tests, so drop the
     `map` state from `test/walks_tab_test.dart` (keep the switch/pin tests if possible).

## Deploying

Deploy command (Spark): `firebase deploy --only firestore:rules,firestore:indexes`.
If the CLI returns a 401 error, run `firebase login --reauth`.
When asked to delete indexes that aren't in the file, answer **N**. The exception
is the old `walks (shareCode, cancelled)` index, which is unused and safe to delete.

## How to verify changes

Use Flutter **3.50.x** (local machine upgraded to 3.50.1 on 2026-11-23; CI uses 3.50.0).
An older Flutter rewrites `pubspec.lock` on every run. Since 3.47, Flutter flags
`package:flutter/material.dart` as deprecated (replacement: `package:material_ui`);
those ~40 infos are expected, and CI runs `flutter analyze --no-fatal-infos`.

```bash
flutter analyze          # expect 0 warnings/errors; ~40 infos are the material.dart deprecation
flutter test             # 22 tests
cd rules-tests && npm ci && npm test   # 80 rules tests; needs Node 22+ and Java 21+
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

## Merging

The testing branch was merged into `main` on 2026-11-23 (fast-forward, CI green).
For future work: branch from `main`, wait for CI to pass, then merge.
