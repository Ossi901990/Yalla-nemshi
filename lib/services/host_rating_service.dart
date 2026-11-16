import 'package:cloud_firestore/cloud_firestore.dart';
import 'crash_service.dart';

/// Service for calculating and managing host ratings
/// Host ratings are computed on read from walk reviews
/// (walks/{walkId}/reviews/{reviewerId}). Read-only on the client.
class HostRatingService {
  static final HostRatingService _instance = HostRatingService._internal();

  factory HostRatingService() => _instance;

  HostRatingService._internal();

  static HostRatingService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Model for host rating data
  static const double defaultRating = 5.0;
  static const int defaultReviewCount = 0;

  /// Host rating computed from the host's reviews with a server-side
  /// aggregation (average + count), so no Cloud Function is needed and hosts
  /// cannot inflate their own rating.
  Future<Map<String, dynamic>> getHostRating(String userId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('reviews')
          .where('hostUid', isEqualTo: userId)
          .where('hostRating', isGreaterThanOrEqualTo: 1)
          .aggregate(average('hostRating'), sum('hostRating'), count())
          .get();

      final reviewCount = snapshot.count ?? 0;
      if (reviewCount == 0) {
        return {
          'rating': defaultRating,
          'reviewCount': defaultReviewCount,
          'totalRatingPoints': 0.0,
        };
      }

      return {
        'rating': snapshot.getAverage('hostRating') ?? defaultRating,
        'reviewCount': reviewCount,
        'totalRatingPoints': snapshot.getSum('hostRating')?.toDouble() ?? 0.0,
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

  /// Get all reviews for a host
  Future<List<Map<String, dynamic>>> getHostReviews(
    String hostId, {
    int limit = 20,
  }) async {
    try {
      final docs = await _firestore
          .collectionGroup('reviews')
          .where('hostUid', isEqualTo: hostId)
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
          .where('hostUid', isEqualTo: hostId)
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

}
