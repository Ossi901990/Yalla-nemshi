import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user review for a walk event
class Review {
  final String id;
  final String walkId;
  final String userId;
  final String userName;
  final String? userProfileUrl;
  final double rating; // 1.0 to 5.0
  final String reviewText;
  final DateTime createdAt;
  final int helpfulCount; // Count of people who found it helpful
  final List<String> helpfulBy; // User IDs who marked helpful

  Review({
    required this.id,
    required this.walkId,
    required this.userId,
    required this.userName,
    this.userProfileUrl,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    this.helpfulCount = 0,
    List<String>? helpfulBy,
  }) : helpfulBy = helpfulBy ?? const <String>[];

  /// Create Review from Firestore document
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      walkId: data['walkId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userProfileUrl: data['userProfileUrl'],
      rating: (data['rating'] ?? 5.0).toDouble(),
      reviewText: data['reviewText'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': Timestamp.fromDate(createdAt),
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
    double? rating,
    String? reviewText,
    DateTime? createdAt,
    int? helpfulCount,
    List<String>? helpfulBy,
  }) {
    return Review(
      id: id ?? this.id,
      walkId: walkId ?? this.walkId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfileUrl: userProfileUrl ?? this.userProfileUrl,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      createdAt: createdAt ?? this.createdAt,
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
      final ratingInt = review.rating.toInt();
      distribution[ratingInt] = (distribution[ratingInt] ?? 0) + 1;
      totalRating += review.rating;
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
