import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single entry in the badge leaderboard
class BadgeLeaderboardEntry {
  final String userId;
  final String displayName;
  final String photoUrl;
  final int totalBadgesEarned;
  final DateTime lastBadgeEarnedAt;
  final int rank; // Calculated position

  BadgeLeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.totalBadgesEarned,
    required this.lastBadgeEarnedAt,
    required this.rank,
  });

  factory BadgeLeaderboardEntry.fromFirestore(
    DocumentSnapshot doc,
    int rank,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return BadgeLeaderboardEntry(
      userId: doc.id,
      displayName: data['displayName'] ?? 'Unknown User',
      photoUrl: data['photoUrl'] ?? '',
      totalBadgesEarned: data['totalBadgesEarned'] ?? 0,
      lastBadgeEarnedAt: (data['lastBadgeEarnedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rank: rank,
    );
  }

  @override
  String toString() =>
      'BadgeLeaderboardEntry(rank: $rank, user: $displayName, badges: $totalBadgesEarned)';
}

/// Represents a single entry in a per-badge leaderboard
class PerBadgeLeaderboardEntry {
  final String userId;
  final String displayName;
  final String photoUrl;
  final String badgeId;
  final String badgeTitle;
  final DateTime earnedAt;
  final int rank; // Calculated position

  PerBadgeLeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.badgeId,
    required this.badgeTitle,
    required this.earnedAt,
    required this.rank,
  });

  factory PerBadgeLeaderboardEntry.fromFirestore(
    DocumentSnapshot doc,
    int rank,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return PerBadgeLeaderboardEntry(
      userId: doc.id,
      displayName: data['displayName'] ?? 'Unknown User',
      photoUrl: data['photoUrl'] ?? '',
      badgeId: data['badgeId'] ?? '',
      badgeTitle: data['badgeTitle'] ?? 'Unknown Badge',
      earnedAt: (data['earnedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rank: rank,
    );
  }

  @override
  String toString() =>
      'PerBadgeLeaderboardEntry(rank: $rank, user: $displayName, badge: $badgeTitle, earned: $earnedAt)';
}
