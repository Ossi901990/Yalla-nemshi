import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'crash_service.dart';
import '../models/app_exception.dart';

/// Service to convert coordinates (lat/lng) → city name using Google Geocoding API
class GeocodingService {
  // 🔹 This is the public API key — it's okay to keep it here for now
  // In production, you should use Cloud API keys with restrictions
  static const String _googleGeocodingApiKey = 'AIzaSyBNZj_FBNB1L3V8UAVUScTrjpCWDc8lTT8';

  /// Convert latitude/longitude to city name
  /// Throws LocationException if unable to determine
  static Future<String?> getCityFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$latitude,$longitude'
        '&key=$_googleGeocodingApiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw LocationException(
          message: 'Geocoding request timed out.',
          originalError: Exception('HTTP timeout'),
        ),
      );

      if (response.statusCode != 200) {
        throw LocationException(
          message: 'Unable to determine location: HTTP ${response.statusCode}',
          code: 'geocoding/http-${response.statusCode}',
          originalError: Exception('HTTP ${response.statusCode}'),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String?;

      if (status != 'OK') {
        throw LocationException(
          message: 'Geocoding API returned status: $status',
          code: 'geocoding/$status',
        );
      }

      final results = json['results'] as List?;

      if (results == null || results.isEmpty) {
        debugPrint('⚠️ No geocoding results found');
        return null;
      }

      // Extract city/locality from address components
      final addressComponents = results[0]['address_components'] as List?;
      if (addressComponents == null) return null;

      // Look for "locality" (city), fall back to "administrative_area_level_1" (state)
      String? city;
      for (final component in addressComponents) {
        final types = (component['types'] as List?)?.cast<String>() ?? [];
        final longName = component['long_name'] as String?;

        if (types.contains('locality') && longName != null) {
          city = longName;
          break;
        }
        if (types.contains('administrative_area_level_1') && city == null && longName != null) {
          city = longName;
        }
      }

      if (city != null) {
        debugPrint('✅ Detected city: $city');
      }
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
}
