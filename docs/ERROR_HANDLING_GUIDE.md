# Error Handling Guide

This guide explains how error handling works in `yalla_nemshi` and how to use it.

## Overview

We have a multi-layer error handling system:

1. **AppException types** — Custom exception classes for different error scenarios
2. **ErrorHandler utility** — Centralized error logging and UI display
3. **Error widgets** — Reusable UI components for showing errors
4. **Riverpod error provider** — Global error state management
5. **Service wrappers** — Automatic error translation in services

---

## Exception Types

### Available Exceptions

Located in `lib/models/app_exception.dart`:

- **AuthException** — Firebase Auth errors (login, signup, permissions)
- **FirestoreException** — Firestore database errors (permission denied, not found, etc.)
- **NetworkException** — Network/connectivity issues
- **ValidationException** — Form/input validation errors
- **LocationException** — GPS/location service errors
- **ParseException** — JSON parsing errors
- **AppError** — Generic app errors (catch-all)

### Factory Constructors

Most exceptions have factory constructors that translate Firebase errors to user-friendly messages:

```dart
// Firebase auth error → AppException
try {
  await _auth.signInWithEmailAndPassword(email: email, password: password);
} on FirebaseAuthException catch (e) {
  throw AuthException.fromFirebaseException(e); // Auto-translates to friendly message
}

// Firebase Firestore error → AppException
try {
  await _firestore.collection('walks').get();
} on FirebaseException catch (e) {
  throw FirestoreException.fromFirebaseException(e);
}

// Network error → AppException
try {
  await http.get(url).timeout(Duration(seconds: 10));
} on SocketException catch (e) {
  throw NetworkException.fromException(e);
}
```

---

## Using ErrorHandler

### Show a Snack Bar Error

```dart
import '../utils/error_handler.dart';

ErrorHandler.showErrorSnackBar(context, 'Something went wrong!');
```

### Show an Error Dialog

```dart
await ErrorHandler.showErrorDialog(
  context,
  title: 'Login Failed',
  message: 'Incorrect email or password.',
  actionLabel: 'Retry',
  onAction: () => _login(),
);
```

### Handle an Exception

```dart
import '../models/app_exception.dart';

try {
  // some operation
} on AppException catch (e) {
  await ErrorHandler.handleAppException(
    context,
    e,
    action: 'Sign In',
  );
} catch (e, st) {
  await ErrorHandler.handleError(
    context,
    e,
    st,
    action: 'Sign In',
    userMessage: 'Failed to sign in. Please try again.',
  );
}
```

### Handle Fatal Errors

```dart
try {
  // some operation
} catch (e, st) {
  await ErrorHandler.handleFatalError(
    context,
    e,
    st,
    action: 'Initialize App',
    userMessage: 'The app encountered a critical error. Please restart.',
  );
}
```

---

## Using Error Widgets

### ErrorWidget — Generic Error Display

```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      message: 'Failed to load walks.',
      title: 'Error',
      icon: Icons.cloud_off_outlined,
      onRetry: () {
        // Retry logic
      },
    );
  }
}
```

### LoadingErrorWidget — Loading State Error

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walks = ref.watch(walksProvider);
    
    return walks.when(
      data: (data) => ListView(children: [...]),
      loading: () => const CircularProgressIndicator(),
      error: (err, st) => LoadingErrorWidget(
        message: 'Unable to load walks.',
        onRetry: () => ref.refresh(walksProvider),
      ),
    );
  }
}
```

### EmptyStateWidget — Empty Data Display

```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Walks Found',
      message: 'You haven\'t created any walks yet.',
      icon: Icons.directions_walk_outlined,
      actionLabel: 'Create a Walk',
      onAction: () {
        Navigator.pushNamed(context, CreateWalkScreen.routeName);
      },
    );
  }
}
```

### ErrorBanner — Top Banner

```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ErrorBanner(
          message: 'Network connection lost.',
          onRetry: () => _retry(),
          onDismiss: () => setState(() => _showError = false),
        ),
        // ... rest of screen
      ],
    );
  }
}
```

### LoadingPlaceholder — Skeleton Loading

```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LoadingPlaceholder(height: 60, width: double.infinity),
        const SizedBox(height: 12),
        LoadingPlaceholder(height: 60, width: double.infinity),
        const SizedBox(height: 12),
        LoadingPlaceholder(height: 60, width: 200),
      ],
    );
  }
}
```

---

## Using Error Provider

### Global Error State

```dart
import '../providers/error_provider.dart';

