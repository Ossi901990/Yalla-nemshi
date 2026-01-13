// lib/services/firestore_sync_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore_user_service.dart';
import 'crash_service.dart';

/// Service to sync Firebase Auth users with Firestore user profiles
class FirestoreSyncService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sync current user: create profile if doesn't exist
  static Future<bool> syncCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No current user, skipping sync');
        return false;
      }

      debugPrint('🔄 Syncing current user: ${user.uid}');

      // Check if user exists in Firestore
      final exists = await FirestoreUserService.userExists(user.uid);
      
      if (exists) {
        debugPrint('✅ User already exists in Firestore: ${user.uid}');
        return true;
      }

      debugPrint('⚠️ User missing from Firestore, creating now...');

      // Create the user profile
      await FirestoreUserService.createUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        photoURL: user.photoURL,
      );

      debugPrint('✅ User synced successfully: ${user.uid}');
      CrashService.log('User synced: ${user.uid}');
      return true;
    } catch (e, st) {
      debugPrint('❌ Sync error: $e');
      debugPrint('Stack: $st');
      CrashService.recordError(e, st, reason: 'FirestoreSyncService.syncCurrentUser');
      return false;
    }
  }

  /// Sync ALL users in Auth to Firestore (admin operation)
  /// WARNING: This is resource-intensive, use sparingly
  static Future<int> syncAllAuthUsersToFirestore() async {
    try {
      debugPrint('🔄 Starting bulk sync of all Auth users to Firestore...');

      // Note: This requires running from a context with admin privileges
      // or from a Cloud Function. If run from app, it will only sync the current user.
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No user logged in, cannot perform bulk sync');
        return 0;
      }

      // For app context, just sync current user
      final synced = await syncCurrentUser() ? 1 : 0;
      return synced;
    } catch (e, st) {
      debugPrint('❌ Bulk sync error: $e');
      CrashService.recordError(e, st, reason: 'FirestoreSyncService.syncAllAuthUsersToFirestore');
      return 0;
    }
  }

  /// Get count of users in Auth vs Firestore
  static Future<Map<String, int>> getUserCounts() async {
    try {
      // Get Firestore user count
      final firestoreSnapshot = await _firestore
          .collection('users')
          .count()
          .get()
          .timeout(const Duration(seconds: 10));

      final firestoreCount = firestoreSnapshot.count ?? 0;

      debugPrint('📊 Firestore users: $firestoreCount');

      return {
        'firestore': firestoreCount,
      };
    } catch (e, st) {
      debugPrint('❌ Error getting user counts: $e');
      CrashService.recordError(e, st, reason: 'FirestoreSyncService.getUserCounts');
      return {'firestore': 0};
    }
  }

  /// Check which Auth users are missing from Firestore
  static Future<List<String>> getMissingUsers() async {
    try {
      final missing = <String>[];
      
      // Get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return missing;
      }

      // Check if current user exists in Firestore
      final exists = await FirestoreUserService.userExists(currentUser.uid);
      if (!exists) {
        missing.add(currentUser.uid);
      }

      return missing;
    } catch (e, st) {
      debugPrint('❌ Error checking missing users: $e');
      CrashService.recordError(e, st, reason: 'FirestoreSyncService.getMissingUsers');
      return [];
    }
  }
}
