  import 'dart:convert';
  import 'package:http/http.dart' as http;
  import 'package:google_maps_flutter/google_maps_flutter.dart';
  import '../../models/place_map.dart';
  import '../../utils/polyline_decoder.dart';
  import '../../utils/haversine.dart';


  class DirectionsResult {
    final List<LatLng> polylinePoints;
    final int totalDistanceMeters;
    final int totalDurationSeconds;

    DirectionsResult({
      required this.polylinePoints,
      required this.totalDistanceMeters,
      required this.totalDurationSeconds,
    });
  }

  class DirectionsService {
    final String? apiKey;
    DirectionsService({this.apiKey});

    Future<DirectionsResult> getRoute(List<Placemap> places) async {
      if (places.length < 2) {
        final pts = places.map((p) => LatLng(p.latitude, p.longitude)).toList();
        return DirectionsResult(polylinePoints: pts, totalDistanceMeters: 0, totalDurationSeconds: 0);
      }

      if (apiKey != null && apiKey!.isNotEmpty) {
        final origin = '${places.first.latitude},${places.first.longitude}';
        final destination = '${places.last.latitude},${places.last.longitude}';
        String? waypoints;
        if (places.length > 2) {
          final middle = places.sublist(1, places.length - 1);
          waypoints = middle.map((p) => '${p.latitude},${p.longitude}').join('|');
        }

        final params = {
          'origin': origin,
          'destination': destination,
          'key': apiKey!,
          'mode': 'driving',
        };
        if (waypoints != null) params['waypoints'] = 'optimize:false|$waypoints';

        final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          if ((json['routes'] as List).isNotEmpty) {
            final route = (json['routes'] as List).first as Map<String, dynamic>;
            final overview = (route['overview_polyline'] as Map<String, dynamic>)['points'] as String;
            final poly = PolylineDecoder.decode(overview);
            int dist = 0;
            int dur = 0;
            final legs = (route['legs'] as List).cast<Map<String, dynamic>>();
            for (final leg in legs) {
              dist += (leg['distance']['value'] as int);
              dur += (leg['duration']['value'] as int);
            }
            return DirectionsResult(polylinePoints: poly, totalDistanceMeters: dist, totalDurationSeconds: dur);
          }
        }
      }

      // fallback: direct lines (haversine-based estimate)
      print('⚠️ Directions API failed, using haversine fallback.');

      final pts = places.map((p) => LatLng(p.latitude, p.longitude)).toList();
      int totalDist = 0;
      for (int i = 0; i < places.length - 1; i++) {
        final d = Haversine.distanceMeters(
          places[i].latitude,
          places[i].longitude,
          places[i + 1].latitude,
          places[i + 1].longitude,
        ).round();
        totalDist += d;
      }
      final durationEstimate = (totalDist / (40 * 1000 / 3600)).round(); // 40 km/h

      return DirectionsResult(polylinePoints: pts, totalDistanceMeters: totalDist, totalDurationSeconds: durationEstimate);
    }
  }
