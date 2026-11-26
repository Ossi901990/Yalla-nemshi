// lib/widgets/osm_map.dart
//
// OpenStreetMap pieces shared by every map in the app (no API key, no
// billing). OSM's free tile servers have a fair-use policy
// (https://operations.osmfoundation.org/policies/tiles/): fine for testing
// and small apps; for a large launch switch [OsmMap.tileUrl] to a tile
// provider. Attribution must stay visible.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

class OsmMap {
  OsmMap._();

  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Identifies the app to the tile servers (required by OSM's policy).
  static const userAgentPackageName = 'com.yallanemshi.app';

  /// Base map tiles; darkened in dark mode.
  static TileLayer tiles(BuildContext context) => TileLayer(
    urlTemplate: tileUrl,
    userAgentPackageName: userAgentPackageName,
    tileBuilder: Theme.of(context).brightness == Brightness.dark
        ? darkModeTileBuilder
        : null,
  );

  /// "© OpenStreetMap contributors" credit (must stay visible). Our own
  /// small label: flutter_map's SimpleAttributionWidget overflows on narrow
  /// phones.
  static Widget attribution() => const _OsmCredit();
}

class _OsmCredit extends StatelessWidget {
  const _OsmCredit();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '© OpenStreetMap contributors',
                  textScaler: TextScaler.noScaling,
                  style: AppText.body(11, color: AppPalette.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round map pin in the app's style.
class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.color, this.selected = false});

  final Color color;
  final bool selected;

  static const double size = 30;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.25 : 1,
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback text when a map has nothing to show.
class MapNote extends StatelessWidget {
  const MapNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpace.radiusCard),
        border: Border.all(color: p.border),
      ),
      child: Text(
        text,
        style: AppText.body(15, color: p.text, weight: FontWeight.w700),
      ),
    );
  }
}
