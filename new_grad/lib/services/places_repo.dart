import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place.dart';
import '../services/auth_service.dart';

class PlacesRepo {
  static const String _baseUrl = 'http://192.168.1.9:4000';

  final AuthService authService;

  PlacesRepo(this.authService);

  Future<Place?> getByMLLabel(String label) async {
    final token = authService.token;

    if (token == null) {
      throw Exception('User is not authenticated');
    }

    final res = await http.get(
      Uri.parse('$_baseUrl/places/by-ml-label/$label'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 404) {
      return null;
    }

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch place: ${res.body}');
    }

    final data = jsonDecode(res.body);
    return Place.fromJson(data);
  }
}
