// lib/services/routing_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_result.dart';

class RoutingService {
  final String apiKey;

  RoutingService({required this.apiKey});

  // ----------------------------------------------------------
  // STANDARD WALKING ROUTE (Point A → Point B)
  // ----------------------------------------------------------
  Future<RouteResult?> getWalkingRoute({
    required LatLng start,
    required LatLng end,
    List<List<List<double>>>? avoidPolygons,
  }) async {
   final url = Uri.parse(
  "https://api.openrouteservice.org/v2/directions/foot-walking",
);


    final Map<String, dynamic> body = {
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
    };

    if (avoidPolygons != null && avoidPolygons.isNotEmpty) {
      body["options"] = {
        "avoid_polygons": {
          "type": "MultiPolygon",
          "coordinates": avoidPolygons,
        }
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": apiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      print("🔍 ORS Raw Response:");
      print(response.body);

      if (response.statusCode != 200) {
        print("❌ ORS Error Response (${response.statusCode}):");
        print(response.body);
        return null;
      }

      print("🔍 Decoding JSON now...");
      final json = jsonDecode(response.body);

      if (json["routes"] == null) {
        print("❌ ERROR: json['routes'] is NULL — no route returned.");
        return null;
      }

      return RouteResult.fromJson(json);
    } catch (e) {
      print("❌ Error during routing request: $e");
      return null;
    }
  }

  // ----------------------------------------------------------
  // WALKING LOOP GENERATOR (Circular route)
  // ----------------------------------------------------------
  Future<RouteResult?> getWalkingLoop({
    required LatLng start,
    required int lengthMeters,
    int points = 3,
  }) async {
    final url = Uri.parse(
      "https://api.openrouteservice.org/v2/directions/foot-walking",
    );

    final Map<String, dynamic> body = {
      "coordinates": [
        [start.longitude, start.latitude]
      ],
      "round_trip": {
        "length": lengthMeters,
        "points": points,
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": apiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      print("🔍 ORS Loop Response:");
      print(response.body);

      if (response.statusCode != 200) {
        print("❌ ORS Loop Error (${response.statusCode})");
        print(response.body);
        return null;
      }

      final json = jsonDecode(response.body);

      if (json["routes"] == null) {
        print("❌ No loop route returned");
        return null;
      }

      return RouteResult.fromJson(json);
    } catch (e) {
      print("❌ Error generating loop: $e");
      return null;
    }
  }
}
