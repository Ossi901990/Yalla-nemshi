// lib/screens/walks/walks_map_view.dart
//
// Map of walks (Nearby → Map). One pin per walk meeting point: lime for open
// walks, coral for walks you joined or host. Tapping a pin shows the walk's
// row at the bottom; tapping the row opens the walk.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/walk_event.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/floating_nav_bar.dart';
import '../../widgets/ui/ui_kit.dart';
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
  GoogleMapController? _map;
  String? _selectedId;

  // Sarajevo, used only when no walk has a location.
  static const _fallback = LatLng(43.8563, 18.4131);

  List<(WalkEvent, LatLng)> get _pinned => [
    for (final w in widget.walks)
      if (WalksMapView.positionOf(w) case final pos?) (w, pos),
  ];

  String _id(WalkEvent w) => w.firestoreId.isNotEmpty ? w.firestoreId : w.id;

  @override
  void didUpdateWidget(covariant WalksMapView old) {
    super.didUpdateWidget(old);
    // Filters changed: drop a selection that's no longer shown, refit.
    if (_selectedId != null &&
        !widget.walks.any((w) => _id(w) == _selectedId)) {
      _selectedId = null;
    }
    if (old.walks.length != widget.walks.length) _fitPins();
  }

  Future<void> _fitPins() async {
    final map = _map;
    final pins = _pinned.map((p) => p.$2).toList();
    if (map == null || pins.isEmpty) return;
    if (pins.length == 1) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(pins.first, 14));
      return;
    }
    var south = pins.first.latitude, north = south;
    var west = pins.first.longitude, east = west;
    for (final p in pins) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    await map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pinned = _pinned;
    final selected = pinned
        .map((e) => e.$1)
        .where((w) => _id(w) == _selectedId)
        .firstOrNull;

    final markers = {
      for (final (w, pos) in pinned)
        Marker(
          markerId: MarkerId(_id(w)),
          position: pos,
          // Lime for open walks, coral for walks you're part of.
          icon: BitmapDescriptor.defaultMarkerWithHue(
            (w.joined || w.isOwner) ? 18 : 75,
          ),
          infoWindow: InfoWindow(title: w.title),
          onTap: () => setState(() => _selectedId = _id(w)),
        ),
    };

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpace.radiusCard),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: pinned.isNotEmpty ? pinned.first.$2 : _fallback,
                zoom: 13,
              ),
              markers: markers,
              style: isDark ? _darkMapStyle : null,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (c) {
                _map = c;
                _fitPins();
              },
              onTap: (_) => setState(() => _selectedId = null),
            ),
          ),
        ),
        if (pinned.isEmpty)
          Positioned(
            left: AppSpace.lg,
            right: AppSpace.lg,
            top: AppSpace.lg,
            child: AppCard(
              child: Text(
                widget.walks.isEmpty
                    ? 'No walks match your filters.'
                    : "These walks don't have a map location yet.",
                style: AppText.body(15, color: p.text, weight: FontWeight.w700),
              ),
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

/// Muted dark map that matches the app's dark mode.
const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#142228"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#a9bcc1"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0d171b"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1e3138"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#214a57"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]
''';
