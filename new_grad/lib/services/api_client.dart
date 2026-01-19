import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'dart:convert';

class ApiClient {
  static const String baseUrl = 'http://13.48.196.1';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService().getValidToken();

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String path) async {
    return http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
  }

  static Future<http.Response> post(String path, {Object? body}) async {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> put(String path, {Object? body}) async {
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> delete(String path) async {
    return http.delete(Uri.parse('$baseUrl$path'), headers: await _headers());
  }

  // Socket
  static String get socketBaseUrl => baseUrl;

  static Future<String?> getToken() async {
    return AuthService().getValidToken();
  }
}
