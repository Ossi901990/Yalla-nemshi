import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/walk_event.dart';
import 'crash_service.dart';

/// Service for controlling walk state (start/end walks)
/// For CP-4 walk completion and participant confirmation flow
class WalkControlService {
  static final WalkControlService _instance = WalkControlService._internal();

  factory WalkControlService() => _instance;

  WalkControlService._internal();

  static WalkControlService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Duration _hostStartEarlyWindow = Duration(minutes: 10);
  static const Duration _hostStartGraceWindow = Duration(minutes: 15);

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

      final normalizedStatus = _normalizeStatus(walk['status']);
      if (normalizedStatus == 'active') {
        throw Exception('Walk already active');
      }
      if (normalizedStatus == 'ended') {
        throw Exception('Walk already ended');
      }

      final scheduledAt = _parseDateTime(walk['dateTime']) ?? DateTime.now();
      final now = DateTime.now();
      final earliestStart = scheduledAt.subtract(_hostStartEarlyWindow);
      final latestStart = scheduledAt.add(_hostStartGraceWindow);

      if (now.isBefore(earliestStart) || now.isAfter(latestStart)) {
        throw Exception(
          'You can only start the walk close to its scheduled time.',
        );
      }

      await walkRef.update({
        'status': 'active',
        'startedAt': Timestamp.now(),
        'startedByUid': uid,
        'cancelled': false,
        'participantStates.$uid': 'confirmed',
      });

      CrashService.log('Walk $walkId activated by $uid');
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
      // This triggers onWalkEnded Cloud Function which will:
      // - Mark all participants as completed
      // - Update user statistics
      // - Award badges
      // Client should NOT update participation directly to avoid race conditions
      await walkRef.update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
        'actualDurationMinutes': actualDurationMinutes,
      });

      CrashService.log(
        'Walk $walkId ended by $uid (${actualDurationMinutes}m)',
      );
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
        'status': 'ended',
        'completedAt': Timestamp.now(),
        'completed_early': true,
        'participantStates.$uid': 'confirmed',
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

      final normalizedStatus = _normalizeStatus(walk['status']);
      if (normalizedStatus == 'ended') {
        throw Exception('Cannot cancel a walk that already ended');
      }

      if (normalizedStatus == 'active') {
        final participantStates = _readParticipantStates(
          walk['participantStates'],
        );
        final hasConfirmed = participantStates.values.whereType<String>().any(
          (state) => state == 'confirmed',
        );
        if (hasConfirmed) {
          throw Exception(
            'Cannot cancel while participants are actively walking.',
          );
        }
      }

      await walkRef.update({
        'cancelled': true,
        'cancelledAt': Timestamp.now(),
        'cancellationReason': reason,
        'status': 'cancelled',
      });

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
      final data = doc.data() ?? {};
      data['id'] = doc.id;
      data['firestoreId'] = doc.id;
      return WalkEvent.fromMap(data);
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
    return _firestore.collection('walks').doc(walkId).snapshots().map((doc) {
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
      final doc = await _firestore.collection('walks').doc(walkId).get();
      if (!doc.exists) {
        return 0;
      }

      final participantStates = _readParticipantStates(
        doc.data()?['participantStates'],
      );
      return participantStates.values
          .where((state) => state == 'confirmed')
          .length;
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
      final doc = await _firestore.collection('walks').doc(walkId).get();
      if (!doc.exists) {
        return {};
      }

      return _readParticipantStates(doc.data()?['participantStates']);
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkControlService.getParticipationStatus error',
      );
      return {};
    }
  }

  Map<String, String> _readParticipantStates(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    }
    if (raw is Map) {
      final result = <String, String>{};
      raw.forEach((key, value) {
        if (key == null) return;
        result[key.toString()] = (value ?? '').toString();
      });
      return result;
    }
    return const {};
  }

  String _normalizeStatus(dynamic value) {
    final raw = (value ?? 'scheduled').toString().toLowerCase();
    switch (raw) {
      case 'active':
      case 'starting':
        return 'active';
      case 'completed':
      case 'ended':
        return 'ended';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'scheduled';
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}
