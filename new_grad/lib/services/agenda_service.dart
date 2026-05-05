import 'dart:convert';
import '../models/agenda_item.dart';
import '../services/api_client.dart'; // ✅ FIXED: 3 levels up
import 'auth_service.dart';

class AgendaService {
  Future<List<AgendaItem>> fetch({
    required DateTime from,
    required DateTime to,
  }) async {
    final token = await AuthService().getValidToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await ApiClient.get(
      '/api/agenda'
      '?from=${_date(from)}'
      '&to=${_date(to)}',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load agenda: ${response.body}');
    }

    final List data = json.decode(response.body);
    return data.map((e) => AgendaItem.fromJson(e)).toList();
  }

  Future<int> create(AgendaItem item) async {
    final token = await AuthService().getValidToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await ApiClient.post(
      '/api/agenda',
      body: item.toCreateJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create agenda: ${response.body}');
    }

    return json.decode(response.body)['id'];
  }

  Future<void> update(AgendaItem item) async {
    final response = await ApiClient.put(
      '/api/agenda/${item.id}',
      body: item.toCreateJson(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update agenda: ${response.body}');
    }
  }

  Future<void> delete(int id) async {
    final response = await ApiClient.delete('/api/agenda/$id');

    if (response.statusCode != 200) {
      throw Exception('Failed to delete agenda: ${response.body}');
    }
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
