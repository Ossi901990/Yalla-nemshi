// lib/screens/walks/walks_map_view.dart
//
// Map of walks (Nearby → Map), on OpenStreetMap (no API key or billing).
// One pin per walk meeting point: lime for open walks, coral for walks you
// joined or host. Tapping a pin shows the walk's row at the bottom; tapping
// the row opens the walk.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/walk_event.dart';
import '../../theme/app_palette.dart';
import '../../widgets/osm_map.dart';
import '../../widgets/ui/floating_nav_bar.dart';
import '../../widgets/walk_row.dart';

class WalksMapView extends StatefulWidget {
  const WalksMapView({
    super.key,
    required this.walks,
    required this.onOpen,
    required this.onJoin,
  });

  final List<WalkEvent> walks;
  final void Function(WalkEvent) onOpen;
  final void Function(WalkEvent) onJoin;

  /// Where a walk is on the map (meeting point, else start), or null.
  static LatLng? positionOf(WalkEvent w) {
    final lat = w.meetingLat ?? w.startLat;
    final lng = w.meetingLng ?? w.startLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  State<WalksMapView> createState() => _WalksMapViewState();
}

class _WalksMapViewState extends State<WalksMapView> {
  final _map = MapController();
  bool _ready = false;
  String? _selectedId;

  // Amman (the app's original default), used only when no walk has a location.
  static const _fallback = LatLng(31.9539, 35.9106);

  List<(WalkEvent, LatLng)> get _pinned => [
    for (final w in widget.walks)
      if (WalksMapView.positionOf(w) case final pos?) (w, pos),
  ];

  String _id(WalkEvent w) => w.firestoreId.isNotEmpty ? w.firestoreId : w.id;

  CameraFit? _fitFor(List<LatLng> points) {
    if (points.isEmpty) return null;
    if (points.length == 1) {
      return CameraFit.coordinates(
        coordinates: points,
        maxZoom: 15,
        padding: const EdgeInsets.all(64),
      );
    }
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(64),
      maxZoom: 16,
    );
  }

  @override
  void didUpdateWidget(covariant WalksMapView old) {
    super.didUpdateWidget(old);
    // Filters changed: drop a selection that's no longer shown and refit.
    if (_selectedId != null &&
        !widget.walks.any((w) => _id(w) == _selectedId)) {
      _selectedId = null;
    }
    if (_ready && old.walks.length != widget.walks.length) {
      final fit = _fitFor(_pinned.map((p) => p.$2).toList());
      if (fit != null) _map.fitCamera(fit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pinned;
    final selected = pinned
        .map((e) => e.$1)
        .where((w) => _id(w) == _selectedId)
        .firstOrNull;
    final fit = _fitFor(pinned.map((p) => p.$2).toList());

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpace.radiusCard),
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _fallback,
                initialZoom: 13,
                initialCameraFit: fit,
                onMapReady: () => _ready = true,
                onTap: (_, _) => setState(() => _selectedId = null),
              ),
              children: [
                OsmMap.tiles(context),
                MarkerLayer(
                  markers: [
                    for (final (w, pos) in pinned)
                      Marker(
                        point: pos,
                        width: 44,
                        height: 44,
                        child: Semantics(
                          button: true,
                          label: w.title,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedId = _id(w)),
                            child: Center(
                              child: MapPin(
                                // Lime: open; coral: you're part of it.
                                color: (w.joined || w.isOwner)
                                    ? AppPalette.coral
                                    : AppPalette.lime,
                                selected: _id(w) == _selectedId,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                OsmMap.attribution(),
              ],
            ),
          ),
        ),
        if (pinned.isEmpty)
          Positioned(
            left: AppSpace.lg,
            right: AppSpace.lg,
            top: AppSpace.lg,
            child: MapNote(
              widget.walks.isEmpty
                  ? 'No walks match your filters.'
                  : "These walks don't have a map location yet.",
            ),
          ),
        if (selected != null)
          Positioned(
            left: AppSpace.md,
            right: AppSpace.md,
            bottom: FloatingNavBar.reservedHeight - 8,
            child: Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(AppSpace.radiusCard),
              child: WalkRow(
                walk: selected,
                onOpen: () => widget.onOpen(selected),
                onJoin: () => widget.onJoin(selected),
              ),
            ),
          ),
      ],
    );
  }
}
