# Yalla Nemshi

A social walking app: create a walk, invite people or let nearby walkers find it,
chat with the group, and review the walk afterwards. Built with Flutter and
Firebase (Auth + Firestore).

## Features

New to the app? Start with [`docs/WHAT_IS_YALLA_NEMSHI.md`](docs/WHAT_IS_YALLA_NEMSHI.md).

- **Open and private walks.** Open walks show up in Nearby walks. Private walks
  are only visible to the host, joined walkers, and people who redeemed an invite.
- **Invite codes.** A private walk gets a short code (and link) the host can
  share, regenerate, or extend. Redeeming happens entirely through Firestore
  security rules, so no Cloud Function is needed.
- **Walk chat** for the host and joined walkers.
- **Reviews and host ratings.** One review per walker per walk. The host's
  rating is an average computed from reviews, so hosts can't set their own.
- **Friends, DMs, blocking and reporting.**

## Privacy model

Access is enforced in [`firestore.rules`](firestore.rules), not just hidden in the UI:

- Private walks can't be read, listed, or guessed by ID by anyone outside the walk.
- Users can only add or remove themselves from a walk.
- Friendships need an accepted request. DM threads are private to their two
  participants.
- Public profiles (`users/{uid}`) never store the email address.

See [`docs/SECURITY_RULES.md`](docs/SECURITY_RULES.md) for the details.

## Firebase plan

The project runs on the free **Spark** plan. In-app notifications (joins, leaves,
cancellations, walk start, chat and DMs) are written by the sender's app and
checked by the security rules. These features need Cloud Functions or Storage
(Blaze plan) and are switched off for now: photo uploads (hidden via
`lib/config/app_features.dart`), phone push notifications, and automatic walk
completion. The function code is kept in [`functions/`](functions/);
see "When upgrading to the paid Blaze plan" in [`docs/HANDOFF.md`](docs/HANDOFF.md)
before deploying it.

## Development

Requirements: Flutter 3.50, plus Node 22+ and Java 21+ for the rules tests.

```bash
flutter pub get
flutter run -d chrome --web-port 5050   # web build (Firebase config is in lib/main.dart)
flutter analyze
flutter test
cd rules-tests && npm ci && npm test    # Firestore/Storage rules tests on the emulator
```

Deploy rules and indexes (Spark):

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Every rules change should come with a test in `rules-tests/test/`.

## Project status

Current progress, the manual test checklist, and the backlog are in
[`docs/HANDOFF.md`](docs/HANDOFF.md).
