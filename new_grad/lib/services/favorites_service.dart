import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import '../models/recommendation_item.dart';

class FavoritesService {
  static const _baseUrl = 'http://10.0.2.2:4000';
  final AuthService authService;

  FavoritesService(this.authService);

  Future<void> add(int itemId) async {
    final token = await authService.getValidToken();
    if (token == null) return;

    await http.post(
      Uri.parse('$_baseUrl/favorites/$itemId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> remove(int itemId) async {
    final token = await authService.getValidToken();
    if (token == null) return;

    await http.delete(
      Uri.parse('$_baseUrl/favorites/$itemId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<RecommendationItem>> list() async {
    final token = await authService.getValidToken();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('$_baseUrl/favorites'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final List data = jsonDecode(res.body);
    return data.map((e) => RecommendationItem.fromJson(e)).toList();
  }
}
