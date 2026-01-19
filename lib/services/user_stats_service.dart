import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/walk_participation.dart';
import 'badge_service.dart';
import 'crash_service.dart';

/// Service for managing user walk statistics
/// Stored at: /users/{userId}/stats (single document)
class UserStatsService {
  static final UserStatsService _instance = UserStatsService._internal();

  factory UserStatsService() => _instance;

  UserStatsService._internal();

  static UserStatsService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user's walk statistics
  Future<UserWalkStats> getUserStats(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('walkStats')
          .get();

      if (!doc.exists) {
        return UserWalkStats(userId: userId);
      }

      return UserWalkStats.fromFirestore(doc);
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.getUserStats error',
      );
      return UserWalkStats(userId: userId);
    }
  }

  /// Watch user's walk statistics in real-time
  Stream<UserWalkStats> watchUserStats(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('walkStats')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return UserWalkStats(userId: userId);
      }
      return UserWalkStats.fromFirestore(doc);
    }).handleError((e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.watchUserStats error',
      );
      return UserWalkStats(userId: userId);
    });
  }

  /// Increment walk stats when user completes a walk
  /// Call this after user marks walk as completed
  Future<void> incrementWalkCompleted({
    required String userId,
    required double distanceKm,
    required Duration duration,
    required int participantCount,
  }) async {
    try {
      final statsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('walkStats');

      final doc = await statsRef.get();
      final stats =
          doc.exists ? UserWalkStats.fromFirestore(doc) : UserWalkStats(userId: userId);

      // Calculate new averages
      final newCompleted = stats.totalWalksCompleted + 1;
      final newTotalDistance = stats.totalDistanceKm + distanceKm;
      final newTotalDuration =
          stats.totalDuration + duration;
      final newParticipants =
          stats.totalParticipants + participantCount;

      final newAvgDistance = newTotalDistance / newCompleted;
      final newAvgDuration = newTotalDuration ~/ newCompleted;

      await statsRef.set({
        'userId': userId,
        'totalWalksCompleted': newCompleted,
        'totalWalksJoined': stats.totalWalksJoined,
        'totalWalksHosted': stats.totalWalksHosted,
        'totalDistanceKm': newTotalDistance,
        'totalDuration': newTotalDuration.inSeconds,
        'totalParticipants': newParticipants,
        'averageDistancePerWalk': newAvgDistance,
        'averageDurationPerWalk': newAvgDuration.inSeconds,
        'lastWalkDate': Timestamp.now(),
        'createdAt': doc.exists ? stats.createdAt : DateTime.now(),
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

      await BadgeService.instance.checkAndAward(userId: userId);
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.incrementWalkCompleted error',
      );
      rethrow;
    }
  }

  /// Increment stats for hosting a walk
  /// Call this when a walk is completed and host wants to log stats
  Future<void> incrementWalkHosted({
    required String userId,
    required double distanceKm,
    required Duration duration,
    required int participantCount,
  }) async {
    try {
      final statsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('walkStats');

      final doc = await statsRef.get();
      final stats =
          doc.exists ? UserWalkStats.fromFirestore(doc) : UserWalkStats(userId: userId);

      final newHosted = stats.totalWalksHosted + 1;

      await statsRef.update({
        'totalWalksHosted': newHosted,
        'lastWalkDate': Timestamp.now(),
        'lastUpdated': Timestamp.now(),
      });

      await BadgeService.instance.checkAndAward(userId: userId);
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.incrementWalkHosted error',
      );
      rethrow;
    }
  }

  /// Record that user joined a walk
  Future<void> recordWalkJoined(String userId) async {
    try {
      final statsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('walkStats');

      final doc = await statsRef.get();
      final stats =
          doc.exists ? UserWalkStats.fromFirestore(doc) : UserWalkStats(userId: userId);

      await statsRef.set({
        'totalWalksJoined': stats.totalWalksJoined + 1,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.recordWalkJoined error',
      );
      // Non-blocking: don't rethrow
    }
  }

  /// Get walk stats for current user
  Future<UserWalkStats> getCurrentUserStats() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    return getUserStats(uid);
  }

  /// Get quick stats summary
  /// Returns a simple map for quick display
  Future<Map<String, dynamic>> getQuickStats(String userId) async {
    try {
      final stats = await getUserStats(userId);
      return {
        'totalWalksCompleted': stats.totalWalksCompleted,
        'totalDistanceKm': stats.totalDistanceKm.toStringAsFixed(1),
        'averageDistancePerWalk':
            stats.averageDistancePerWalk.toStringAsFixed(1),
        'totalWalksHosted': stats.totalWalksHosted,
        'totalParticipants': stats.totalParticipants,
      };
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.getQuickStats error',
      );
      return {
        'totalWalksCompleted': 0,
        'totalDistanceKm': '0.0',
        'averageDistancePerWalk': '0.0',
        'totalWalksHosted': 0,
        'totalParticipants': 0,
      };
    }
  }

  /// Reset user stats (admin only)
  Future<void> resetStats(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('walkStats')
          .delete();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.resetStats error',
      );
      rethrow;
    }
  }

  /// Get leaderboard of top walkers (by distance)
  /// Limit to 50 users by default
  Future<List<Map<String, dynamic>>> getTopWalkers({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('walkStats')
          .orderBy('totalDistanceKm', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .asMap()
          .entries
          .map((entry) {
            final data = entry.value.data();
            return {
              ...data,
              'rank': entry.key + 1,
            };
          })
          .toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.getTopWalkers error',
      );
      return [];
    }
  }

  /// Get leaderboard of top hosts (by walks hosted)
  Future<List<Map<String, dynamic>>> getTopHosts({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('walkStats')
          .orderBy('totalWalksHosted', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .asMap()
          .entries
          .map((entry) {
            final data = entry.value.data();
            return {
              ...data,
              'rank': entry.key + 1,
            };
          })
          .toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'UserStatsService.getTopHosts error',
      );
      return [];
    }
  }
}
