// lib/screens/map_view_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapViewScreen extends StatelessWidget {
  // Legacy single-point view
  final double lat;
  final double lng;
  final String? placeName;

  // Optional: explicit start/end pair for route viewing
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;

  const MapViewScreen({
    super.key,
    required this.lat,
    required this.lng,
    this.placeName,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasRoute = startLat != null && startLng != null && endLat != null && endLng != null;

    // Determine center/zoom
    final LatLng center = hasRoute
        ? LatLng((startLat! + endLat!) / 2.0, (startLng! + endLng!) / 2.0)
        : LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(title: Text(hasRoute ? 'Route' : 'Meeting point')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: hasRoute ? 13 : 15),
        markers: {
          if (hasRoute) ...[
            Marker(
              markerId: const MarkerId('start_point'),
              position: LatLng(startLat!, startLng!),
              infoWindow: const InfoWindow(title: 'Start'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
            Marker(
              markerId: const MarkerId('end_point'),
              position: LatLng(endLat!, endLng!),
              infoWindow: const InfoWindow(title: 'End'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          ] else ...[
            Marker(
              markerId: const MarkerId('meeting_point'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: placeName ?? 'Meeting point'),
            ),
          ]
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }
}
