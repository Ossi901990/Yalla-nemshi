import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';
import '../models/badge.dart';
import '../models/walk_participation.dart';
import 'crash_service.dart';
import 'notification_storage.dart';
import 'user_stats_service.dart';

/// Badge evaluation and persistence service.
/// Badges are stored at: /users/{uid}/badges/{badgeId}
class BadgeService {
  BadgeService._();
  static final BadgeService instance = BadgeService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Check the user's stats and award/update badges as needed.
  /// Returns the list of newly earned badge ids.
  Future<List<UserBadge>> checkAndAward({String? userId}) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final stats = await UserStatsService.instance.getUserStats(uid);
      return _evaluateAndPersist(uid: uid, stats: stats);
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'BadgeService.checkAndAward');
      return [];
    }
  }

  Future<List<UserBadge>> _evaluateAndPersist({
    required String uid,
    required UserWalkStats stats,
  }) async {
    // Load current badges to avoid re-awarding
    final existingSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('badges')
        .get();

    final existing = {
      for (final doc in existingSnap.docs) doc.id: doc.data(),
    };

    final batch = _firestore.batch();
    final newlyEarned = <UserBadge>[];

    for (final def in kBadgeCatalog) {
      final currentValue = _metricValue(def.metric, stats);
      final progress = def.target <= 0
          ? 0.0
          : (currentValue / def.target).clamp(0.0, 1.0);
      final achieved = currentValue >= def.target - 1e-6;

      final existingData = existing[def.id];
      final alreadyAchieved = existingData != null &&
          (existingData['achieved'] as bool? ?? false);

      final earnedAt = achieved
          ? (existingData != null
              ? (existingData['earnedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
              : DateTime.now())
          : null;

      final userBadge = UserBadge(
        id: def.id,
        title: def.title,
        description: def.description,
        progress: progress,
        target: def.target,
        achieved: achieved,
        earnedAt: earnedAt,
      );

      // Persist progress (even if not achieved) for UI progress bars
      final badgeRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('badges')
          .doc(def.id);

      batch.set(badgeRef, {
        'title': def.title,
        'description': def.description,
        'progress': progress,
        'target': def.target,
        'achieved': achieved,
        'earnedAt': earnedAt,
        'metric': def.metric.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (achieved && !alreadyAchieved) {
        newlyEarned.add(userBadge);
      }
    }

    await batch.commit();

    if (newlyEarned.isNotEmpty) {
      await _recordLocalNotifications(newlyEarned);
    }

    return newlyEarned;
  }

  double _metricValue(BadgeMetric metric, UserWalkStats stats) {
    switch (metric) {
      case BadgeMetric.totalWalksCompleted:
        return stats.totalWalksCompleted.toDouble();
      case BadgeMetric.totalDistanceKm:
        return stats.totalDistanceKm;
      case BadgeMetric.totalWalksHosted:
        return stats.totalWalksHosted.toDouble();
    }
  }

  Future<void> _recordLocalNotifications(List<UserBadge> badges) async {
    try {
      for (final b in badges) {
        await NotificationStorage.addNotification(
          AppNotification(
            id: 'badge_${b.id}_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Badge earned! 🎉',
            message: '${b.title}: ${b.description}',
            timestamp: DateTime.now(),
            isRead: false,
          ),
        );
      }
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'BadgeService._recordLocalNotifications');
    }
  }
}