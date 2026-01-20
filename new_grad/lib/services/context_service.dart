import '../services/api_client.dart';

class ContextService {
  Future<void> setContext({
    required String budget,
    required String travelType,
  }) async {
    final res = await ApiClient.put(
      '/api/context',
      body: {'budget': budget, 'travel_type': travelType},
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }
}
