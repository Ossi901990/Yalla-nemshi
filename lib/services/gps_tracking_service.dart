import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'crash_service.dart';

/// Service for real-time GPS tracking during active walks
/// Stores route data in /walks/{walkId}/tracking
class GPSTrackingService {
  static final GPSTrackingService _instance = GPSTrackingService._internal();

  factory GPSTrackingService() => _instance;

  GPSTrackingService._internal();

  static GPSTrackingService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Active tracking subscriptions by walkId
  final Map<String, StreamSubscription<Position>> _trackingSubscriptions = {};
  final Map<String, List<Map<String, dynamic>>> _routeData = {};

  /// Start tracking a walk in real-time
  /// Stores GPS positions to Firestore every 10 seconds (configurable)
  Future<void> startTracking(
    String walkId, {
    Duration updateInterval = const Duration(seconds: 10),
  }) async {
    try {
      // Check if already tracking
      if (_trackingSubscriptions.containsKey(walkId)) {
        CrashService.log('Already tracking walk $walkId');
        return;
      }

      // Request location permission
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

      // Initialize route storage
      _routeData[walkId] = [];

      // Start listening to position updates
      final subscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5, // Update on 5m change
          timeLimit: updateInterval,
        ),
      ).listen(
        (Position position) async {
          await _onPositionUpdate(walkId, position);
        },
        onError: (e) {
          CrashService.recordError(
            e,
            StackTrace.current,
            reason: 'GPSTrackingService position stream error for walk $walkId',
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

  /// Handle position update - store locally and periodically to Firestore
  Future<void> _onPositionUpdate(String walkId, Position position) async {
    try {
      final pointData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed, // m/s
        'heading': position.heading, // degrees
        'timestamp': Timestamp.fromDate(position.timestamp ?? DateTime.now()),
      };

      // Store in local list
      if (_routeData.containsKey(walkId)) {
        _routeData[walkId]!.add(pointData);
      }

      // Every 30 points (5 minutes at 10s intervals), save batch to Firestore
      var len = _routeData[walkId]?.length;
      if (len != null && len % 30 == 0) {
        await _saveBatchToFirestore(walkId);
      }
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'GPSTrackingService._onPositionUpdate error for walk $walkId',
      );
    }
  }

  /// Save route batch to Firestore
  Future<void> _saveBatchToFirestore(String walkId) async {
    try {
      final batch = _firestore.batch();
      final pointCount = _routeData[walkId]?.length ?? 0;

      // Save 30 points at a time to avoid large document size issues
      for (int i = 0; i < (_routeData[walkId]?.length ?? 0); i++) {
        final point = _routeData[walkId]![i];
        final pointRef = _firestore
            .collection('walks')
            .doc(walkId)
            .collection('tracking')
            .doc('point_$i');
        batch.set(pointRef, point);
      }

      // Update walk document with point count
      final walkRef = _firestore.collection('walks').doc(walkId);
      batch.update(walkRef, {
        'trackingPointsCount': pointCount,
        'lastTrackingUpdate': Timestamp.now(),
      });

      await batch.commit();
      CrashService.log('Saved $pointCount tracking points for walk $walkId');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'GPSTrackingService._saveBatchToFirestore error for walk $walkId',
      );
    }
  }

  /// Stop tracking a walk and return final route data
  Future<Map<String, dynamic>> stopTracking(String walkId) async {
    try {
      // Cancel subscription
      _trackingSubscriptions[walkId]?.cancel();
      _trackingSubscriptions.remove(walkId);

      // Save remaining points
      if ((_routeData[walkId]?.length ?? 0) > 0) {
        await _saveBatchToFirestore(walkId);
      }

      // Calculate route statistics
      final route = _routeData[walkId] ?? [];
      final stats = _calculateRouteStats(route);

      // Save route summary to Firestore
      await _firestore.collection('walks').doc(walkId).update({
        'trackingCompleted': true,
        'actualDistanceKm': stats['totalDistanceKm'],
        'averageSpeed': stats['averageSpeedMph'],
        'maxSpeed': stats['maxSpeedMph'],
        'routePointsCount': route.length,
      });

      // Clear local cache
      _routeData.remove(walkId);

      CrashService.log('Stopped tracking walk $walkId. Distance: ${stats['totalDistanceKm']} km');

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

  /// Calculate distance and speed statistics from route
  Map<String, double> _calculateRouteStats(List<Map<String, dynamic>> route) {
    if (route.isEmpty) {
      return {
        'totalDistanceKm': 0.0,
        'averageSpeedMph': 0.0,
        'maxSpeedMph': 0.0,
      };
    }

    double totalDistanceMeters = 0;
    double maxSpeedMps = 0;

    // Calculate distances between consecutive points using Haversine
    for (int i = 1; i < route.length; i++) {
      final prev = route[i - 1];
      final curr = route[i];

      final distance = _haversineDistance(
        prev['latitude'] as double,
        prev['longitude'] as double,
        curr['latitude'] as double,
        curr['longitude'] as double,
      );

      totalDistanceMeters += distance;

      // Track max speed
      final speed = (curr['speed'] as double?) ?? 0;
      if (speed > maxSpeedMps) {
        maxSpeedMps = speed;
      }
    }

    final distanceKm = totalDistanceMeters / 1000;
    final avgSpeedMps = route.isNotEmpty ? maxSpeedMps : 0;
    
    // Convert m/s to mph (1 m/s = 2.237 mph)
    final avgSpeedMph = avgSpeedMps * 2.237;
    final maxSpeedMph = maxSpeedMps * 2.237;

    return {
      'totalDistanceKm': double.parse(distanceKm.toStringAsFixed(2)),
      'averageSpeedMph': double.parse(avgSpeedMph.toStringAsFixed(1)),
      'maxSpeedMph': double.parse(maxSpeedMph.toStringAsFixed(1)),
    };
  }

  /// Haversine formula: calculate distance between two lat/lng points
  /// Returns distance in meters
  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371000; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * (3.14159265359 / 180);

  /// Get current route polyline (for map display)
  List<Map<String, dynamic>> getCurrentRoute(String walkId) {
    return _routeData[walkId] ?? [];
  }

  /// Is a walk currently being tracked?
  bool isTracking(String walkId) {
    return _trackingSubscriptions.containsKey(walkId);
  }

  /// Stop all active tracking
  Future<void> stopAllTracking() async {
    try {
      for (final subscription in _trackingSubscriptions.values) {
        subscription.cancel();
      }
      _trackingSubscriptions.clear();
      _routeData.clear();
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
