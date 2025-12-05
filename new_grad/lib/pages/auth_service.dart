import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<AuthResponse> supabaseSignUp(String email, String password) async {
  final response = await supabase.auth.signUp(
    email: email,
    password: password,
    emailRedirectTo: null,
  );
  return response;
}
