import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Service to report errors and exceptions to Firebase Crashlytics
class CrashService {
  static final _instance = FirebaseCrashlytics.instance;

  /// Log a non-fatal error (won't crash the app but will be tracked)
  static void recordError(
    dynamic error,
    StackTrace stackTrace, {
    String? reason,
    Iterable<Object>? information,
  }) {
    _instance.recordError(
      error,
      stackTrace,
      reason: reason,
      information: information ?? const [],
    );
  }

  /// Log a fatal error
  static void recordFatalError(dynamic error, StackTrace stackTrace) {
    _instance.recordError(error, stackTrace, fatal: true);
  }

  /// Set user-specific information for crash reports
  static void setUserIdentifier(String userId) {
    _instance.setUserIdentifier(userId);
  }

  /// Clear user information
  static void clearUserIdentifier() {
    _instance.setUserIdentifier('');
  }

  /// Add custom key-value pairs to crash reports
  static void setCustomKey(String key, Object value) {
    _instance.setCustomKey(key, value);
  }

  /// Log a message without crashing
  static void log(String message) {
    _instance.log(message);
  }
}
