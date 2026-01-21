import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_event.dart';
import '../design_tokens.dart';

/// Screen showing walk completion summary with route map and statistics
class WalkSummaryScreen extends StatefulWidget {
  final WalkEvent walk;
  final Map<String, dynamic> routeStats; // From GPSTrackingService

  const WalkSummaryScreen({
    super.key,
    required this.walk,
    required this.routeStats,
  });

  @override
  State<WalkSummaryScreen> createState() => _WalkSummaryScreenState();
}

class _WalkSummaryScreenState extends State<WalkSummaryScreen> {
  late GoogleMapController _mapController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Set<Polyline> _polylines = {};
  LatLngBounds? _routeBounds;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutePolyline();
  }

  /// Load route from Firestore and draw polyline
  Future<void> _loadRoutePolyline() async {
    try {
      final trackingSnapshot = await _firestore
          .collection('walks')
          .doc(widget.walk.firestoreId)
          .collection('tracking')
          .orderBy('timestamp')
          .get();

      if (!mounted) return;

      if (trackingSnapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final points = <LatLng>[];
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

      for (final doc in trackingSnapshot.docs) {
        final lat = doc['latitude'] as double;
        final lng = doc['longitude'] as double;
        points.add(LatLng(lat, lng));

        // Track bounds
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }

      // Create polyline
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF1ABFC4),
        width: 5,
        geodesic: true,
      );

      // Calculate bounds with padding
      _routeBounds = LatLngBounds(
        southwest: LatLng(minLat - 0.001, minLng - 0.001),
        northeast: LatLng(maxLat + 0.001, maxLng + 0.001),
      );

      setState(() {
        _polylines = {polyline};
        _isLoading = false;
      });

      // Animate map to fit route
      if (mounted && _routeBounds != null) {
        // Delay to ensure map is ready
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _routeBounds != null) {
            try {
              _mapController.animateCamera(
                CameraUpdate.newLatLngBounds(_routeBounds!, 100),
              );
            } catch (e) {
              // Silently fail if map not ready
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use meeting location or fallback
    final initialLat = widget.walk.meetingLat ?? 30.0;
    final initialLng = widget.walk.meetingLng ?? 31.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk Summary'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Route Map
                  SizedBox(
                    height: 300,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(initialLat, initialLng),
                        zoom: 12,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        // Animate after a small delay to ensure map is ready
                        if (_routeBounds != null) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) {
                              try {
                                _mapController.animateCamera(
                                  CameraUpdate.newLatLngBounds(_routeBounds!, 100),
                                );
                              } catch (e) {
                                // Silently fail if map not ready
                              }
                            }
                          });
                        }
                      },
                      polylines: _polylines,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                  ),

                  // Statistics Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Walk Title
                        Text(
                          widget.walk.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Distance Card
                        _StatCard(
                          icon: Icons.straighten,
                          label: 'Distance',
                          value:
                              '${widget.routeStats['totalDistanceKm']} km',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),

                        // Speed Card
                        _StatCard(
                          icon: Icons.speed,
                          label: 'Avg Speed',
                          value:
                              '${widget.routeStats['averageSpeed']} mph',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),

                        // Max Speed Card
                        _StatCard(
                          icon: Icons.trending_up,
                          label: 'Max Speed',
                          value: '${widget.routeStats['maxSpeed']} mph',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),

                        // Route Points Card
                        _StatCard(
                          icon: Icons.pin_drop,
                          label: 'Route Points',
                          value:
                              '${widget.routeStats['routePointsCount']} points',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),

                        // Actions
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Finish'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1ABFC4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

/// Stat display card
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurface : Colors.grey[100],
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF1ABFC4),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
