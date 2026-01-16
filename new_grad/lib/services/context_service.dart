import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ContextService {
  static const String _baseUrl = 'http://10.0.2.2:4000';
  final AuthService authService;

  ContextService(this.authService);

  Future<void> setContext({
    required String budget,
    required String travelType,
  }) async {
    final token = await authService.getValidToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final res = await http.put(
      Uri.parse('$_baseUrl/context'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'budget': budget, 'travel_type': travelType}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to set context');
    }
  }
}
