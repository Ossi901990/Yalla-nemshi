// lib/screens/map_pick_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/routing_service.dart';
import '../models/route_result.dart';

class MapPickScreen extends StatefulWidget {
  const MapPickScreen({super.key});

  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;

  Polyline? _routePolyline;
  RouteResult? _routeResult;

  // IMPORTANT: Add your ORS API key
  final routing = RoutingService(
    apiKey:
        "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjI3NjQyMjU0OTBjYjQ0M2E5MWRjYzBkZGIzNzVkZDVhIiwiaCI6Im11cm11cjY0In0=",
  );

  static const LatLng _initialPosition = LatLng(31.9539, 35.9106);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick meeting point')),
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
                _selectedLatLng = tapped;
              });

              _mapController?.animateCamera(CameraUpdate.newLatLng(tapped));

              await _fetchRouteTo(tapped);
            },

            markers: {
              if (_selectedLatLng != null)
                Marker(
                  markerId: const MarkerId('meeting_point'),
                  position: _selectedLatLng!,
                  infoWindow: const InfoWindow(title: 'Meeting point'),
                ),
            },

            polylines: {if (_routePolyline != null) _routePolyline!},
          ),

          // Distance card
          if (_routeResult != null)
            Positioned(
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildDistanceCard(),
                ),
              ),
            ),

          // Loop generator button
          Positioned(
            right: 16,
            top: 120,
            child: FloatingActionButton(
              heroTag: "loopPicker",
              backgroundColor: Colors.green,
              onPressed: _showLoopPicker,
              child: const Icon(Icons.loop),
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
                  if (_selectedLatLng == null)
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
                        'Tap on the map to choose a meeting point',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selectedLatLng == null
                          ? null
                          : () {
                              Navigator.of(context).pop(_selectedLatLng);
                            },
                      child: const Text(
                        'Confirm meeting point',
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

  // ----------------------------------------------------------
  // FETCH ROUTE TO SPECIFIC POINT
  // ----------------------------------------------------------
  Future<void> _fetchRouteTo(LatLng target) async {
    LatLng start;

    final cameraPos = await _mapController?.getLatLng(
      const ScreenCoordinate(x: 10, y: 10),
    );

    start = cameraPos ?? _initialPosition;

    final result = await routing.getWalkingRoute(start: start, end: target);

    if (result == null) {
      print("❌ Could not fetch route");
      return;
    }

    setState(() {
      _routeResult = result;
      _routePolyline = Polyline(
        polylineId: const PolylineId("route"),
        points: result.points,
        width: 6,
        color: Colors.blue,
      );
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFromLatLngList(result.points), 50),
    );
  }

  // ----------------------------------------------------------
  // LOOP GENERATOR + PICKER
  // ----------------------------------------------------------
  void _showLoopPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SizedBox(
        height: 220,
        child: Column(
          children: [
            const SizedBox(height: 18),
            const Text(
              "Select Loop Distance",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),

            _loopOption(2000, "2 km"),
            _loopOption(4000, "4 km"),
            _loopOption(6000, "6 km"),
            _loopOption(10000, "10 km"),
          ],
        ),
      ),
    );
  }

  Widget _loopOption(int meters, String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        _generateLoop(meters);
      },
    );
  }

  Future<void> _generateLoop(int meters) async {
    final start = await _mapController?.getLatLng(
      const ScreenCoordinate(x: 200, y: 400),
    );

    if (start == null) {
      print("❌ Cannot get start point for loop");
      return;
    }

    final result = await routing.getWalkingLoop(
      start: start,
      lengthMeters: meters,
      points: 3,
    );

    if (result == null) {
      print("❌ Failed to generate loop");
      return;
    }

    setState(() {
      _routeResult = result;
      _routePolyline = Polyline(
        polylineId: const PolylineId("loop"),
        points: result.points,
        width: 6,
        color: Colors.green,
      );
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFromLatLngList(result.points), 50),
    );
  }

  // ----------------------------------------------------------
  // UI HELPERS
  // ----------------------------------------------------------
  Widget _buildDistanceCard() {
    final km = (_routeResult!.distanceMeters / 1000).toStringAsFixed(2);
    final min = (_routeResult!.durationSeconds / 60).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          "$km km  •  $min min walk",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

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
