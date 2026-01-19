import 'dart:convert';
import '../services/api_client.dart';
import '../models/recommendation_item.dart';

class FavoritesService {
  Future<void> add(int itemId) async {
    final res = await ApiClient.post('/api/favorites/$itemId');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(res.body);
    }
  }

  Future<void> remove(int itemId) async {
    final res = await ApiClient.delete('/api/favorites/$itemId');

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  Future<List<RecommendationItem>> list() async {
    final res = await ApiClient.get('/api/favorites');

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => RecommendationItem.fromJson(e)).toList();
  }
}
