import 'dart:convert';
import '../models/recommendation_item.dart';
import 'api_client.dart';

class LandmarksService {
  static Future<LandmarksSearchResult> search({
    String q = '',
    String category = '',
    int page = 1,
    int limit = 20,
    String sortMode = 'POPULAR',
  }) async {
    final params = [
      if (q.isNotEmpty) 'q=${Uri.encodeComponent(q)}',
      if (category.isNotEmpty) 'category=${Uri.encodeComponent(category)}',
      'page=$page',
      'limit=$limit',
      'sort=$sortMode',
    ].join('&');

    final response = await ApiClient.get('/api/landmarks/search?$params');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return LandmarksSearchResult(
        data: (json['data'] as List)
            .map((e) => RecommendationItem.fromJson(e))
            .toList(),
        total: json['total'] ?? 0,
      );
    }

    throw Exception('Failed to load landmarks: ${response.statusCode}');
  }

  static Future<List<String>> getCategories() async {
    final response = await ApiClient.get('/api/landmarks/categories');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return List<String>.from(json['categories']);
    }

    throw Exception('Failed to load categories: ${response.statusCode}');
  }
}

class LandmarksSearchResult {
  final List<RecommendationItem> data;
  final int total;

  LandmarksSearchResult({required this.data, required this.total});
}
