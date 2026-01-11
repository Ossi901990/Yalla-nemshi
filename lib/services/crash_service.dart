import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service to report errors and exceptions to Firebase Crashlytics
class CrashService {
  static FirebaseCrashlytics? get _instance => kIsWeb ? null : FirebaseCrashlytics.instance;

  /// Log a non-fatal error (won't crash the app but will be tracked)
  static void recordError(
    dynamic error,
    StackTrace stackTrace, {
    String? reason,
    Iterable<Object>? information,
  }) {
    final inst = _instance;
    if (inst == null) return; // no-op on web
    inst.recordError(
      error,
      stackTrace,
      reason: reason,
      information: information ?? const [],
    );
  }

  /// Log a fatal error
  static void recordFatalError(dynamic error, StackTrace stackTrace) {
    final inst = _instance;
    if (inst == null) return; // no-op on web
    inst.recordError(error, stackTrace, fatal: true);
  }

  /// Set user-specific information for crash reports
  static void setUserIdentifier(String userId) {
    final inst = _instance;
    if (inst == null) return; // no-op on web
    inst.setUserIdentifier(userId);
  }

  /// Clear user information
  static void clearUserIdentifier() {
    final inst = _instance;
    if (inst == null) return; // no-op on web
    inst.setUserIdentifier('');
  }

  /// Add custom key-value pairs to crash reports
  static void setCustomKey(String key, Object value) {
    final inst = _instance;
    if (inst == null) return; // no-op on web
    inst.setCustomKey(key, value);
  }

  /// Log a message without crashing
  static void log(String message) {
    final inst = _instance;
    if (inst == null) return; // no-op on web
    inst.log(message);
  }
}
