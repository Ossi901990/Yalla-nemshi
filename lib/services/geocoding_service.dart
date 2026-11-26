import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_exception.dart';
import 'crash_service.dart';

/// Place lookups via OpenStreetMap's Nominatim (no API key or billing).
///
/// - [getCityFromCoordinates]: lat/lng → city name (walk city, user city).
/// - [searchPlace]: text → coordinates (map picker search box).
///
/// Nominatim's usage policy (https://operations.osmfoundation.org/policies/nominatim/):
/// identify the app, at most 1 request per second, no bulk use. The app only
/// looks up places on user actions, which fits. For heavy production use,
/// point [_base] at a hosted Nominatim/geocoding provider.
class GeocodingService {
  GeocodingService._();

  static const _base = 'https://nominatim.openstreetmap.org';
  static const _timeout = Duration(seconds: 10);

  static Map<String, String> get _headers => {
    'Accept-Language': 'en',
    // Browsers don't allow setting User-Agent; they send a Referer instead.
    if (!kIsWeb) 'User-Agent': 'YallaNemshi/1.0 (com.yallanemshi.app)',
  };

  /// Convert latitude/longitude to a city name (null if none found).
  /// Throws [LocationException] if the lookup fails.
  static Future<String?> getCityFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.parse(
        '$_base/reverse?format=jsonv2&zoom=10&lat=$latitude&lon=$longitude',
      );
      final response = await http.get(url, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) {
        throw LocationException(
          message: 'Unable to determine location: HTTP ${response.statusCode}',
          code: 'geocoding/http-${response.statusCode}',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      // Most specific "city-like" name available. Some cities (e.g.
      // Sarajevo) only appear as a county ("City of Sarajevo").
      String? pick(String key) {
        final v = (address[key] as String?)?.trim();
        return (v == null || v.isEmpty) ? null : v;
      }

      final county = pick('county')
          ?.replaceFirst(
            RegExp(r'^(City of|Grad)\s+', caseSensitive: false),
            '',
          )
          .replaceFirst(RegExp(r'\s+(Sub-District|District|County)$'), '');
      final city =
          pick('city') ??
          pick('town') ??
          pick('village') ??
          county ??
          pick('municipality') ??
          pick('state');
      if (city != null) debugPrint('✅ Detected city: $city');
      return city;
    } on LocationException {
      rethrow;
    } catch (e, st) {
      final exception = LocationException.fromException(e);
      debugPrint('❌ Geocoding exception: $e');
      CrashService.recordError(exception, st);
      throw exception;
    }
  }

  /// Find a place by name; returns its coordinates, or null if not found or
  /// the lookup failed.
  static Future<({double latitude, double longitude})?> searchPlace(
    String query,
  ) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    try {
      final url = Uri.parse(
        '$_base/search?format=jsonv2&limit=1&q=${Uri.encodeQueryComponent(q)}',
      );
      final response = await http.get(url, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final results = jsonDecode(response.body) as List<dynamic>;
      if (results.isEmpty) return null;
      final hit = results.first as Map<String, dynamic>;
      final lat = double.tryParse('${hit['lat']}');
      final lon = double.tryParse('${hit['lon']}');
      if (lat == null || lon == null) return null;
      return (latitude: lat, longitude: lon);
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'GeocodingService.searchPlace');
      return null;
    }
  }
}
