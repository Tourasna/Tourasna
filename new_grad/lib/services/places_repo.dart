import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class PlacesRepo {
  final SupabaseClient _db = Supabase.instance.client;

  Future<Place?> getByMLLabel(String label) async {
    final res = await _db
        .from('places')
        .select()
        .eq('ml_label', label)
        .limit(1)
        .maybeSingle();

    print("SUPABASE RESULT FOR label=[$label]: $res");

    if (res == null) return null;

    return Place.fromJson(res);
  }
}
