import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provides current Firebase user (null if signed out)
final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider);
  return user.maybeWhen(
    data: (u) => u != null,
    orElse: () => false,
  );
});

/// Get current user's UID (null if not authenticated)
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider);
  return user.maybeWhen(
    data: (u) => u?.uid,
    orElse: () => null,
  );
});

/// Get current user's email (null if not authenticated)
final currentUserEmailProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider);
  return user.maybeWhen(
    data: (u) => u?.email,
    orElse: () => null,
  );
});
