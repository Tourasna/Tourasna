    // lib/features/interactive_map/utils/polyline_decoder.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolylineDecoder {
  static List<LatLng> decode(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      while (true) {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      while (true) {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final pt = LatLng(lat / 1e5, lng / 1e5);
      poly.add(pt);
    }
    return poly;
  }
}
