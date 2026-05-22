import 'dart:convert';
import '../models/recommendation_item.dart';
import 'api_client.dart';

class PlacesSearchService {
  Future<List<RecommendationItem>> search({
    required String query,
    required String city,
  }) async {
    if (query.trim().isEmpty) return [];

    final res = await ApiClient.get(
      '/api/landmarks/search?q=${Uri.encodeComponent(query)}&limit=20',
    );

    if (res.statusCode != 200) {
      throw Exception('Search failed');
    }

    final json = jsonDecode(res.body);
    final List data = json['data'];
    return data.map((e) => RecommendationItem.fromJson(e)).toList();
  }
}
