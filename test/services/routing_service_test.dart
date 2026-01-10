import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_nemshi/models/route_result.dart';
import 'package:yalla_nemshi/services/routing_service.dart';

void main() {
  group('RoutingService', () {
    test('getWalkingRoute returns RouteResult on 200 with valid JSON', () async {
      final mockClient = MockClient((request) async {
        final responseJson = {
          "routes": [
            {
              "summary": {"distance": 1234.5, "duration": 456.7},
              "geometry": {
                "coordinates": [
                  [10.0, 20.0],
                  [10.1, 20.1]
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(responseJson), 200, headers: {
          'content-type': 'application/json'
        });
      });

      final service = RoutingService(apiKey: 'test', client: mockClient);
      final result = await service.getWalkingRoute(
        start: const LatLng(20.0, 10.0),
        end: const LatLng(20.1, 10.1),
      );

      expect(result, isA<RouteResult>());
      expect(result!.distanceMeters, closeTo(1234.5, 0.0001));
      expect(result.durationSeconds, closeTo(456.7, 0.0001));
      expect(result.points.length, greaterThanOrEqualTo(2));
    });

    test('getWalkingRoute returns null on non-200', () async {
      final mockClient = MockClient((request) async {
        return http.Response('error', 400);
      });

      final service = RoutingService(apiKey: 'test', client: mockClient);
      final res = await service.getWalkingRoute(
        start: const LatLng(0, 0),
        end: const LatLng(1, 1),
      );
      expect(res, isNull);
    });

    test('getWalkingRoute returns null when routes key missing', () async {
      final mockClient = MockClient((request) async {
        final badJson = {"data": {"foo": 1}};
        return http.Response(jsonEncode(badJson), 200, headers: {
          'content-type': 'application/json'
        });
      });

      final service = RoutingService(apiKey: 'test', client: mockClient);
      final res = await service.getWalkingRoute(
        start: const LatLng(0, 0),
        end: const LatLng(1, 1),
      );
      expect(res, isNull);
    });

    test('getWalkingLoop handles 200 with valid JSON', () async {
      final mockClient = MockClient((request) async {
        final responseJson = {
          "routes": [
            {
              "summary": {"distance": 2000.0, "duration": 600.0},
              "geometry": {
                "coordinates": [
                  [10.0, 20.0], [10.05, 20.05], [10.1, 20.1]
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(responseJson), 200, headers: {
          'content-type': 'application/json'
        });
      });

      final service = RoutingService(apiKey: 'test', client: mockClient);
      final result = await service.getWalkingLoop(
        start: const LatLng(20.0, 10.0),
        lengthMeters: 2000,
      );

      expect(result, isA<RouteResult>());
      expect(result!.points.length, greaterThanOrEqualTo(3));
    });
  });
}
