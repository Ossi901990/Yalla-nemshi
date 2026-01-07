// lib/screens/map_pick_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Routing/automatic route generation removed — this screen now only
// allows picking a start and an end point and returns them to the caller.

class MapPickScreen extends StatefulWidget {
  const MapPickScreen({super.key});

  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  GoogleMapController? _mapController;
  // We collect start and end points (two taps). The caller expects both
  // points returned when confirming.
  LatLng? _startLatLng;
  LatLng? _endLatLng;

  static const LatLng _initialPosition = LatLng(31.9539, 35.9106);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick start & end')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 13,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,

            onTap: (LatLng tapped) async {
              setState(() {
                // First tap sets start. Second tap sets end. Third tap resets
                // and starts again from the new tap.
                if (_startLatLng == null) {
                  _startLatLng = tapped;
                } else if (_endLatLng == null) {
                  _endLatLng = tapped;
                } else {
                  _startLatLng = tapped;
                  _endLatLng = null;
                }
              });

              _mapController?.animateCamera(CameraUpdate.newLatLng(tapped));
            },

            markers: {
              if (_startLatLng != null)
                Marker(
                  markerId: const MarkerId('start_point'),
                  position: _startLatLng!,
                  infoWindow: const InfoWindow(title: 'Start'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                ),
              if (_endLatLng != null)
                Marker(
                  markerId: const MarkerId('end_point'),
                  position: _endLatLng!,
                  infoWindow: const InfoWindow(title: 'End'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                ),
            },
          ),

          // Simple helper hint when selecting points
          if (_startLatLng == null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Tap on the map to set the START point',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            )
          else if (_endLatLng == null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Tap on the map to set the END point',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

          // Confirm button
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    if (_startLatLng == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                        child: const Text(
                          'Tap on the map to choose start and end points',
                          style: TextStyle(color: Colors.white),
                        ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: (_startLatLng == null || _endLatLng == null)
                          ? null
                          : () {
                                Navigator.of(context).pop([
                                  _startLatLng!,
                                  _endLatLng!,
                                ]);
                            },
                        child: const Text(
                          'Confirm start & end',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UI helpers kept minimal — distance/route generation removed.

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double x0 = list.first.latitude;
    double x1 = list.first.latitude;
    double y0 = list.first.longitude;
    double y1 = list.first.longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(southwest: LatLng(x0, y0), northeast: LatLng(x1, y1));
  }
}
