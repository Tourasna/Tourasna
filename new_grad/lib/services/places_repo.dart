import 'dart:convert';
import '../models/place.dart';
import '../models/recommendation_item.dart';
import '../services/api_client.dart';

class PlacesRepo {
  Future<Place?> getByMLLabel(String label) async {
    final res = await ApiClient.get('/api/places/by-ml-label/$label');

    if (res.statusCode == 404) return null;

    if (res.statusCode != 200) throw Exception(res.body);

    return Place.fromJson(jsonDecode(res.body));
  }

  Future<RecommendationItem?> searchRecommendationByName(String name) async {
    final encoded = Uri.encodeComponent(name);
    final res = await ApiClient.get(
      '/api/places-search/search?q=$encoded&limit=1',
    );

    if (res.statusCode != 200) return null;

    final List<dynamic> data = jsonDecode(res.body);
    if (data.isEmpty) return null;

    return RecommendationItem.fromJson(data[0]);
  }
}
