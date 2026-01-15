import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/walk_participation.dart';
import 'crash_service.dart';

/// Service for tracking walk history and user participation
/// Stores data at: /users/{userId}/walks/{walkId}
class WalkHistoryService {
  static final WalkHistoryService _instance = WalkHistoryService._internal();

  factory WalkHistoryService() => _instance;

  WalkHistoryService._internal();

  static WalkHistoryService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Record that user joined a walk
  Future<void> recordWalkJoin(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .set({
        'userId': uid,
        'joinedAt': Timestamp.now(),
        'completed': false,
        'leftEarly': false,
        'hostCancelled': false,
      }, SetOptions(merge: true));
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.recordWalkJoin error',
      );
      rethrow;
    }
  }

  /// Record that user left a walk
  Future<void> recordWalkLeave(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .update({
        'leftAt': Timestamp.now(),
        'leftEarly': true,
        'completed': false,
      });
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.recordWalkLeave error',
      );
      rethrow;
    }
  }

  /// Mark a walk as completed by the user
  Future<void> markWalkCompleted(
    String walkId, {
    double? distanceKm,
    Duration? duration,
    String? notes,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .update({
        'completed': true,
        'actualDistanceKm': distanceKm,
        'actualDuration': duration?.inSeconds,
        'notes': notes,
        'completedAt': Timestamp.now(),
      });
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.markWalkCompleted error',
      );
      rethrow;
    }
  }

  /// Get all past walks for current user (completed or left early)
  Future<List<WalkParticipation>> getPastWalks({
    int limit = 20,
    DateTime? beforeDate,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      Query query = _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .where('completed', isEqualTo: true)
          .orderBy('joinedAt', descending: true);

      if (beforeDate != null) {
        query = query.where('joinedAt',
            isLessThan: Timestamp.fromDate(beforeDate));
      }

      final docs = await query.limit(limit).get();
      return docs.docs
          .map((doc) => WalkParticipation.fromFirestore(doc))
          .toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.getPastWalks error',
      );
      return [];
    }
  }

  /// Get all walks user has joined (including upcoming)
  Future<List<WalkParticipation>> getUserWalks({
    bool onlyCompleted = false,
    int limit = 50,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      Query query =
          _firestore.collection('users').doc(uid).collection('walks');

      if (onlyCompleted) {
        query = query.where('completed', isEqualTo: true);
      }

      query = query.orderBy('joinedAt', descending: true);

      final docs = await query.limit(limit).get();
      return docs.docs
          .map((doc) => WalkParticipation.fromFirestore(doc))
          .toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.getUserWalks error',
      );
      return [];
    }
  }

  /// Watch user's walk history in real-time
  Stream<List<WalkParticipation>> watchUserWalks({bool onlyCompleted = false}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.error('User not authenticated');
    }

    Query query =
        _firestore.collection('users').doc(uid).collection('walks');

    if (onlyCompleted) {
      query = query.where('completed', isEqualTo: true);
    }

    return query.orderBy('joinedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => WalkParticipation.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get walk participation for a specific walk
  Future<WalkParticipation?> getWalkParticipation(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .get();

      if (!doc.exists) return null;
      return WalkParticipation.fromFirestore(doc);
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.getWalkParticipation error',
      );
      return null;
    }
  }

  /// Get walk stats for a user (not the stats document, just basic counts)
  Future<Map<String, int>> getUserWalkCounts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('walks')
          .get();

      final walks = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'completed': data['completed'] as bool? ?? false,
          'leftEarly': data['leftEarly'] as bool? ?? false,
        };
      }).toList();

      return {
        'total': walks.length,
        'completed':
            walks.where((w) => w['completed'] == true).length,
        'leftEarly': walks
            .where((w) => w['leftEarly'] == true && !(w['completed'] ?? false))
            .length,
      };
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.getUserWalkCounts error',
      );
      return {'total': 0, 'completed': 0, 'leftEarly': 0};
    }
  }

  /// Delete a walk participation record
  Future<void> deleteWalkParticipation(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .delete();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.deleteWalkParticipation error',
      );
      rethrow;
    }
  }

  // ===== CP-4: Walk Control Methods =====

  /// Confirm user's participation when walk starts
  /// Updates status to "actively_walking" and records confirmation time
  Future<void> confirmParticipation(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .update({
        'status': 'actively_walking',
        'confirmedAt': Timestamp.now(),
      });
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.confirmParticipation error',
      );
      rethrow;
    }
  }

  /// Mark user's participation as completed
  /// Called when walk officially ends by host
  Future<void> markParticipationComplete(
    String walkId, {
    int? actualDurationMinutes,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
        'actualDurationMinutes': actualDurationMinutes,
      });
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.markParticipationComplete error',
      );
      rethrow;
    }
  }

  /// Mark user's participation as declined when walk starts
  /// User didn't confirm when prompted
  Future<void> declineParticipation(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .update({
        'status': 'declined',
        'declinedAt': Timestamp.now(),
      });
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.declineParticipation error',
      );
      rethrow;
    }
  }

  /// User leaves walk early
  /// Sets status to "completed_early" and records actual duration
  Future<void> leaveWalkEarly(String walkId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .doc(walkId)
          .update({
        'status': 'completed_early',
        'completedAt': Timestamp.now(),
      });
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.leaveWalkEarly error',
      );
      rethrow;
    }
  }

  /// Get user's walk statistics from persisted stats document
  /// Returns total walks, distance, duration, etc.
  Future<Map<String, dynamic>> getUserWalkStats(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('walkStats')
          .get();

      if (!doc.exists) {
        // Return default stats if document doesn't exist yet
        return {
          'totalWalksCompleted': 0,
          'totalWalksJoined': 0,
          'totalWalksHosted': 0,
          'totalDistanceKm': 0.0,
          'totalDuration': 0, // in seconds
          'totalParticipants': 0,
          'averageDistancePerWalk': 0.0,
          'averageDurationPerWalk': 0, // in seconds
          'lastWalkDate': null,
        };
      }

      return doc.data() ?? {};
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkHistoryService.getUserWalkStats error',
      );
      return {};
    }
  }

  /// Watch user's walk statistics in real-time
  Stream<Map<String, dynamic>> watchUserWalkStats(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('walkStats')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }
}
