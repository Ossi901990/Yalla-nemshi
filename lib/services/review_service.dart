import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';
import 'crash_service.dart';

/// Service to manage walk reviews and ratings
class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _reviewsCollection = 'reviews';
  static const String _walksCollection = 'walks';

  /// Add a new review for a walk
  static Future<void> addReview({
    required String walkId,
    required String userId,
    required String userName,
    String? userProfileUrl,
    required double rating,
    required String reviewText,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw ArgumentError('Rating must be between 1 and 5');
      }

      if (reviewText.trim().isEmpty) {
        throw ArgumentError('Review text cannot be empty');
      }

      final review = Review(
        id: '', // Firestore will generate
        walkId: walkId,
        userId: userId,
        userName: userName,
        userProfileUrl: userProfileUrl,
        rating: rating,
        reviewText: reviewText,
        createdAt: DateTime.now(),
        helpfulCount: 0,
      );

      await _firestore.collection(_reviewsCollection).add(review.toFirestore());

      // Update walk's average rating
      await _updateWalkRating(walkId);

      CrashService.log('Review added for walk: $walkId');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.addReview',
      );
      rethrow;
    }
  }

  /// Get all reviews for a specific walk
  static Future<List<Review>> getWalkReviews(String walkId) async {
    try {
      final snapshot = await _firestore
          .collection(_reviewsCollection)
          .where('walkId', isEqualTo: walkId)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.getWalkReviews',
      );
      return [];
    }
  }

  /// Get reviews for a walk with pagination
  static Future<List<Review>> getWalkReviewsPaginated(
    String walkId, {
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      var query = _firestore
          .collection(_reviewsCollection)
          .where('walkId', isEqualTo: walkId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.getWalkReviewsPaginated',
      );
      return [];
    }
  }

  /// Get review statistics for a walk
  static Future<ReviewStats> getWalkReviewStats(String walkId) async {
    try {
      final reviews = await getWalkReviews(walkId);
      return ReviewStats.fromReviews(reviews);
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.getWalkReviewStats',
      );
      return ReviewStats.fromReviews([]);
    }
  }

  /// Check if user already reviewed this walk
  static Future<bool> userAlreadyReviewed(String walkId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_reviewsCollection)
          .where('walkId', isEqualTo: walkId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.userAlreadyReviewed',
      );
      return false;
    }
  }

  /// Get user's review for a specific walk (if exists)
  static Future<Review?> getUserReview(String walkId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_reviewsCollection)
          .where('walkId', isEqualTo: walkId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) return null;
      return Review.fromFirestore(snapshot.docs.first);
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.getUserReview',
      );
      return null;
    }
  }

  /// Delete a review (only by review author)
  static Future<void> deleteReview(String reviewId, String walkId) async {
    try {
      await _firestore.collection(_reviewsCollection).doc(reviewId).delete();

      // Recalculate walk rating
      await _updateWalkRating(walkId);

      CrashService.log('Review deleted: $reviewId');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.deleteReview',
      );
      rethrow;
    }
  }

  /// Update a review
  static Future<void> updateReview(
    String reviewId,
    String walkId, {
    double? rating,
    String? reviewText,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (rating != null) {
        if (rating < 1 || rating > 5) {
          throw ArgumentError('Rating must be between 1 and 5');
        }
        updates['rating'] = rating;
      }
      if (reviewText != null && reviewText.trim().isNotEmpty) {
        updates['reviewText'] = reviewText;
      }

      if (updates.isEmpty) return;

      await _firestore
          .collection(_reviewsCollection)
          .doc(reviewId)
          .update(updates);

      // Recalculate walk rating
      await _updateWalkRating(walkId);

      CrashService.log('Review updated: $reviewId');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.updateReview',
      );
      rethrow;
    }
  }

  /// Mark review as helpful
  static Future<void> markHelpful(String reviewId, String userId) async {
    try {
      final ref = _firestore.collection(_reviewsCollection).doc(reviewId);
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List<dynamic> current =
            (data['helpfulBy'] as List<dynamic>?) ?? <dynamic>[];
        if (current.contains(userId)) {
          return;
        }
        txn.update(ref, {
          'helpfulBy': FieldValue.arrayUnion([userId]),
          'helpfulCount': FieldValue.increment(1),
        });
      });
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.markHelpful',
      );
      rethrow;
    }
  }

  /// Private helper: Update walk's average rating
  static Future<void> _updateWalkRating(String walkId) async {
    try {
      final reviews = await getWalkReviews(walkId);
      if (reviews.isEmpty) {
        await _firestore.collection(_walksCollection).doc(walkId).update({
          'averageRating': 0,
          'reviewCount': 0,
        });
        return;
      }

      double totalRating = 0;
      for (final review in reviews) {
        totalRating += review.rating;
      }

      final averageRating = totalRating / reviews.length;

      await _firestore.collection(_walksCollection).doc(walkId).update({
        'averageRating': averageRating,
        'reviewCount': reviews.length,
      });

      CrashService.log(
        'Walk rating updated: $walkId, avg: ${averageRating.toStringAsFixed(2)}',
      );
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService._updateWalkRating',
      );
    }
  }

  /// Get top-rated walks
  static Future<List<String>> getTopRatedWalks({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_walksCollection)
          .where('averageRating', isGreaterThan: 0)
          .orderBy('averageRating', descending: true)
          .orderBy('reviewCount', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'ReviewService.getTopRatedWalks',
      );
      return [];
    }
  }
}
