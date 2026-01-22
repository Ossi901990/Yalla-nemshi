import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review.dart';
import '../models/walk_event.dart';
import '../models/walk_participation.dart';
import '../models/walk_summary.dart';
import 'crash_service.dart';
import 'review_service.dart';

class WalkSummaryService {
  WalkSummaryService._();

  static final WalkSummaryService instance = WalkSummaryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<WalkSummaryData> loadSummary(
    String walkId, {
    WalkEvent? initialWalk,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw StateError('User not authenticated');
      }

      WalkEvent? resolvedWalk = initialWalk;
      final walkSnap = await _firestore.collection('walks').doc(walkId).get();
      if (walkSnap.exists) {
        final data = walkSnap.data() ?? <String, dynamic>{};
        data['id'] ??= walkSnap.id;
        data['firestoreId'] ??= walkSnap.id;
        resolvedWalk = WalkEvent.fromMap(data);
      }

      if (resolvedWalk == null) {
        throw StateError('Walk not found');
      }

      WalkParticipation? participation;
      bool reviewSubmitted = false;
      try {
        final participationSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('walks')
            .doc(walkId)
            .get();
        if (participationSnap.exists) {
          participation = WalkParticipation.fromFirestore(participationSnap);
          final data = participationSnap.data() ?? <String, dynamic>{};
          reviewSubmitted = data['reviewSubmittedAt'] != null ||
              data['reviewSubmitted'] == true;
        }
      } catch (e, st) {
        CrashService.recordError(
          e,
          st,
          reason: 'WalkSummaryService.loadSummary.participation',
        );
      }

      Review? existingReview;
      try {
        existingReview = await ReviewService.getUserReview(walkId, uid);
        reviewSubmitted = reviewSubmitted || existingReview != null;
      } catch (e, st) {
        CrashService.recordError(
          e,
          st,
          reason: 'WalkSummaryService.loadSummary.review',
        );
      }

      final durationMinutes = resolvedWalk.actualDurationMinutes ??
          participation?.actualDurationMinutes;
      final totalDistanceKm = resolvedWalk.actualDistanceKm ??
          participation?.actualDistanceKm;
      final avgSpeed = resolvedWalk.averageSpeed;
      final maxSpeed = resolvedWalk.maxSpeed;
      final routePoints = resolvedWalk.routePointsCount ?? 0;

      return WalkSummaryData(
        walk: resolvedWalk,
        participation: participation,
        existingReview: existingReview,
        isHost: resolvedWalk.hostUid == uid,
        reviewSubmitted: reviewSubmitted,
        totalDistanceKm: totalDistanceKm,
        durationMinutes: durationMinutes,
        averageSpeedMph: avgSpeed,
        maxSpeedMph: maxSpeed,
        routePointsCount: routePoints,
      );
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'WalkSummaryService.loadSummary',
      );
      rethrow;
    }
  }
}
