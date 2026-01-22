import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user review for a walk event
class Review {
  final String id;
  final String walkId;
  final String userId;
  final String userName;
  final String? userProfileUrl;
  final double walkRating; // 1.0 to 5.0
  final double? hostRating; // 1.0 to 5.0 (participants only)
  final String? reviewText;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> photoUrls;
  final bool leftEarly;
  final bool reviewerIsHost;
  final int helpfulCount; // Count of people who found it helpful
  final List<String> helpfulBy; // User IDs who marked helpful

  Review({
    required this.id,
    required this.walkId,
    required this.userId,
    required this.userName,
    this.userProfileUrl,
    required this.walkRating,
    this.hostRating,
    this.reviewText,
    required this.createdAt,
    this.updatedAt,
    List<String>? photoUrls,
    this.leftEarly = false,
    this.reviewerIsHost = false,
    this.helpfulCount = 0,
    List<String>? helpfulBy,
  }) :
        helpfulBy = helpfulBy ?? const <String>[],
        photoUrls = photoUrls ?? const <String>[];

  double get rating => walkRating;

  /// Create Review from Firestore document
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      walkId: data['walkId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userProfileUrl: data['userProfileUrl'],
      walkRating: (data['walkRating'] ?? data['rating'] ?? 5.0).toDouble(),
      hostRating: (data['hostRating'] as num?)?.toDouble(),
      reviewText: data['reviewText'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      photoUrls: (data['photoUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      leftEarly: data['leftEarly'] as bool? ?? false,
      reviewerIsHost: data['reviewerIsHost'] as bool? ?? false,
      helpfulCount: data['helpfulCount'] ?? 0,
      helpfulBy:
          (data['helpfulBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );
  }

  /// Convert Review to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'walkId': walkId,
      'userId': userId,
      'userName': userName,
      'userProfileUrl': userProfileUrl,
      'walkRating': walkRating,
      'hostRating': hostRating,
      'reviewText': reviewText,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'photoUrls': photoUrls,
      'leftEarly': leftEarly,
      'reviewerIsHost': reviewerIsHost,
      'helpfulCount': helpfulCount,
      'helpfulBy': helpfulBy,
    };
  }

  /// Copy with method for updates
  Review copyWith({
    String? id,
    String? walkId,
    String? userId,
    String? userName,
    String? userProfileUrl,
    double? walkRating,
    double? hostRating,
    String? reviewText,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? photoUrls,
    bool? leftEarly,
    bool? reviewerIsHost,
    int? helpfulCount,
    List<String>? helpfulBy,
  }) {
    return Review(
      id: id ?? this.id,
      walkId: walkId ?? this.walkId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfileUrl: userProfileUrl ?? this.userProfileUrl,
      walkRating: walkRating ?? this.walkRating,
      hostRating: hostRating ?? this.hostRating,
      reviewText: reviewText ?? this.reviewText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrls: photoUrls ?? this.photoUrls,
      leftEarly: leftEarly ?? this.leftEarly,
      reviewerIsHost: reviewerIsHost ?? this.reviewerIsHost,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      helpfulBy: helpfulBy ?? this.helpfulBy,
    );
  }

  @override
  String toString() => 'Review($id, walkId: $walkId, rating: $rating)';
}

/// Summary statistics for walk reviews
class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // rating -> count

  ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  /// Calculate from list of reviews
  factory ReviewStats.fromReviews(List<Review> reviews) {
    if (reviews.isEmpty) {
      return ReviewStats(
        averageRating: 0,
        totalReviews: 0,
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }

    final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    double totalRating = 0;

    for (final review in reviews) {
      final clamped = review.walkRating.round().clamp(1, 5) as num;
      final ratingInt = clamped.toInt();
      distribution[ratingInt] = (distribution[ratingInt] ?? 0) + 1;
      totalRating += review.walkRating;
    }

    return ReviewStats(
      averageRating: totalRating / reviews.length,
      totalReviews: reviews.length,
      ratingDistribution: distribution,
    );
  }

  /// Get percentage of 5-star reviews
  double get percentageFiveStars =>
      totalReviews == 0 ? 0 : (ratingDistribution[5]! / totalReviews) * 100;

  /// Get percentage of 1-star reviews
  double get percentageOneStars =>
      totalReviews == 0 ? 0 : (ratingDistribution[1]! / totalReviews) * 100;
}
