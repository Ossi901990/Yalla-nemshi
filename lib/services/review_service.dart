import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/review.dart';
import 'crash_service.dart';

/// Service to manage walk reviews and ratings stored inside each walk document.
class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _walkReviews(String walkId) {
    return _firestore.collection('walks').doc(walkId).collection('reviews');
  }

  /// Add or replace a review for a walk. Photos must already be uploaded.
  static Future<void> addReview({
    required String walkId,
    required String hostUid,
    required String userId,
    required String userName,
    String? userProfileUrl,
    required double walkRating,
    double? hostRating,
    String? reviewText,
    List<String> photoUrls = const [],
    bool leftEarly = false,
    bool reviewerIsHost = false,
  }) async {
    try {
      if (walkRating < 1 || walkRating > 5) {
        throw ArgumentError('Walk rating must be between 1 and 5');
      }
      if (hostRating != null && (hostRating < 1 || hostRating > 5)) {
        throw ArgumentError('Host rating must be between 1 and 5');
      }

      final reviewRef = _walkReviews(walkId).doc(userId);
      final payload = {
        'walkId': walkId,
        'hostUid': hostUid,
        'userId': userId,
        'userName': userName,
        'userProfileUrl': userProfileUrl,
        'walkRating': walkRating,
        if (!reviewerIsHost && hostRating != null) 'hostRating': hostRating,
        'reviewText': reviewText,
        'photoUrls': photoUrls,
        'leftEarly': leftEarly,
        'reviewerIsHost': reviewerIsHost,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'helpfulCount': 0,
        'helpfulBy': <String>[],
      };

      await reviewRef.set(payload);

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('walks')
          .doc(walkId)
          .set({
        'reviewSubmittedAt': FieldValue.serverTimestamp(),
        'reviewSubmitted': true,
      }, SetOptions(merge: true));

      CrashService.log('Review saved for walk: $walkId by $userId');
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.addReview',
      );
      rethrow;
    }
  }

  static Future<List<Review>> getWalkReviews(String walkId) async {
    try {
      final snapshot = await _walkReviews(walkId)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.map(Review.fromFirestore).toList();
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.getWalkReviews',
      );
      return [];
    }
  }

  static Future<List<Review>> getWalkReviewsPaginated(
    String walkId, {
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _walkReviews(walkId)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      return snapshot.docs.map(Review.fromFirestore).toList();
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.getWalkReviewsPaginated',
      );
      return [];
    }
  }

  static Future<ReviewStats> getWalkReviewStats(String walkId) async {
    try {
      final reviews = await getWalkReviews(walkId);
      return ReviewStats.fromReviews(reviews);
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.getWalkReviewStats',
      );
      return ReviewStats.fromReviews(const []);
    }
  }

  static Future<bool> userAlreadyReviewed(String walkId, String userId) async {
    try {
      final doc = await _walkReviews(walkId).doc(userId).get();
      return doc.exists;
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.userAlreadyReviewed',
      );
      return false;
    }
  }

  static Future<Review?> getUserReview(String walkId, String userId) async {
    try {
      final doc = await _walkReviews(walkId).doc(userId).get();
      if (!doc.exists) return null;
      return Review.fromFirestore(doc);
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.getUserReview',
      );
      return null;
    }
  }

  static Future<void> deleteReview(String walkId, String userId) async {
    try {
      await _walkReviews(walkId).doc(userId).delete();
      CrashService.log('Review removed for walk $walkId by $userId');
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.deleteReview',
      );
      rethrow;
    }
  }

  static Future<void> updateReview(
    String walkId,
    String userId, {
    double? walkRating,
    double? hostRating,
    String? reviewText,
    List<String>? photoUrls,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (walkRating != null) {
        if (walkRating < 1 || walkRating > 5) {
          throw ArgumentError('Walk rating must be between 1 and 5');
        }
        updates['walkRating'] = walkRating;
      }
      if (hostRating != null) {
        if (hostRating < 1 || hostRating > 5) {
          throw ArgumentError('Host rating must be between 1 and 5');
        }
        updates['hostRating'] = hostRating;
      }
      if (reviewText != null) {
        updates['reviewText'] = reviewText;
      }
      if (photoUrls != null) {
        updates['photoUrls'] = photoUrls;
      }
      if (updates.isEmpty) return;
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _walkReviews(walkId).doc(userId).update(updates);
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.updateReview',
      );
      rethrow;
    }
  }

  static Future<void> markHelpful(
    String walkId,
    String reviewUserId,
    String helperUid,
  ) async {
    try {
      final ref = _walkReviews(walkId).doc(reviewUserId);
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? <String, dynamic>{};
        final current = (data['helpfulBy'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
        if (current.contains(helperUid)) {
          return;
        }
        txn.update(ref, {
          'helpfulBy': FieldValue.arrayUnion([helperUid]),
          'helpfulCount': FieldValue.increment(1),
        });
      });
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ReviewService.markHelpful',
      );
      rethrow;
    }
  }
}
