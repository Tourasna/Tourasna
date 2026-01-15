import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/place.dart';
import '../services/auth_service.dart';

class RecommendationService {
  static const String _baseUrl = 'http://10.0.2.2:4000';

  final AuthService authService;

  RecommendationService(this.authService);

  Future<List<Place>> getProfileRecommendations() async {
    final token = authService.token;

    if (token == null) {
      // Not logged in → no personalized recommendations
      return [];
    }

    final res = await http.get(
      Uri.parse('$_baseUrl/recommendations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load recommendations: ${res.body}');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Place.fromJson(e)).toList();
  }
}
