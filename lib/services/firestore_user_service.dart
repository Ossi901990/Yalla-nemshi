// lib/services/firestore_user_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/firestore_user.dart';
import 'crash_service.dart';

/// Service to manage user profiles in Firestore
class FirestoreUserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _usersCollection = 'users';
  static const String _profilePhotosPath = 'user_profiles';

  static String _sanitizeDisplayName(String value) => value.trim();

  static String _displayNameLower(String value) => _sanitizeDisplayName(value).toLowerCase();

  /// Create a new user document in Firestore
  static Future<void> createUser({
    required String uid,
    required String email,
    required String displayName,
    String? photoURL,
  }) async {
    try {
      final normalizedName = _sanitizeDisplayName(displayName);
      final user = FirestoreUser(
        uid: uid,
        email: email,
        displayName: normalizedName,
        photoURL: photoURL,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(user.toFirestore());

      debugPrint('✅ User profile created in Firestore: $uid');
      CrashService.log('User profile created: $uid');
    } catch (e, st) {
      debugPrint('❌ Error creating user profile: $e');
      CrashService.recordError(e, st, reason: 'FirestoreUserService.createUser');
      rethrow;
    }
  }

  /// Get a user by UID
  static Future<FirestoreUser?> getUser(String uid) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        debugPrint('⚠️ User not found: $uid');
        return null;
      }

      return FirestoreUser.fromFirestore(doc);
    } catch (e, st) {
      debugPrint('❌ Error fetching user: $e');
      CrashService.recordError(e, st, reason: 'FirestoreUserService.getUser');
      return null;
    }
  }

  /// Get current logged-in user's profile
  static Future<FirestoreUser?> getCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return getUser(uid);
  }

  /// Update user profile
  static Future<void> updateUser({
    required String uid,
    String? displayName,
    String? photoURL,
    String? bio,
    int? age,
    String? gender,
    bool? profilePublic,
  }) async {
    try {
      final updates = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (displayName != null) {
        final normalized = _sanitizeDisplayName(displayName);
        updates['displayName'] = normalized;
        updates['displayNameLower'] = _displayNameLower(normalized);
      }
      if (photoURL != null) updates['photoURL'] = photoURL;
      if (bio != null) updates['bio'] = bio;
      if (age != null) updates['age'] = age;
      if (gender != null) updates['gender'] = gender;
      if (profilePublic != null) updates['profilePublic'] = profilePublic;

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update(updates)
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ User profile updated: $uid');
      CrashService.log('User profile updated: $uid');
    } catch (e, st) {
      debugPrint('❌ Error updating user profile: $e');
      CrashService.recordError(e, st, reason: 'FirestoreUserService.updateUser');
      rethrow;
    }
  }

  /// Upload profile photo to Firebase Storage
  static Future<String> uploadProfilePhoto({
    required String uid,
    required File photoFile,
  }) async {
    try {
      final storagePath = '$_profilePhotosPath/$uid/avatar.jpg';
      final ref = _storage.ref(storagePath);

      debugPrint('📸 Uploading profile photo to: $storagePath');

      final uploadTask = ref.putFile(photoFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Profile photo uploaded: $downloadUrl');
      CrashService.log('Profile photo uploaded: $uid');

      // Update user document with new photo URL
      await updateUser(uid: uid, photoURL: downloadUrl);

      return downloadUrl;
    } catch (e, st) {
      debugPrint('❌ Photo upload error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'FirestoreUserService.uploadProfilePhoto',
      );
      rethrow;
    }
  }

  /// Delete profile photo from Firebase Storage
  static Future<void> deleteProfilePhoto(String uid) async {
    try {
      final storagePath = '$_profilePhotosPath/$uid/avatar.jpg';
      final ref = _storage.ref(storagePath);

      await ref.delete();

      // Update user document to remove photo URL
      await updateUser(uid: uid, photoURL: '');

      debugPrint('✅ Profile photo deleted: $uid');
      CrashService.log('Profile photo deleted: $uid');
    } catch (e, st) {
      debugPrint('❌ Photo delete error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'FirestoreUserService.deleteProfilePhoto',
      );
      rethrow;
    }
  }

  /// Check if user profile exists
  static Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));

      return doc.exists;
    } catch (e) {
      debugPrint('❌ Error checking user existence: $e');
      return false;
    }
  }

  /// Search users by display name (for future use)
  static Future<List<FirestoreUser>> searchUsers(String query, {int limit = 20}) async {
    try {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return [];

      final normalized = trimmed.toLowerCase();
      final Map<String, FirestoreUser> resultsById = {};

      Future<void> runPrefixedQuery(String field, String value) async {
        final snapshot = await _firestore
            .collection(_usersCollection)
            .where(field, isGreaterThanOrEqualTo: value)
            .where(field, isLessThanOrEqualTo: '$value\uf8ff')
            .limit(limit)
            .get()
            .timeout(const Duration(seconds: 5));

        for (final doc in snapshot.docs) {
          final user = FirestoreUser.fromFirestore(doc);
          resultsById[user.uid] = user;
          if (resultsById.length >= limit) break;
        }
      }

      await runPrefixedQuery('displayNameLower', normalized);

      if (resultsById.length < limit) {
        final variants = {
          trimmed,
          _toTitleCase(trimmed),
          trimmed.toUpperCase(),
        }..removeWhere((value) => value.isEmpty);

        for (final variant in variants) {
          await runPrefixedQuery('displayName', variant);
          if (resultsById.length >= limit) break;
        }
      }

      final users = resultsById.values.toList()
        ..sort((a, b) => a.displayNameLower.compareTo(b.displayNameLower));
      return users.take(limit).toList();
    } catch (e, st) {
      debugPrint('❌ Error searching users: $e');
      CrashService.recordError(e, st, reason: 'FirestoreUserService.searchUsers');
      return [];
    }
  }

  static String _toTitleCase(String value) {
    if (value.isEmpty) return value;
    final words = value
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) =>
            '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .toList();
    return words.join(' ');
  }

  /// Increment walk stats (called after walk completion)
  static Future<void> incrementWalkStats({
    required String uid,
    required double distanceKm,
    bool isHost = false,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'walksJoined': FieldValue.increment(1),
        if (isHost) 'walksHosted': FieldValue.increment(1),
        'totalKm': FieldValue.increment(distanceKm),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Walk stats incremented for: $uid');
    } catch (e, st) {
      debugPrint('❌ Error incrementing walk stats: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'FirestoreUserService.incrementWalkStats',
      );
    }
  }

  /// Get multiple users by UIDs (for displaying participants)
  static Future<List<FirestoreUser>> getUsersByIds(List<String> uids) async {
    try {
      if (uids.isEmpty) return [];

      // Firestore has a limit of 10 items for 'in' queries
      // Split into batches if needed
      final batches = <List<String>>[];
      for (var i = 0; i < uids.length; i += 10) {
        batches.add(
          uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10),
        );
      }

      final allUsers = <FirestoreUser>[];
      for (final batch in batches) {
        final snapshot = await _firestore
            .collection(_usersCollection)
            .where('uid', whereIn: batch)
            .get()
            .timeout(const Duration(seconds: 10));

        allUsers.addAll(
          snapshot.docs.map((doc) => FirestoreUser.fromFirestore(doc)),
        );
      }

      return allUsers;
    } catch (e, st) {
      debugPrint('❌ Error fetching users by IDs: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'FirestoreUserService.getUsersByIds',
      );
      return [];
    }
  }

  /// Listen to user profile changes (real-time)
  static Stream<FirestoreUser?> watchUser(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return FirestoreUser.fromFirestore(doc);
    });
  }

  /// Get monthly digest preference (defaults to false)
  static Future<bool> getMonthlyDigestEnabled(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      return doc.data()?['monthlyDigestEnabled'] as bool? ?? false;
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'FirestoreUserService.getMonthlyDigestEnabled',
      );
      return false;
    }
  }

  /// Enable/disable monthly digest for a user
  static Future<void> setMonthlyDigestEnabled({
    required String uid,
    required bool enabled,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).set(
        {
          'monthlyDigestEnabled': enabled,
          'monthlyDigestUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      CrashService.log('Monthly digest ${enabled ? 'enabled' : 'disabled'} for $uid');
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'FirestoreUserService.setMonthlyDigestEnabled',
      );
      rethrow;
    }
  }
}
