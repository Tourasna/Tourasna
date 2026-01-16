import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/recommendation_item.dart';
import '../services/auth_service.dart';

class RecommendationService {
  static const String _baseUrl = 'http://10.0.2.2:4000';

  final AuthService authService;

  RecommendationService(this.authService);

  Future<List<RecommendationItem>> getRecommendations() async {
    final token = await authService.getValidToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('$_baseUrl/recommendations'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load recommendations');
    }

    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => RecommendationItem.fromJson(e)).toList();
  }
}
