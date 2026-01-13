import 'package:supabase_flutter/supabase_flutter.dart';

class RecommendationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<int>> getRecommendations() async {
    final response = await _client.functions.invoke('get_recommendations');

    // In the new SDK, errors throw automatically
    final data = response.data as Map<String, dynamic>;

    final List<dynamic> recs = data['recommendations'];
    return recs.map((e) => e as int).toList();
  }
}
