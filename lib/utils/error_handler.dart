import 'dart:async';
import 'package:flutter/material.dart';
import '../services/crash_service.dart';
import '../models/app_exception.dart';

/// Centralized error handling and user-friendly messaging
class ErrorHandler {
  /// Show a user-friendly error dialog with a message and optional action
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onAction();
              },
              child: Text(actionLabel),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show a SnackBar error message with user-friendly amber color
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(
          0xFFD97706,
        ), // Warm amber instead of harsh red
        duration: duration,
      ),
    );
  }

  /// Log an error and optionally show user-facing message
  static Future<void> handleError(
    BuildContext? context,
    Object error,
    StackTrace stackTrace, {
    required String action,
    String? userMessage,
  }) async {
    // Always log to Crashlytics
    CrashService.recordError(error, stackTrace);

    debugPrint(
      '❌ ERROR in $action: $error\n'
      'Stack trace: $stackTrace',
    );

    // Show user message if context is available
    if (context != null && context.mounted) {
      final message = userMessage ?? _getDefaultUserMessage(error);
      showErrorSnackBar(context, message);
    }
  }

  /// Log a fatal error
  static Future<void> handleFatalError(
    BuildContext? context,
    Object error,
    StackTrace stackTrace, {
    required String action,
    String? userMessage,
  }) async {
    // Log as fatal to Crashlytics
    CrashService.recordFatalError(error, stackTrace);

    debugPrint(
      '🔴 FATAL ERROR in $action: $error\n'
      'Stack trace: $stackTrace',
    );

    // Show user message if context is available
    if (context != null && context.mounted) {
      final message =
          userMessage ??
          'Something went wrong. Please restart the app and try again.';

      await showErrorDialog(context, title: 'Error', message: message);
    }
  }

  /// Get user-friendly error message from any error object
  static String getUserMessage(Object error) {
    return _getDefaultUserMessage(error);
  }

  /// Extract user-friendly message from error
  static String _getDefaultUserMessage(Object error) {
    final errorStr = error.toString();

    // Handle AppException types (already user-friendly)
    if (error is AppException) {
      return error.message;
    }

    // Convert technical Firebase errors to friendly messages
    if (errorStr.contains('[cloud_firestore/unavailable]') ||
        errorStr.contains('unavailable')) {
      return 'Network connection issue. Please try again.';
    }
    if (errorStr.contains('[cloud_firestore/permission-denied]') ||
        errorStr.contains('permission-denied')) {
      return 'You don\'t have permission to do this.';
    }
    if (errorStr.contains('[cloud_firestore/unauthenticated]') ||
        errorStr.contains('unauthenticated')) {
      return 'Please sign in and try again.';
    }
    if (errorStr.contains('[cloud_firestore/not-found]') ||
        errorStr.contains('not-found')) {
      return 'The requested item was not found.';
    }
    if (errorStr.contains('[cloud_firestore/deadline-exceeded]') ||
        errorStr.contains('deadline-exceeded')) {
      return 'Request timed out. Please try again.';
    }
    if (errorStr.contains('[cloud_firestore/cancelled]')) {
      return 'Operation was cancelled. Please try again.';
    }
    if (errorStr.contains('[cloud_firestore/already-exists]')) {
      return 'This item already exists.';
    }
    if (errorStr.contains('FirebaseException') ||
        errorStr.contains('firebase')) {
      return 'Unable to sync data. Check your internet connection.';
    }
    if (errorStr.contains('SocketException') ||
        errorStr.contains('TimeoutException')) {
      return 'Network error. Please check your internet connection.';
    }
    if (errorStr.contains('PermissionDeniedException')) {
      return 'Permission denied. Check your app settings.';
    }
    if (errorStr.contains('NetworkImageLoadException')) {
      return 'Unable to load image. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// Handle AppException with typed handling
  static Future<void> handleAppException(
    BuildContext? context,
    AppException exception, {
    required String action,
  }) async {
    // Log to Crashlytics
    CrashService.recordError(
      exception,
      StackTrace.current,
      reason: 'AppException in $action: ${exception.code}',
    );

    debugPrint('❌ $action: ${exception.message} (Code: ${exception.code})');

    // Show user message
    if (context != null && context.mounted) {
      showErrorSnackBar(context, exception.message);
    }
  }
}

/// Wrapper for safe async operations
Future<T?> safeAsyncOperation<T>(
  Future<T> Function() operation, {
  required String operationName,
  required BuildContext? context,
  String? customErrorMessage,
}) async {
  try {
    return await operation();
  } catch (e, st) {
    await ErrorHandler.handleError(
      context,
      e,
      st,
      action: operationName,
      userMessage: customErrorMessage,
    );
    return null;
  }
}
