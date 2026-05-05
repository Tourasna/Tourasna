import 'dart:convert';
import 'package:flutter/services.dart';
import '../remote/recommendation_service.dart';
import '../../models/trip.dart';

class TripRepository {
  final RecommendationService recService;
  TripRepository({required this.recService});

  // ✅ الدالة الجديدة اللي محتاجها MapProvider
  Future<Trip> loadMockTrip() async {
    try {
      // تحميل الرحلة من ملف sample_trip.json
      final String jsonString = await rootBundle.loadString('assets/data/sample_trip.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      return Trip.fromJson(jsonData);
    } catch (e) {
      throw Exception('❌ Failed to load sample_trip.json: $e');
    }
  }

  // (اختياري) لو عايز تسيب القديمة برضو
  Future<Trip> getMockTrip() => recService.getMockTrip();
}