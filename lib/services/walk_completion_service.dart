// lib/services/walk_completion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_features.dart';
import 'badge_service.dart';
import 'crash_service.dart';
import 'route_store.dart';

/// Counts a finished walk towards the signed-in user's history and lifetime
/// stats, on their own device.
///
/// On the paid Blaze plan this is the job of the walk-completion Cloud
/// Functions (functions/cp4_walk_completion.js). On the free Spark plan they
/// don't run, so without this nobody's "walks completed", total km, past walks
/// or badges ever change. Each user can only write their own history
/// (`users/{uid}/walks/{walkId}`) and stats (`users/{uid}/stats/walkStats`),
/// which is exactly what the rules already allow.
///
/// Idempotent: the history doc gets `statsCounted: true` in the same
/// transaction as the stats update, so a walk is never counted twice.
/// Disabled when [AppFeatures.serverWalkCompletion] is on (the functions do it).
class WalkCompletionService {
  WalkCompletionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _endedStatuses = ['completed', 'ended'];

  /// Walks already handled in this app session (saves repeat reads).
  static final Set<String> _handled = {};

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Count [walkId] for the current user if it has ended and they hosted or
  /// walked it. Safe to call any number of times.
  static Future<void> completeForMe(
    String walkId, {
    Map<String, dynamic>? walkData,
  }) async {
    if (AppFeatures.serverWalkCompletion) return;
    final uid = _uid;
    if (uid == null || _handled.contains(walkId)) return;

    try {
      final walk =
          walkData ?? (await _db.collection('walks').doc(walkId).get()).data();
      if (walk == null) return;
      if (!_endedStatuses.contains(walk['status']) || walk['cancelled'] == true) {
        return; // not finished (yet)
      }

      final isHost = walk['hostUid'] == uid;
      final joined = ((walk['joinedUserUids'] as List?) ?? const [])
          .contains(uid);
      final state = (walk['participantStates'] as Map?)?[uid];

      final histRef = _db
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId);
      final statsRef = _db
          .collection('users')
          .doc(uid)
          .collection('stats')
          .doc('walkStats');

      // The walker's own GPS distance if they tracked, else the walk's.
      double? ownKm;
      try {
        final route = await RouteStore.summaryRef(walkId, uid).get();
        ownKm = (route.data()?['distanceKm'] as num?)?.toDouble();
      } catch (_) {}
      final distanceKm =
          ownKm ??
          (walk['actualDistanceKm'] as num?)?.toDouble() ??
          (walk['distanceKm'] as num?)?.toDouble() ??
          (walk['loopDistanceKm'] as num?)?.toDouble() ??
          0.0;

      final startedAt = (walk['startedAt'] as Timestamp?)?.toDate();
      final completedAt =
          (walk['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

      var counted = false;
      await _db.runTransaction((tx) async {
        final hist = await tx.get(histRef);
        final h = hist.data() ?? const <String, dynamic>{};
        if (h['statsCounted'] == true) return; // already counted

        final leftEarly = h['status'] == 'completed_early';
        final walked =
            joined ||
            leftEarly ||
            h['status'] == 'actively_walking' ||
            state == 'confirmed';
        if (!isHost && !walked) return; // joined then left before it started

        final from =
            (h['confirmedAt'] as Timestamp?)?.toDate() ?? startedAt;
        final until = leftEarly
            ? ((h['completedAt'] as Timestamp?)?.toDate() ?? completedAt)
            : completedAt;
        final minutes = from == null
            ? 0
            : until.difference(from).inMinutes.clamp(0, 24 * 60);

        final statsSnap = await tx.get(statsRef);
        final s = statsSnap.data() ?? const <String, dynamic>{};
        num n(String k) => (s[k] as num?) ?? 0;

        final completed = n('totalWalksCompleted').toInt() + 1;
        final totalKm = n('totalDistanceKm').toDouble() + distanceKm;
        final totalSeconds = n('totalDuration').toInt() + minutes * 60;

        tx.set(histRef, {
          'walkId': walkId,
          'userId': uid,
          'joinedAt':
              h['joinedAt'] ?? walk['startedAt'] ?? Timestamp.fromDate(completedAt),
          'completed': true,
          'status': leftEarly ? 'completed_early' : 'completed',
          'completedAt': h['completedAt'] ?? Timestamp.fromDate(completedAt),
          'actualDistanceKm': distanceKm,
          'actualDurationMinutes': minutes,
          'role': isHost ? 'host' : 'participant',
          'statsCounted': true,
        }, SetOptions(merge: true));

        tx.set(statsRef, {
          'userId': uid,
          'totalWalksCompleted': completed,
          'totalWalksHosted': n('totalWalksHosted').toInt() + (isHost ? 1 : 0),
          'totalDistanceKm': totalKm,
          'totalDuration': totalSeconds,
          'averageDistancePerWalk': totalKm / completed,
          'averageDurationPerWalk': totalSeconds ~/ completed,
          'lastWalkDate': Timestamp.fromDate(completedAt),
          'lastUpdated': FieldValue.serverTimestamp(),
          if (!statsSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        counted = true;
      });

      _handled.add(walkId);
      if (counted) {
        debugPrint('✅ Walk $walkId counted for $uid (${distanceKm}km)');
        await BadgeService.instance.checkAndAward(userId: uid);
      }
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'WalkCompletionService.completeForMe($walkId)',
      );
    }
  }

  /// Count every finished walk the user hosted or joined that isn't counted
  /// yet. Called when the profile opens, so stats catch up even if the user
  /// wasn't in the app when a walk ended.
  static Future<void> completePendingForMe() async {
    if (AppFeatures.serverWalkCompletion) return;
    final uid = _uid;
    if (uid == null) return;

    final walks = _db.collection('walks');
    final queries = <Query<Map<String, dynamic>>>[
      for (final status in _endedStatuses) ...[
        walks.where('hostUid', isEqualTo: uid).where('status', isEqualTo: status),
        walks
            .where('joinedUserUids', arrayContains: uid)
            .where('status', isEqualTo: status),
      ],
    ];

    for (final q in queries) {
      try {
        final snap = await q.limit(25).get();
        for (final doc in snap.docs) {
          await completeForMe(doc.id, walkData: doc.data());
        }
      } catch (e, st) {
        CrashService.recordError(
          e,
          st,
          reason: 'WalkCompletionService.completePendingForMe',
        );
      }
    }
  }
}
