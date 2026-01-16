import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class ChatSocketService {
  static const String _baseUrl = 'http://10.0.2.2:4000';

  final AuthService authService;
  IO.Socket? _socket;

  ChatSocketService(this.authService);

  // ─────────────────────────────────────────────
  // FETCH CHAT HISTORY (SAFE NO-OP)
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    final token = authService.token;
    if (token == null) return [];

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chat/history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      if (data is! List) return [];

      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // CONNECT SOCKET
  // ─────────────────────────────────────────────
  void connect({
    required VoidCallback onConnected,
    required VoidCallback onDisconnected,
    required void Function(String chunk) onStream,
    required VoidCallback onStreamEnd,
  }) {
    final token = authService.token;
    if (token == null) {
      throw Exception('No auth token');
    }

    _socket = IO.io(
      _baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) => onConnected());
    _socket!.onDisconnect((_) => onDisconnected());

    _socket!.on('stream', (data) {
      if (data is String) onStream(data);
    });

    _socket!.on('end', (_) {
      onStreamEnd();
    });

    _socket!.onError((err) {
      debugPrint('❌ Socket error: $err');
    });
  }

  // ─────────────────────────────────────────────
  // SEND MESSAGE
  // ─────────────────────────────────────────────
  void sendMessage(String message) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('message', {'message': message});
  }

  // ─────────────────────────────────────────────
  // DISCONNECT
  // ─────────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
