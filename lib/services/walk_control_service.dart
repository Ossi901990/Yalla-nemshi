import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/walk_event.dart';
import 'crash_service.dart';
import 'badge_service.dart';

/// Service for controlling walk state (start/end walks)
/// For CP-4 walk completion and participant confirmation flow
class WalkControlService {
  static final WalkControlService _instance = WalkControlService._internal();

  factory WalkControlService() => _instance;

  WalkControlService._internal();

  static WalkControlService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Start a walk (only callable by host)
  /// Sets status to "starting" which triggers onWalkStarted Cloud Function
  /// Cloud Function will send confirmation prompts to all participants
  Future<void> startWalk(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final walkRef = _firestore.collection('walks').doc(walkId);
      final walkDoc = await walkRef.get();

      if (!walkDoc.exists) {
        throw Exception('Walk not found');
      }

      final walk = walkDoc.data() as Map<String, dynamic>;
      if (walk['hostUid'] != uid) {
        throw Exception('Only walk host can start the walk');
      }

      // Update walk status to "starting"
      // This triggers onWalkStarted Cloud Function
      await walkRef.update({
        'status': 'starting',
        'startedAt': Timestamp.now(),
        'startedByUid': uid,
      });

      CrashService.log('Walk $walkId started by $uid');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkControlService.startWalk error',
      );
      rethrow;
    }
  }

  /// End a walk (only callable by host)
  /// Sets status to "completed" which triggers onWalkEnded Cloud Function
  /// Cloud Function will:
  /// - Mark all "actively_walking" participants as complete
  /// - Calculate stats for each participant
  /// - Persist to /users/{uid}/stats/walkStats
  Future<void> endWalk(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final walkRef = _firestore.collection('walks').doc(walkId);
      final walkDoc = await walkRef.get();

      if (!walkDoc.exists) {
        throw Exception('Walk not found');
      }

      final walk = walkDoc.data() as Map<String, dynamic>;
      if (walk['hostUid'] != uid) {
        throw Exception('Only walk host can end the walk');
      }

      // Calculate actual duration from start
      final startedAt = (walk['startedAt'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      int? actualDurationMinutes;

      if (startedAt != null) {
        actualDurationMinutes = now.difference(startedAt).inMinutes;
      }

      // Update walk status to "completed"
      // This triggers onWalkEnded Cloud Function
      await walkRef.update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
        'actualDurationMinutes': actualDurationMinutes,
      });

      // Award badges to all participants (async, no need to await)
      final participantsSnapshot = await walkRef
          .collection('walkParticipations')
          .get();
      
      for (final doc in participantsSnapshot.docs) {
        final participantId = doc['userId'] as String?;
        if (participantId != null) {
          // Award badges asynchronously
          BadgeService.instance.checkAndAward(userId: participantId).ignore();
        }
      }

      CrashService.log('Walk $walkId ended by $uid (${actualDurationMinutes}m)');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkControlService.endWalk error',
      );
      rethrow;
    }
  }

  /// Mark walk as completed early (emergency/admin only)
  /// Useful if host loses connection
  Future<void> completeWalkEarly(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final walkRef = _firestore.collection('walks').doc(walkId);
      final walkDoc = await walkRef.get();

      if (!walkDoc.exists) {
        throw Exception('Walk not found');
      }

      final walk = walkDoc.data() as Map<String, dynamic>;
      if (walk['hostUid'] != uid) {
        throw Exception('Only walk host can complete the walk early');
      }

      await walkRef.update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
        'completed_early': true,
      });

      CrashService.log('Walk $walkId completed early by $uid');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkControlService.completeWalkEarly error',
      );
      rethrow;
    }
  }

  /// Cancel a walk (only callable by host)
  /// Sets status to "cancelled"
  Future<void> cancelWalk(String walkId, {String? reason}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final walkRef = _firestore.collection('walks').doc(walkId);
      final walkDoc = await walkRef.get();

      if (!walkDoc.exists) {
        throw Exception('Walk not found');
      }

      final walk = walkDoc.data() as Map<String, dynamic>;
      if (walk['hostUid'] != uid) {
        throw Exception('Only walk host can cancel the walk');
      }

      // Check if walk already started
      final status = walk['status'] as String?;
      if (status == 'starting' || status == 'completed') {
        throw Exception('Cannot cancel a walk that has already started');
      }

      await walkRef.update({
        'cancelled': true,
        'cancelledAt': Timestamp.now(),
        'cancellationReason': reason,
      });

      // Mark all participants as cancelled
      final participantsSnapshot = await _firestore
          .collectionGroup('walks')
          .where('walkId', isEqualTo: walkId)
          .get();

      final batch = _firestore.batch();
      for (final doc in participantsSnapshot.docs) {
        batch.update(doc.reference, {
          'status': 'host_cancelled',
          'cancelledAt': Timestamp.now(),
        });
      }
      await batch.commit();

      CrashService.log('Walk $walkId cancelled by $uid: $reason');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkControlService.cancelWalk error',
      );
      rethrow;
    }
  }

  /// Get walk details
  Future<WalkEvent?> getWalk(String walkId) async {
    try {
      final doc = await _firestore.collection('walks').doc(walkId).get();
      if (!doc.exists) return null;
      return WalkEvent.fromMap(doc.data() ?? {});
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkControlService.getWalk error',
      );
      return null;
    }
  }

  /// Watch walk details in real-time
  Stream<WalkEvent?> watchWalk(String walkId) {
    return _firestore
        .collection('walks')
        .doc(walkId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return WalkEvent.fromMap(doc.data() ?? {});
    });
  }

  /// Check if current user is host of walk
  Future<bool> isHostOfWalk(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final walk = await getWalk(walkId);
      return walk?.hostUid == uid;
    } catch (e) {
      return false;
    }
  }

  /// Get count of active participants in a walk (status: "actively_walking")
  Future<int> getActiveParticipantCount(String walkId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('walks')
          .where('walkId', isEqualTo: walkId)
          .where('status', isEqualTo: 'actively_walking')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkControlService.getActiveParticipantCount error',
      );
      return 0;
    }
  }

  /// Get all participants with their confirmation status
  Future<Map<String, String>> getParticipationStatus(String walkId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('walks')
          .where('walkId', isEqualTo: walkId)
          .get();

      final status = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        final participationStatus = data['status'] as String?;

        if (userId != null && participationStatus != null) {
          status[userId] = participationStatus;
        }
      }

      return status;
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkControlService.getParticipationStatus error',
      );
      return {};
    }
  }
}
