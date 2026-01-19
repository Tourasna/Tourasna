import 'dart:convert';
import '../models/recommendation_item.dart';
import 'api_client.dart';

class RecommendationService {
  Future<List<RecommendationItem>> getRecommendations() async {
    final res = await ApiClient.get('/api/recommendations');

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => RecommendationItem.fromJson(e)).toList();
  }
}
