import 'dart:convert';
import '../models/place.dart';
import '../services/api_client.dart';

class PlacesRepo {
  Future<Place?> getByMLLabel(String label) async {
    final res = await ApiClient.get('/api/places/by-ml-label/$label');

    if (res.statusCode == 404) {
      return null;
    }

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return Place.fromJson(jsonDecode(res.body));
  }
}
