// lib/services/route_store.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Where GPS routes live in Firestore.
///
/// Each walker has their own route:
///   walks/{walkId}/routes/{uid}                  summary (distance, speed...)
///   walks/{walkId}/routes/{uid}/chunks/c{millis} up to [chunkSize] points
///
/// A chunk is written once (its id is the first point's time, so retries and
/// app restarts never overwrite earlier points). A 5 km walk is ~35 writes per
/// walker. The older format (`walks/{walkId}/tracking/point_N`, host only,
/// re-written in full every 30 points) is still read as a fallback.
class RouteStore {
  RouteStore._();

  static const int chunkSize = 30;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> summaryRef(
    String walkId,
    String uid,
  ) => _db.collection('walks').doc(walkId).collection('routes').doc(uid);

  static CollectionReference<Map<String, dynamic>> _chunks(
    String walkId,
    String uid,
  ) => summaryRef(walkId, uid).collection('chunks');

  /// Save one chunk of points (each a map with latitude, longitude, timestamp,
  /// ...). Idempotent: saving the same chunk twice writes the same doc.
  static Future<void> saveChunk({
    required String walkId,
    required String uid,
    required List<Map<String, dynamic>> points,
  }) async {
    if (points.isEmpty) return;
    final first = points.first['timestamp'] as Timestamp;
    await _chunks(walkId, uid).doc('c${first.millisecondsSinceEpoch}').set({
      'uid': uid,
      'firstAt': first,
      'count': points.length,
      'points': points,
    });
  }

  /// All points of one walker's route, oldest first.
  static Future<List<Map<String, dynamic>>> loadPoints(
    String walkId,
    String uid,
  ) async {
    final snap = await _chunks(walkId, uid).orderBy('firstAt').get();
    return [
      for (final doc in snap.docs)
        ...((doc.data()['points'] as List?) ?? const [])
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p)),
    ];
  }

  static Future<void> saveSummary({
    required String walkId,
    required String uid,
    required Map<String, double> stats,
    required int pointsCount,
    int? durationMinutes,
  }) {
    return summaryRef(walkId, uid).set({
      'uid': uid,
      'pointsCount': pointsCount,
      'distanceKm': stats['totalDistanceKm'] ?? 0.0,
      'averageSpeed': stats['averageSpeed'] ?? 0.0,
      'maxSpeed': stats['maxSpeed'] ?? 0.0,
      'durationMinutes': ?durationMinutes,
      'completed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Old host-only format, for walks tracked before per-walker routes.
  static Future<List<Map<String, dynamic>>> _loadLegacy(String walkId) async {
    final snap = await _db
        .collection('walks')
        .doc(walkId)
        .collection('tracking')
        .orderBy('timestamp')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// The route to show for a walk: the given walker's own route if they
  /// tracked one, otherwise the host's, otherwise the legacy format.
  static Future<List<Map<String, dynamic>>> loadWalkRoute(
    String walkId, {
    String? preferUid,
    String? hostUid,
  }) async {
    for (final uid in {?preferUid, ?hostUid}) {
      try {
        final points = await loadPoints(walkId, uid);
        if (points.length >= 2) return points;
      } catch (_) {
        // Not readable (e.g. not a member) or missing; try the next source.
      }
    }
    try {
      return await _loadLegacy(walkId);
    } catch (_) {
      return const [];
    }
  }
}
