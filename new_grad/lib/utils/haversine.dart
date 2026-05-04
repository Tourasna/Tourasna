// lib/features/interactive_map/utils/haversine.dart
import 'dart:math';

class Haversine {
  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dphi = (lat2 - lat1) * pi / 180;
    final dlambda = (lon2 - lon1) * pi / 180;
    final a = sin(dphi/2) * sin(dphi/2) + cos(phi1) * cos(phi2) * sin(dlambda/2) * sin(dlambda/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }
}
