import 'dart:convert';
import 'api_client.dart';

class StorytellingService {
  static Future<String> getStory(String placeId) async {
    final res = await ApiClient.get('/api/storytelling/$placeId');

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body)['story'] as String;
  }
}