class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorState = ref.watch(errorStateProvider);
    final hasError = ref.watch(hasErrorProvider);
    final errorMessage = ref.watch(errorMessageProvider);

    return Column(
      children: [
        if (hasError)
          ErrorBanner(
            message: errorMessage ?? 'An error occurred',
            onDismiss: () {
              ref.read(errorStateProvider.notifier).clearError();
            },
          ),
        // ... rest of screen
      ],
    );
  }
}
```

### Wrap Operations with Error Handling

```dart
Future<void> _createWalk() async {
  final result = await executeWithErrorHandling(
    ref,
    () => createWalkInFirestore(walkData),
  );

  if (result != null) {
    // Success
    ref.refresh(walksProvider);
  } else {
    // Error already set in errorStateProvider
  }
}
```

---

## Service Wrappers

### GeocodingService (Location Errors)

```dart
import '../services/geocoding_service.dart';
import '../models/app_exception.dart';

try {
  final city = await GeocodingService.getCityFromCoordinates(
    latitude: position.latitude,
    longitude: position.longitude,
  );
} on LocationException catch (e) {
  print('Location error: ${e.message}');
}
```

### FirestoreErrorHandler (Database Errors)

```dart
import '../services/firestore_error_handler.dart';
import '../models/app_exception.dart';

try {
  // Automatic error handling & translation
  final doc = await FirestoreErrorHandler.getDocument(
    _firestore.collection('walks').doc(walkId).withConverter(...),
  );
} on FirestoreException catch (e) {
  print('Database error: ${e.message}');
}
```

---

## Migration Checklist

Use this when adding error handling to a screen or service:

- [ ] Import `app_exception.dart` and appropriate exception type
- [ ] Wrap operations in `try-catch` with typed exceptions
- [ ] Use `ErrorHandler.handleAppException()` or similar
- [ ] Replace generic error messages with typed exceptions
- [ ] Add error widgets to loading/error states
- [ ] Test error paths (offline, permission denied, timeout, etc.)

---

## Error Codes

Common error codes used throughout:

**Auth Codes:**
- `auth/user-not-found`
- `auth/wrong-password`
- `auth/invalid-email`
- `auth/weak-password`
- `auth/email-already-in-use`

**Firestore Codes:**
- `firestore/permission-denied`
- `firestore/not-found`
- `firestore/already-exists`
- `firestore/unauthenticated`

**Location Codes:**
- `location/permission-denied`
- `location/service-disabled`
- `location/timeout`

**Network Codes:**
- `network/socket-error`
- `network/timeout`
- `network/http-error`

---

## Testing Errors

Example test for error handling:

```dart
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/app_exception.dart';

void main() {
  test('AuthException from Firebase', () {
    final mockFirebaseException = FirebaseAuthException(
      code: 'wrong-password',
      message: 'The password is invalid.',
    );

    final appException = AuthException.fromFirebaseException(
      mockFirebaseException,
    );

    expect(appException.message, contains('Incorrect password'));
    expect(appException.code, 'wrong-password');
  });

  test('FirestoreException permission denied', () {
    final appException = FirestoreException(
      message: 'Permission denied',
      code: 'permission-denied',
    );

    expect(appException.message, 'You do not have permission');
  });
}
```

---

## Best Practices

1. **Always use typed exceptions** — Don't throw generic `Exception()`; use `AuthException`, `FirestoreException`, etc.
2. **Provide user-friendly messages** — Translate technical errors to plain language
3. **Log to Crashlytics** — Use `CrashService` for non-fatal and fatal errors
4. **Show loading states** — Use skeleton loaders before showing errors
5. **Provide retry paths** — Give users a way to retry failed operations
6. **Test error paths** — Simulate network failures, permissions, etc.
7. **Clean up errors** — Call `ref.refresh()` or `clearError()` after fixing an issue

---

## Resources

- [Dart Exception Handling](https://dart.dev/guides/language/language-tour#exceptions)
- [Flutter Error Handling](https://flutter.dev/docs/testing/errors)
- [Firebase Error Codes](https://firebase.google.com/docs/auth/troubleshooting)
