import 'dart:convert';
import '../models/place_search_item.dart';
import 'api_client.dart';

class PlacesSearchService {
  Future<List<PlaceSearchItem>> search({
    required String query,
    required String city,
  }) async {
    final res = await ApiClient.get(
      '/api/places-search/search?q=$query&city=$city',
    );

    if (res.statusCode != 200) {
      throw Exception('Search failed');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => PlaceSearchItem.fromJson(e)).toList();
  }
}
