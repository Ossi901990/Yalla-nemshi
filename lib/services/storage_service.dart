import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'crash_service.dart';

/// Service to handle Firebase Storage operations for walk photos
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _walksPhotosPath = 'walks';

  /// Upload a photo for a walk
  /// [walkId] - The walk document ID
  /// [photoFile] - The image file to upload
  /// [photoIndex] - Index/name of the photo (e.g., 'photo_0', 'photo_1')
  /// Returns the download URL of the uploaded photo
  static Future<String> uploadWalkPhoto({
    required String walkId,
    required File photoFile,
    required String photoIndex,
  }) async {
    try {
      // Create storage path: walks/{walkId}/{photoIndex}.jpg
      final storagePath = '$_walksPhotosPath/$walkId/$photoIndex.jpg';
      final ref = _storage.ref(storagePath);

      debugPrint('📸 Uploading photo to: $storagePath');

      // Upload file
      final uploadTask = ref.putFile(photoFile);
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Photo uploaded successfully: $downloadUrl');
      CrashService.log('Uploaded walk photo: $walkId/$photoIndex');

      return downloadUrl;
    } catch (e, st) {
      debugPrint('❌ Photo upload error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'StorageService.uploadWalkPhoto',
      );
      rethrow;
    }
  }

  /// Delete a photo from a walk
  /// [walkId] - The walk document ID
  /// [photoIndex] - Index/name of the photo to delete
  static Future<void> deleteWalkPhoto({
    required String walkId,
    required String photoIndex,
  }) async {
    try {
      final storagePath = '$_walksPhotosPath/$walkId/$photoIndex.jpg';
      final ref = _storage.ref(storagePath);

      debugPrint('🗑️ Deleting photo: $storagePath');

      await ref.delete();

      debugPrint('✅ Photo deleted successfully');
      CrashService.log('Deleted walk photo: $walkId/$photoIndex');
    } catch (e, st) {
      debugPrint('❌ Photo delete error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'StorageService.deleteWalkPhoto',
      );
      rethrow;
    }
  }

  /// Delete all photos for a walk (cleanup)
  /// [walkId] - The walk document ID
  static Future<void> deleteAllWalkPhotos(String walkId) async {
    try {
      final folderPath = '$_walksPhotosPath/$walkId/';
      final ref = _storage.ref(folderPath);

      debugPrint('🗑️ Deleting all photos for walk: $walkId');

      // List all files in the folder
      final result = await ref.listAll();

      // Delete each file
      for (final file in result.items) {
        await file.delete();
      }

      debugPrint('✅ All photos deleted for walk: $walkId');
      CrashService.log('Deleted all photos for walk: $walkId');
    } catch (e, st) {
      debugPrint('❌ Batch delete error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'StorageService.deleteAllWalkPhotos',
      );
      rethrow;
    }
  }

  /// Get download URL for a walk photo
  /// [walkId] - The walk document ID
  /// [photoIndex] - Index/name of the photo
  static Future<String> getPhotoUrl({
    required String walkId,
    required String photoIndex,
  }) async {
    try {
      final storagePath = '$_walksPhotosPath/$walkId/$photoIndex.jpg';
      final ref = _storage.ref(storagePath);

      final url = await ref.getDownloadURL();
      return url;
    } catch (e, st) {
      debugPrint('❌ Get URL error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'StorageService.getPhotoUrl',
      );
      rethrow;
    }
  }

  /// Check if a photo exists
  static Future<bool> photoExists({
    required String walkId,
    required String photoIndex,
  }) async {
    try {
      final storagePath = '$_walksPhotosPath/$walkId/$photoIndex.jpg';
      final ref = _storage.ref(storagePath);

      // Try to get metadata
      await ref.getMetadata();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return false;
      }
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Photo exists check error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'StorageService.photoExists',
      );
      rethrow;
    }
  }
}
