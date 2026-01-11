/// Custom exception types for the app
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Firebase Authentication errors
class AuthException extends AppException {
  AuthException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory AuthException.fromFirebaseException(dynamic e) {
    final String code = e.code ?? 'auth/unknown-error';
    String message;

    switch (code) {
      case 'user-not-found':
        message = 'No user found with this email.';
        break;
      case 'wrong-password':
        message = 'Incorrect password. Please try again.';
        break;
      case 'invalid-email':
        message = 'Please enter a valid email address.';
        break;
      case 'user-disabled':
        message = 'This user account has been disabled.';
        break;
      case 'too-many-requests':
        message = 'Too many failed login attempts. Try again later.';
        break;
      case 'operation-not-allowed':
        message = 'This sign-in method is not enabled.';
        break;
      case 'email-already-in-use':
        message = 'This email is already registered.';
        break;
      case 'weak-password':
        message = 'Password is too weak. Use at least 6 characters.';
        break;
      case 'account-exists-with-different-credential':
        message = 'An account already exists with this email.';
        break;
      default:
        message = e.message ?? 'Authentication failed. Please try again.';
    }

    return AuthException(
      message: message,
      code: code,
      originalError: e,
    );
  }
}

/// Firestore database errors
class FirestoreException extends AppException {
  FirestoreException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory FirestoreException.fromFirebaseException(dynamic e) {
    final String code = e.code ?? 'firestore/unknown-error';
    String message;

    switch (code) {
      case 'permission-denied':
        message = 'You do not have permission to perform this action.';
        break;
      case 'not-found':
        message = 'The requested document was not found.';
        break;
      case 'already-exists':
        message = 'This document already exists.';
        break;
      case 'invalid-argument':
        message = 'Invalid argument provided.';
        break;
      case 'deadline-exceeded':
        message = 'Request took too long. Please try again.';
        break;
      case 'unavailable':
        message = 'Service is temporarily unavailable. Please try again later.';
        break;
      case 'unauthenticated':
        message = 'You must be signed in to perform this action.';
        break;
      default:
        message = e.message ?? 'A database error occurred. Please try again.';
    }

    return FirestoreException(
      message: message,
      code: code,
      originalError: e,
    );
  }
}

/// Network/connectivity errors
class NetworkException extends AppException {
  NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory NetworkException.fromException(dynamic e) {
    String message;

    if (e.toString().contains('SocketException')) {
      message = 'No internet connection. Please check your network.';
    } else if (e.toString().contains('TimeoutException')) {
      message = 'Request timed out. Please try again.';
    } else if (e.toString().contains('HttpException')) {
      message = 'Network error. Please try again.';
    } else {
      message = 'Network error occurred. Please try again.';
    }

    return NetworkException(
      message: message,
      originalError: e,
    );
  }
}

/// Validation errors
class ValidationException extends AppException {
  ValidationException({
    required super.message,
    super.originalError,
  });
}

/// Generic app errors
class AppError extends AppException {
  AppError({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Parse exception for JSON/data parsing errors
class ParseException extends AppException {
  ParseException({
    required super.message,
    super.originalError,
  });
}

/// Location service errors
class LocationException extends AppException {
  LocationException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory LocationException.fromException(dynamic e) {
    String message;

    if (e.toString().contains('PERMISSION_DENIED')) {
      message = 'Location permission was denied. Enable it in settings.';
    } else if (e.toString().contains('SERVICE_DISABLED')) {
      message = 'Location services are disabled. Enable them to proceed.';
    } else if (e.toString().contains('TIMEOUT')) {
      message = 'Location request timed out. Please try again.';
    } else {
      message = 'Unable to determine location. Please try again.';
    }

    return LocationException(
      message: message,
      originalError: e,
    );
  }
}
