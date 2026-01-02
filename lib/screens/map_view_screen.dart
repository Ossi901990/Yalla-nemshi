// lib/screens/map_view_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapViewScreen extends StatelessWidget {
  final double lat;
  final double lng;
  final String? placeName;

  const MapViewScreen({
    super.key,
    required this.lat,
    required this.lng,
    this.placeName,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng target = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting point')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: target, zoom: 15),
        markers: {
          Marker(
            markerId: const MarkerId('meeting_point'),
            position: target,
            infoWindow: InfoWindow(title: placeName ?? 'Meeting point'),
          ),
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }
}
