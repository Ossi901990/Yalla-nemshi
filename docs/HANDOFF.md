# Work in progress: notes for the next session

Branch: `claude/inspiring-goldberg-xlwagq`

## Done
1. Repo cleanup, single CI workflow (`.github/workflows/flutter_ci.yml`), tests green.
2. Security rules rewrite (`firestore.rules`, `storage.rules`) with emulator tests
   in `rules-tests/` (`npm test`). See `docs/SECURITY_RULES.md`.
3. Fixed: reviews, walk chat images, chat notification trigger path, block/report,
   friend accept flow, recurring walks missing `visibility`.
4. Spark-plan friendly: invite codes via `invite_codes/{CODE}` + rules
   (`lib/services/invite_service.dart`); host rating via aggregate query
   (`lib/services/host_rating_service.dart`). Removed the invite/rating Cloud Functions.

## Not deployed yet
Owner deploys with `firebase deploy --only firestore:rules,firestore:indexes`.
Old test walks can simply be deleted in the console (or run
`functions/scripts/migrate_private_invites.js` with admin credentials).

## Known issues / next steps
- `users/{uid}` docs (including email) are readable by any signed-in user → move
  email to a private subdoc; friend list screen shows other users' emails.
- GPS tracking: all participants write `walks/{id}/tracking/point_N` (collide);
  rules currently allow host only. Needs per-user paths if participants track.
- `UserStatsService.getTopWalkers/getTopHosts` query collectionGroup('walkStats'),
  which is a doc id, not a collection → always empty (unused today).
- On Spark: no push notifications, `friend_profiles` sync, or walk auto-completion
  (all Cloud Functions). Storage likely requires Blaze.
- Very large screens (home_screen.dart ~3.5k lines etc.) should be split up.
