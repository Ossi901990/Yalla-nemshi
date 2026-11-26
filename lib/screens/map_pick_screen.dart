// lib/screens/map_pick_screen.dart
//
// Pick a walk's start and end point on an OpenStreetMap map (no API key or
// billing). First tap = start, second tap = end, third tap starts over.
// Returns [start, end] as google_maps_flutter LatLng values (only the data
// type; create_walk_screen uses it throughout).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../widgets/osm_map.dart';
import '../widgets/ui/ui_kit.dart';

class MapPickScreen extends StatefulWidget {
  const MapPickScreen({super.key});

  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();
  bool _searchLoading = false;

  LatLng? _start;
  LatLng? _end;

  // Amman (the original default), used when the location isn't available.
  static const _fallback = LatLng(31.9539, 35.9106);
  LatLng? _initial;

  @override
  void initState() {
    super.initState();
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    var target = _fallback;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        target = LatLng(pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint('Could not get current location: $e');
    }
    if (mounted) setState(() => _initial = target);
  }

  Future<void> _searchAndGo(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _searchLoading = true);
    try {
      final hit = await GeocodingService.searchPlace(q);
      if (!mounted) return;
      if (hit == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No place found for "$q".')));
        return;
      }
      _map.move(LatLng(hit.latitude, hit.longitude), 15);
      FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  void _onTap(LatLng tapped) {
    setState(() {
      if (_start == null) {
        _start = tapped;
      } else if (_end == null) {
        _end = tapped;
      } else {
        _start = tapped;
        _end = null;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hint = _start == null
        ? 'Tap the map to set the START point'
        : (_end == null
              ? 'Now tap to set the END point'
              : 'Tap again to start over');

    return Scaffold(
      backgroundColor: p.background,
      body: _initial == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _initial!,
                      initialZoom: 15,
                      onTap: (_, point) => _onTap(point),
                    ),
                    children: [
                      OsmMap.tiles(context),
                      if (_start != null && _end != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_start!, _end!],
                              strokeWidth: 4,
                              color: AppPalette.ink.withValues(alpha: 0.6),
                              pattern: StrokePattern.dashed(
                                segments: const [10, 8],
                              ),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_start != null)
                            Marker(
                              point: _start!,
                              width: 40,
                              height: 40,
                              child: const Center(
                                child: MapPin(color: AppPalette.lime),
                              ),
                            ),
                          if (_end != null)
                            Marker(
                              point: _end!,
                              width: 40,
                              height: 40,
                              child: const Center(
                                child: MapPin(color: AppPalette.coral),
                              ),
                            ),
                        ],
                      ),
                      OsmMap.attribution(),
                    ],
                  ),
                ),

                // Top: back + search, then the hint
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            RoundIconButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.maybePop(context),
                              tooltip: 'Back',
                              size: 48,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Material(
                                color: p.surface,
                                shape: StadiumBorder(
                                  side: BorderSide(color: p.border),
                                ),
                                child: TextField(
                                  controller: _searchCtrl,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _searchAndGo,
                                  style: AppText.body(15, color: p.text),
                                  decoration: InputDecoration(
                                    hintText: 'Search a place…',
                                    hintStyle: AppText.body(
                                      15,
                                      color: p.textMuted,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: p.text,
                                    ),
                                    suffixIcon: _searchLoading
                                        ? const Padding(
                                            padding: EdgeInsets.all(14),
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: PillLabel(
                            text: hint,
                            background: AppPalette.ink,
                            foreground: Colors.white,
                            dotColor: _start == null
                                ? AppPalette.lime
                                : AppPalette.coral,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              12,
              AppSpace.page,
              12,
            ),
            child: PillButton(
              label: 'Use these points',
              icon: Icons.check_rounded,
              expand: true,
              dark: !isDark,
              onPressed: (_start == null || _end == null)
                  ? null
                  : () => Navigator.of(context).pop([
                      gm.LatLng(_start!.latitude, _start!.longitude),
                      gm.LatLng(_end!.latitude, _end!.longitude),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}
