import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_history.dart';

class TripHistoryService {
  static const String _key = 'trip_history';

  // حفظ رحلة
  Future<void> saveTripHistory(TripHistoryItem trip) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getTripHistory();
    
    // إضافة أو تحديث
    final index = history.indexWhere((t) => t.id == trip.id);
    if (index >= 0) {
      history[index] = trip;
    } else {
      history.add(trip);
    }
    
    final jsonList = history.map((t) => t.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  // جلب كل الرحلات
  Future<List<TripHistoryItem>> getTripHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    
    if (jsonString == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => TripHistoryItem.fromJson(json)).toList();
  }

  // حذف رحلة
  Future<void> deleteTripHistory(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getTripHistory();
    history.removeWhere((t) => t.id == tripId);
    
    final jsonList = history.map((t) => t.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  // مسح كل التاريخ
  Future<void> clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // إحصائيات
  Future<Map<String, dynamic>> getStatistics() async {
    final history = await getTripHistory();
    
    final completedTrips = history.where((t) => t.isCompleted).length;
    final totalPlaces = history.fold<int>(0, (sum, t) => sum + t.placesVisited);
    final totalDistance = history.fold<double>(0, (sum, t) => sum + t.totalDistance);
    
    return {
      'totalTrips': history.length,
      'completedTrips': completedTrips,
      'totalPlaces': totalPlaces,
      'totalDistance': totalDistance,
    };
  }
}