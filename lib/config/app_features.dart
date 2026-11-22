// lib/config/app_features.dart

/// Switches for features that need the paid Firebase **Blaze** plan.
///
/// The app currently runs on the free Spark plan, which has no Cloud Storage
/// and no Cloud Functions. Features that depend on them are hidden so users
/// don't hit buttons that always fail.
///
/// When the project moves to Blaze, follow "When upgrading to the paid Blaze
/// plan" in docs/HANDOFF.md (deploy Storage rules + functions first), then set
/// [paidPlanFeatures] to `true`.
class AppFeatures {
  AppFeatures._();

  /// Master switch: true once the project is on Blaze with Storage and
  /// functions deployed.
  static const bool paidPlanFeatures = false;

  /// Photo uploads (walk photos, walk chat images, DM images, review photos).
  /// Needs Firebase Storage.
  static const bool photoUploads = paidPlanFeatures;
}
