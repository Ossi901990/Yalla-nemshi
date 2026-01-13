import 'package:cloud_firestore/cloud_firestore.dart';
import 'crash_service.dart';

/// Service for calculating and managing host ratings
/// Host ratings are calculated from reviews and stored at: /users/{userId}/hostRating (single document)
class HostRatingService {
  static final HostRatingService _instance = HostRatingService._internal();

  factory HostRatingService() => _instance;

  HostRatingService._internal();

  static HostRatingService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Model for host rating data
  static const double defaultRating = 5.0;
  static const int defaultReviewCount = 0;

  /// Get current host rating for a user
  /// Returns map with 'rating' and 'reviewCount'
  Future<Map<String, dynamic>> getHostRating(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('hostRating')
          .get();

      if (!doc.exists) {
        return {
          'rating': defaultRating,
          'reviewCount': defaultReviewCount,
          'totalRatingPoints': 0.0,
        };
      }

      final data = doc.data() as Map<String, dynamic>;
      return {
        'rating': (data['rating'] ?? defaultRating).toDouble(),
        'reviewCount': data['reviewCount'] ?? 0,
        'totalRatingPoints': (data['totalRatingPoints'] ?? 0.0).toDouble(),
      };
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'HostRatingService.getHostRating error',
      );
      return {
        'rating': defaultRating,
        'reviewCount': defaultReviewCount,
        'totalRatingPoints': 0.0,
      };
    }
  }

  /// Watch host rating in real-time
  Stream<Map<String, dynamic>> watchHostRating(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('hostRating')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {
          'rating': defaultRating,
          'reviewCount': defaultReviewCount,
          'totalRatingPoints': 0.0,
        };
      }

      final data = doc.data() as Map<String, dynamic>;
      return {
        'rating': (data['rating'] ?? defaultRating).toDouble(),
        'reviewCount': data['reviewCount'] ?? 0,
        'totalRatingPoints': (data['totalRatingPoints'] ?? 0.0).toDouble(),
      };
    }).handleError((e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'HostRatingService.watchHostRating error',
      );
      return {
        'rating': defaultRating,
        'reviewCount': defaultReviewCount,
        'totalRatingPoints': 0.0,
      };
    });
  }

  /// Add a review and recalculate host rating
  /// Call this when a user submits a review for a walk
  Future<void> addReview(String hostId, double rating) async {
    try {
      final ratingRef = _firestore
          .collection('users')
          .doc(hostId)
          .collection('stats')
          .doc('hostRating');

      // Get current rating document
      final doc = await ratingRef.get();
      final currentData = doc.exists
          ? (doc.data() ?? {})
          : {};

      final currentCount = (currentData['reviewCount'] ?? 0) as int;
      final currentTotal =
          (currentData['totalRatingPoints'] ?? 0.0).toDouble();

      // Calculate new average
      final newTotal = currentTotal + rating;
      final newCount = currentCount + 1;
      final newAverage = newTotal / newCount;

      // Update rating document
      await ratingRef.set({
        'rating': newAverage,
        'reviewCount': newCount,
        'totalRatingPoints': newTotal,
        'lastReviewAt': Timestamp.now(),
        'userId': hostId,
      }, SetOptions(merge: true));
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'HostRatingService.addReview error',
      );
      rethrow;
    }
  }

  /// Get all reviews for a host
  Future<List<Map<String, dynamic>>> getHostReviews(
    String hostId, {
    int limit = 20,
  }) async {
    try {
      final docs = await _firestore
          .collectionGroup('reviews')
          .where('hostId', isEqualTo: hostId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return docs.docs
          .map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
            };
          })
          .toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'HostRatingService.getHostReviews error',
      );
      return [];
    }
  }

  /// Get review count for a host
  Future<int> getHostReviewCount(String hostId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('reviews')
          .where('hostId', isEqualTo: hostId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'HostRatingService.getHostReviewCount error',
      );
      return 0;
    }
  }

  /// Calculate quality tier based on rating
  static String getRatingTier(double rating) {
    if (rating >= 4.8) return 'Excellent';
    if (rating >= 4.5) return 'Very Good';
    if (rating >= 4.0) return 'Good';
    if (rating >= 3.5) return 'Fair';
    return 'New Host';
  }

  /// Get badge emoji for rating
  static String getRatingEmoji(double rating) {
    if (rating >= 4.8) return '⭐⭐⭐⭐⭐';
    if (rating >= 4.5) return '⭐⭐⭐⭐⭐';
    if (rating >= 4.0) return '⭐⭐⭐⭐';
    if (rating >= 3.5) return '⭐⭐⭐';
    return '⭐⭐';
  }

  /// Get color for rating (can be used for UI)
  static String getRatingColor(double rating) {
    if (rating >= 4.8) return '#FFD700'; // Gold
    if (rating >= 4.5) return '#C0C0C0'; // Silver
    if (rating >= 4.0) return '#CD7F32'; // Bronze
    if (rating >= 3.5) return '#808080'; // Gray
    return '#A9A9A9'; // Dark gray
  }

  /// Remove a review and recalculate rating (admin/host only)
  Future<void> removeReview(String hostId, double rating) async {
    try {
      final ratingRef = _firestore
          .collection('users')
          .doc(hostId)
          .collection('stats')
          .doc('hostRating');

      final doc = await ratingRef.get();
      if (!doc.exists) return;

      final currentData = doc.data() as Map<String, dynamic>;
      final currentCount = (currentData['reviewCount'] ?? 0) as int;
      final currentTotal =
          (currentData['totalRatingPoints'] ?? 0.0).toDouble();

      if (currentCount <= 0) return;

      final newTotal = (currentTotal - rating).clamp(0.0, double.infinity);
      final newCount = currentCount - 1;
      final newAverage = newCount > 0 ? newTotal / newCount : defaultRating;

      await ratingRef.update({
        'rating': newAverage,
        'reviewCount': newCount,
        'totalRatingPoints': newTotal,
      });
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'HostRatingService.removeReview error',
      );
      rethrow;
    }
  }
}
