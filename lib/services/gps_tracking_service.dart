import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'crash_service.dart';
import 'route_store.dart';

/// Real-time GPS tracking during active walks.
///
/// Every walker (host and participants) records their own route. Points are
/// buffered on the device and saved in chunks of [RouteStore.chunkSize], each
/// written once (see [RouteStore] for the layout and costs).
class GPSTrackingService {
  static final GPSTrackingService _instance = GPSTrackingService._internal();

  factory GPSTrackingService() => _instance;

  GPSTrackingService._internal();

  static GPSTrackingService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Active tracking subscriptions by walkId
  final Map<String, StreamSubscription<Position>> _trackingSubscriptions = {};

  /// Points recorded in this session, by walkId.
  final Map<String, List<Map<String, dynamic>>> _routeData = {};

  /// How many of [_routeData] points have been handed to [RouteStore].
  final Map<String, int> _savedCount = {};

  void _debug(String message) {
    if (kDebugMode) {
      debugPrint('[GPSTrackingService] $message');
    }
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Start recording the current user's route for [walkId].
  Future<void> startTracking(String walkId) async {
    try {
      _debug('startTracking requested for $walkId');
      if (_trackingSubscriptions.containsKey(walkId)) {
        CrashService.log('Already tracking walk $walkId');
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      _routeData[walkId] = [];
      _savedCount[walkId] = 0;

      // No timeLimit: with a distance filter, standing still (e.g. at a
      // crossing) produces no updates, and a timeLimit would end the stream.
      final subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 5, // metres
            ),
          ).listen(
            (Position position) => _onPositionUpdate(walkId, position),
            onError: (e) {
              CrashService.recordError(
                e,
                StackTrace.current,
                reason:
                    'GPSTrackingService position stream error for walk $walkId',
              );
            },
          );

      _trackingSubscriptions[walkId] = subscription;
      CrashService.log('Started tracking walk $walkId');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'GPSTrackingService.startTracking error',
      );
      rethrow;
    }
  }

  Future<void> _onPositionUpdate(String walkId, Position position) async {
    final route = _routeData[walkId];
    if (route == null) return;
    route.add({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed, // m/s
      'heading': position.heading, // degrees
      'timestamp': Timestamp.fromDate(position.timestamp),
    });

    final saved = _savedCount[walkId] ?? 0;
    if (route.length - saved >= RouteStore.chunkSize) {
      await _saveNextChunk(walkId);
    }
  }

  /// Save the next unsaved chunk. On failure the points stay unsaved and are
  /// retried with the next chunk or on stop (same chunk id, so no duplicates).
  Future<void> _saveNextChunk(String walkId, {bool flush = false}) async {
    final uid = _uid;
    final route = _routeData[walkId];
    if (uid == null || route == null) return;

    final start = _savedCount[walkId] ?? 0;
    final available = route.length - start;
    if (available <= 0) return;
    if (!flush && available < RouteStore.chunkSize) return;

    final end = flush ? route.length : start + RouteStore.chunkSize;
    final chunk = List<Map<String, dynamic>>.from(route.sublist(start, end));
    _savedCount[walkId] = end; // claim before awaiting to avoid double saves

    try {
      await RouteStore.saveChunk(walkId: walkId, uid: uid, points: chunk);
      _debug('Saved ${chunk.length} points for $walkId');
    } catch (e) {
      if (_savedCount[walkId] == end) _savedCount[walkId] = start;
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'GPSTrackingService chunk save failed for walk $walkId',
      );
    }
  }

  /// Stop tracking, save what's left, and return the route statistics.
  ///
  /// Stats are computed from everything saved for this walker (so a route that
  /// spans an app restart still counts in full), falling back to this
  /// session's points if the saved route can't be read.
  Future<Map<String, dynamic>> stopTracking(String walkId) async {
    try {
      _debug('stopTracking requested for $walkId');
      await _trackingSubscriptions.remove(walkId)?.cancel();

      // Flush everything not yet saved (may take more than one chunk if
      // earlier saves failed).
      while ((_routeData[walkId]?.length ?? 0) > (_savedCount[walkId] ?? 0)) {
        final before = _savedCount[walkId];
        await _saveNextChunk(walkId, flush: true);
        if (_savedCount[walkId] == before) break; // save failed; give up
      }

      final uid = _uid;
      final session = _routeData.remove(walkId) ?? const [];
      _savedCount.remove(walkId);

      var route = session;
      if (uid != null) {
        try {
          final stored = await RouteStore.loadPoints(walkId, uid);
          if (stored.length >= session.length) route = stored;
        } catch (_) {}
      }

      final stats = _calculateRouteStats(route);
      final durationMinutes = route.length >= 2
          ? (route.last['timestamp'] as Timestamp)
                .toDate()
                .difference((route.first['timestamp'] as Timestamp).toDate())
                .inMinutes
          : null;

      if (uid != null && route.isNotEmpty) {
        await RouteStore.saveSummary(
          walkId: walkId,
          uid: uid,
          stats: stats,
          pointsCount: route.length,
          durationMinutes: durationMinutes,
        );

        // The host's route is the walk's main route (summary map, walk card).
        final walk = await _firestore.collection('walks').doc(walkId).get();
        if (walk.data()?['hostUid'] == uid) {
          await walk.reference.update({
            'trackingCompleted': true,
            'actualDistanceKm': stats['totalDistanceKm'],
            'averageSpeed': stats['averageSpeed'],
            'maxSpeed': stats['maxSpeed'],
            'routePointsCount': route.length,
          });
        }
      }

      CrashService.log(
        'Stopped tracking walk $walkId. Distance: ${stats['totalDistanceKm']} km',
      );
      return stats;
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'GPSTrackingService.stopTracking error for walk $walkId',
      );
      rethrow;
    }
  }

  /// Distance and speed statistics for a route.
  Map<String, double> _calculateRouteStats(List<Map<String, dynamic>> route) {
    if (route.isEmpty) {
      return {'totalDistanceKm': 0.0, 'averageSpeed': 0.0, 'maxSpeed': 0.0};
    }

    double totalDistanceMeters = 0;
    double maxSpeedMps = 0;

    for (int i = 1; i < route.length; i++) {
      final prev = route[i - 1];
      final curr = route[i];
      totalDistanceMeters += _haversineDistance(
        (prev['latitude'] as num).toDouble(),
        (prev['longitude'] as num).toDouble(),
        (curr['latitude'] as num).toDouble(),
        (curr['longitude'] as num).toDouble(),
      );
      final speed = (curr['speed'] as num?)?.toDouble() ?? 0;
      if (speed > maxSpeedMps) maxSpeedMps = speed;
    }

    final distanceKm = totalDistanceMeters / 1000;

    double avgSpeedMps = 0;
    if (route.length >= 2) {
      final first = (route.first['timestamp'] as Timestamp).toDate();
      final last = (route.last['timestamp'] as Timestamp).toDate();
      final seconds = last.difference(first).inSeconds.toDouble();
      if (seconds > 0) avgSpeedMps = totalDistanceMeters / seconds;
    }

    // Convert m/s to mph (1 m/s = 2.237 mph)
    return {
      'totalDistanceKm': double.parse(distanceKm.toStringAsFixed(2)),
      'averageSpeed': double.parse((avgSpeedMps * 2.237).toStringAsFixed(1)),
      'maxSpeed': double.parse((maxSpeedMps * 2.237).toStringAsFixed(1)),
    };
  }

  /// Haversine distance between two lat/lng points, in metres.
  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371000; // Earth radius in metres
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  /// Current session's route (for live map display).
  List<Map<String, dynamic>> getCurrentRoute(String walkId) {
    return _routeData[walkId] ?? [];
  }

  bool isTracking(String walkId) {
    return _trackingSubscriptions.containsKey(walkId);
  }

  /// Stop all active tracking, saving unsaved points first.
  Future<void> stopAllTracking() async {
    try {
      for (final walkId in _trackingSubscriptions.keys.toList()) {
        await _trackingSubscriptions.remove(walkId)?.cancel();
        await _saveNextChunk(walkId, flush: true);
      }
      _routeData.clear();
      _savedCount.clear();
      CrashService.log('Stopped all walk tracking');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'GPSTrackingService.stopAllTracking error',
      );
    }
  }
}
