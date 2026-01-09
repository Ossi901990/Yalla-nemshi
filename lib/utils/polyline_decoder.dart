// lib/utils/polyline_decoder.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolylineDecoder {
  // ORS coordinate format: [lng, lat]
  static List<LatLng> decodeORS(List<dynamic> coords) {
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  // Optional: decode encoded polyline strings
  static List<List<double>> decodePolylineToLngLat(String encoded) {
    List<List<double>> result = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, res = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        res |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      lat += dlat;

      shift = 0;
      res = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        res |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      lng += dlng;

      result.add([lng / 1E5, lat / 1E5]);
    }

    return result;
  }
}
