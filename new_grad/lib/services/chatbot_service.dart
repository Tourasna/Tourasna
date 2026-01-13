import 'package:supabase_flutter/supabase_flutter.dart';

class ChatbotResult {
  final String message;
  final String? sessionId;

  ChatbotResult({required this.message, this.sessionId});
}

class ChatbotService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _sessionId;

  Future<ChatbotResult> sendMessage(String message) async {
    final response = await _supabase.functions.invoke(
      'chatbot',
      body: {
        'message': message,
        'session_id': _sessionId, // null on first message
      },
    );

    final data = response.data;

    if (data == null || data['message'] == null) {
      throw Exception('Invalid chatbot response: $data');
    }

    // Persist session id after first response
    _sessionId ??= data['session_id'] as String?;

    return ChatbotResult(
      message: data['message'] as String,
      sessionId: _sessionId,
    );
  }
}
