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

  /// Create a new user document in Firestore
  static Future<void> createUser({
    required String uid,
    required String email,
    required String displayName,
    String? photoURL,
  }) async {
    try {
      final user = FirestoreUser(
        uid: uid,
        email: email,
        displayName: displayName,
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

      if (displayName != null) updates['displayName'] = displayName;
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
  static Future<List<FirestoreUser>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      // Note: Firestore doesn't support full-text search
      // For production, use Algolia or ElasticSearch
      // This is a simple prefix search
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) => FirestoreUser.fromFirestore(doc))
          .toList();
    } catch (e, st) {
      debugPrint('❌ Error searching users: $e');
      CrashService.recordError(e, st, reason: 'FirestoreUserService.searchUsers');
      return [];
    }
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
}
