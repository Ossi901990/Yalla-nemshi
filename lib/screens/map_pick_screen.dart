// lib/screens/map_pick_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// Routing/automatic route generation removed — this screen now only
// allows picking a start and an end point and returns them to the caller.

class MapPickScreen extends StatefulWidget {
  const MapPickScreen({super.key});

  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  // ✅ Put your Google API key here (must have Geocoding API enabled)
  // Tip: later we can move it to a safer config approach.
  static const String _googleApiKey = 'AIzaSyCf4xhAGD2FlnFwsFjGpZZoXa5pnB4oRqM';

  final TextEditingController _searchCtrl = TextEditingController();
  bool _searchLoading = false;

  GoogleMapController? _mapController;

  // We collect start and end points (two taps). The caller expects both
  // points returned when confirming.
  LatLng? _startLatLng;
  LatLng? _endLatLng;

  static const LatLng _initialPosition = LatLng(31.9539, 35.9106);

  Future<void> _searchAndGo(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    if (_googleApiKey == 'PASTE_YOUR_GOOGLE_API_KEY_HERE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your Google API key in MapPickScreen.'),
        ),
      );
      return;
    }

    setState(() => _searchLoading = true);

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(q)}'
        '&key=$_googleApiKey',
      );

      final res = await http.get(uri);
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final status = data['status']?.toString();
      if (status != 'OK') {
        throw Exception(data['error_message'] ?? 'Search failed ($status)');
      }

      final results = (data['results'] as List);
      if (results.isEmpty) {
        throw Exception('No results found.');
      }

      final loc = results.first['geometry']['location'];
      final lat = (loc['lat'] as num).toDouble();
      final lng = (loc['lng'] as num).toDouble();
      final target = LatLng(lat, lng);

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 15),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search error: $e')));
      }
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hintText = _startLatLng == null
        ? 'Tap on the map to set the START point'
        : (_endLatLng == null
              ? 'Tap on the map to set the END point'
              : 'Tap again to reset (start over)');

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
            onTap: (LatLng tapped) {
              setState(() {
                // First tap sets start. Second tap sets end. Third tap resets.
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
                    BitmapDescriptor.hueGreen,
                  ),
                ),
              if (_endLatLng != null)
                Marker(
                  markerId: const MarkerId('end_point'),
                  position: _endLatLng!,
                  infoWindow: const InfoWindow(title: 'End'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
                ),
            },
          ),

          // ✅ Search bar overlay
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: SafeArea(
              bottom: false,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchAndGo,
                  decoration: InputDecoration(
                    hintText: 'Search a place…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              FocusScope.of(context).unfocus();
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                  ),
                ),
              ),
            ),
          ),

          // Helper hint banner (placed UNDER search bar so they don't overlap)
          Positioned(
            left: 16,
            right: 16,
            top: 72,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.6 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    hintText,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                        color: Colors.black.withAlpha((0.6 * 255).round()),
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
                              Navigator.of(
                                context,
                              ).pop([_startLatLng!, _endLatLng!]);
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
}

