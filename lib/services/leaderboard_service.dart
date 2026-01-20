import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leaderboard.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  LeaderboardService._internal();

  factory LeaderboardService() {
    return _instance;
  }

  /// Get global badge leaderboard (top N users by total badges earned)
  Future<List<BadgeLeaderboardEntry>> getGlobalBadgeLeaderboard({
    int limit = 50,
  }) async {
    try {
      final query = _db
          .collection('leaderboards')
          .doc('global_badges')
          .collection('rankings')
          .orderBy('totalBadgesEarned', descending: true)
          .orderBy('lastBadgeEarnedAt', descending: true)
          .limit(limit);

      final snapshot = await query.get();

      final entries = <BadgeLeaderboardEntry>[];
      for (int i = 0; i < snapshot.docs.length; i++) {
        entries.add(
          BadgeLeaderboardEntry.fromFirestore(snapshot.docs[i], i + 1),
        );
      }

      return entries;
    } catch (e) {
      debugPrint('❌ Error fetching global badge leaderboard: $e');
      return [];
    }
  }

  /// Stream global badge leaderboard for real-time updates
  Stream<List<BadgeLeaderboardEntry>> streamGlobalBadgeLeaderboard({
    int limit = 50,
  }) {
    try {
      return _db
          .collection('leaderboards')
          .doc('global_badges')
          .collection('rankings')
          .orderBy('totalBadgesEarned', descending: true)
          .orderBy('lastBadgeEarnedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final entries = <BadgeLeaderboardEntry>[];
        for (int i = 0; i < snapshot.docs.length; i++) {
          entries.add(
            BadgeLeaderboardEntry.fromFirestore(snapshot.docs[i], i + 1),
          );
        }
        return entries;
      });
    } catch (e) {
      debugPrint('❌ Error streaming global badge leaderboard: $e');
      return Stream.value([]);
    }
  }

  /// Get per-badge leaderboard (users who earned a specific badge, sorted by when they earned it)
  Future<List<PerBadgeLeaderboardEntry>> getPerBadgeLeaderboard(
    String badgeId, {
    int limit = 50,
  }) async {
    try {
      final query = _db
          .collection('leaderboards')
          .doc('badge_$badgeId')
          .collection('rankings')
          .orderBy('earnedAt', descending: false) // First to earn is rank 1
          .limit(limit);

      final snapshot = await query.get();

      final entries = <PerBadgeLeaderboardEntry>[];
      for (int i = 0; i < snapshot.docs.length; i++) {
        entries.add(
          PerBadgeLeaderboardEntry.fromFirestore(snapshot.docs[i], i + 1),
        );
      }

      return entries;
    } catch (e) {
      debugPrint('❌ Error fetching per-badge leaderboard for $badgeId: $e');
      return [];
    }
  }

  /// Stream per-badge leaderboard for real-time updates
  Stream<List<PerBadgeLeaderboardEntry>> streamPerBadgeLeaderboard(
    String badgeId, {
    int limit = 50,
  }) {
    try {
      return _db
          .collection('leaderboards')
          .doc('badge_$badgeId')
          .collection('rankings')
          .orderBy('earnedAt', descending: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final entries = <PerBadgeLeaderboardEntry>[];
        for (int i = 0; i < snapshot.docs.length; i++) {
          entries.add(
            PerBadgeLeaderboardEntry.fromFirestore(snapshot.docs[i], i + 1),
          );
        }
        return entries;
      });
    } catch (e) {
      debugPrint('❌ Error streaming per-badge leaderboard for $badgeId: $e');
      return Stream.value([]);
    }
  }

  /// Get user's rank in global badge leaderboard
  Future<int?> getUserGlobalRank(String userId) async {
    try {
      final snapshot = await _db
          .collection('leaderboards')
          .doc('global_badges')
          .collection('rankings')
          .orderBy('totalBadgesEarned', descending: true)
          .orderBy('lastBadgeEarnedAt', descending: true)
          .get();

      for (int i = 0; i < snapshot.docs.length; i++) {
        if (snapshot.docs[i].id == userId) {
          return i + 1; // Rank is 1-indexed
        }
      }

      return null; // User not in leaderboard
    } catch (e) {
      debugPrint('❌ Error fetching user global rank: $e');
      return null;
    }
  }

  /// Get user's entry in global leaderboard
  Future<BadgeLeaderboardEntry?> getUserGlobalEntry(String userId) async {
    try {
      final snapshot = await _db
          .collection('leaderboards')
          .doc('global_badges')
          .collection('rankings')
          .orderBy('totalBadgesEarned', descending: true)
          .orderBy('lastBadgeEarnedAt', descending: true)
          .get();

      for (int i = 0; i < snapshot.docs.length; i++) {
        if (snapshot.docs[i].id == userId) {
          return BadgeLeaderboardEntry.fromFirestore(snapshot.docs[i], i + 1);
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user global entry: $e');
      return null;
    }
  }
}
