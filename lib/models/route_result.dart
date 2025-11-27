// lib/models/route_result.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/polyline_decoder.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    dynamic routes = json["routes"];

    // Case 1: "routes" is a List
    if (routes is List) {
      routes = routes[0];
    }

    // Case 2: "routes" is a Map
    final summary = routes["summary"];
    final geometry = routes["geometry"];

    List<dynamic> coords;

    if (geometry is Map && geometry["coordinates"] is List) {
      coords = geometry["coordinates"];
    } else if (geometry is String) {
      // Encoded polyline case
      coords = PolylineDecoder.decodePolylineToLngLat(geometry);
    } else {
      throw Exception("Unknown geometry format: $geometry");
    }

    return RouteResult(
      points: PolylineDecoder.decodeORS(coords),
      distanceMeters: (summary["distance"] ?? 0).toDouble(),
      durationSeconds: (summary["duration"] ?? 0).toDouble(),
    );
  }
}
