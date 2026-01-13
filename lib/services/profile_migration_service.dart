// lib/services/profile_migration_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'profile_storage.dart';
import 'firestore_user_service.dart';

/// Service to migrate local profiles to Firestore
class ProfileMigrationService {
  /// Check if user needs migration and perform it
  static Future<void> migrateIfNeeded() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ No user logged in, skipping migration');
        return;
      }

      // Check if user already exists in Firestore
      final exists = await FirestoreUserService.userExists(user.uid);
      if (exists) {
        debugPrint('✅ User already exists in Firestore: ${user.uid}');
        return;
      }

      debugPrint('🔄 Starting profile migration for: ${user.uid}');

      // Load local profile from SharedPreferences
      final localProfile = await ProfileStorage.loadProfile();

      // Create Firestore profile
      await FirestoreUserService.createUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: localProfile?.name ?? user.displayName ?? 'User',
      );

      // If local profile has additional data, update Firestore
      if (localProfile != null) {
        await FirestoreUserService.updateUser(
          uid: user.uid,
          bio: localProfile.bio,
          age: localProfile.age > 0 ? localProfile.age : null,
          gender: localProfile.gender != 'Not set' ? localProfile.gender : null,
        );
        debugPrint('✅ Migrated local profile data to Firestore');
      }

      debugPrint('✅ Profile migration complete for: ${user.uid}');
    } catch (e, st) {
      debugPrint('❌ Profile migration error: $e');
      debugPrint('Stack trace: $st');
      // Don't rethrow - migration failure shouldn't block app
    }
  }

  /// Force re-migration (for testing)
  static Future<void> forceMigration() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final localProfile = await ProfileStorage.loadProfile();

      await FirestoreUserService.createUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: localProfile?.name ?? user.displayName ?? 'User',
      );

      if (localProfile != null) {
        await FirestoreUserService.updateUser(
          uid: user.uid,
          bio: localProfile.bio,
          age: localProfile.age > 0 ? localProfile.age : null,
          gender: localProfile.gender != 'Not set' ? localProfile.gender : null,
        );
      }

      debugPrint('✅ Force migration complete');
    } catch (e) {
      debugPrint('❌ Force migration error: $e');
    }
  }
}
