import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/trip.dart' as m;


class RecommendationService {
  Future<m.Trip> getMockTrip() async {
  try {
    print("🔍 Loading sample_trip.json...");
    final jsonStr = await rootBundle.loadString('assets/trips/sample_trip.json');
    print("✅ Loaded JSON successfully: ${jsonStr.substring(0, 50)}...");
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return m.Trip.fromJson(json);
  } catch (e, st) {
    print("❌ ERROR loading JSON: $e");
    print(st);
    rethrow;
  }
}

}
