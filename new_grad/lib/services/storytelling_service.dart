import 'dart:convert';
import 'api_client.dart';
import '../models/place_story.dart';

class StorytellingService {
  // existing
  static Future<String> getStory(String placeId) async {
    final res = await ApiClient.get('/api/storytelling/$placeId');
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body)['story'] as String;
  }

  // new
  static Future<List<PlaceStory>> getAllPlaces() async {
    final res = await ApiClient.get('/api/storytelling/places');
    if (res.statusCode != 200) throw Exception(res.body);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => PlaceStory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
