import 'dart:async';
import 'package:flutter/material.dart';
import '../services/crash_service.dart';

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

  /// Show a SnackBar error message
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
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
      final message = userMessage ?? 
        'Something went wrong. Please restart the app and try again.';
      
      await showErrorDialog(
        context,
        title: 'Error',
        message: message,
      );
    }
  }

  /// Extract user-friendly message from error
  static String _getDefaultUserMessage(Object error) {
    final errorStr = error.toString();

    if (errorStr.contains('FirebaseException')) {
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
