import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/remote/directions_service.dart';
import '../models/place_map.dart';

class MapService {
  final DirectionsService directionsService;

  MapService({required this.directionsService});

  /// Returns a polyline route between the given places
  Future<List<LatLng>> getRoutePolyline(List<Placemap> places) async {
    if (places.length < 2) return places.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final result = await directionsService.getRoute(places);
    return result.polylinePoints;
  }

  /// Returns total distance in meters between the given places
  Future<int> getTotalDistance(List<Placemap> places) async {
    if (places.length < 2) return 0;
    final result = await directionsService.getRoute(places);
    return result.totalDistanceMeters;
  }

  /// Returns total duration in seconds between the given places
  Future<int> getTotalDuration(List<Placemap> places) async {
    if (places.length < 2) return 0;
    final result = await directionsService.getRoute(places);
    return result.totalDurationSeconds;
  }
}
