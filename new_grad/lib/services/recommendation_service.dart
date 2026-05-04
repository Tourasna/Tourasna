import 'dart:convert';
import '../models/recommendation_item.dart';
import 'api_client.dart';

class RecommendationService {
  // ── DayPlan ─────────────────────────────────
  Future<List<RecommendationItem>> getDayPlan() async {
    final res = await ApiClient.post(
      '/api/recommendations',
      body: {'plan_type': 'DayPlan'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load recommendations: ${res.body}');
    }

    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => RecommendationItem.fromJson(e)).toList();
  }

  // ── TripPlan ─────────────────────────────────
  Future<TripPlanResult> getTripPlan({required int tripDays}) async {
    final res = await ApiClient.post(
      '/api/recommendations',
      body: {'plan_type': 'TripPlan', 'trip_days': tripDays},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load trip plan: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return TripPlanResult.fromJson(data);
  }

  // ── Feedback ─────────────────────────────────
  Future<void> sendFeedback({
    required String landmarkName,
    required String eventType, // 'like' or 'dislike'
  }) async {
    final res = await ApiClient.post(
      '/api/recommendations/feedback',
      body: {'landmark_name': landmarkName, 'event_type': eventType},
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to send feedback: ${res.body}');
    }
  }
}
