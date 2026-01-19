import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

import 'api_client.dart';

class ChatSocketService {
  IO.Socket? _socket;

  // ─────────────────────────────────────────────
  // FETCH CHAT HISTORY
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    try {
      final res = await ApiClient.get('/api/chat/history');

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
  Future<void> connect({
    required VoidCallback onConnected,
    required VoidCallback onDisconnected,
    required void Function(String chunk) onStream,
    required VoidCallback onStreamEnd,
  }) async {
    final token = await ApiClient.getToken();
    if (token == null) {
      throw Exception('No auth token');
    }

    _socket = IO.io(
      ApiClient.socketBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) => onConnected());
    _socket!.onDisconnect((_) {
      _socket = null;
      onDisconnected();
    });

    _socket!.on('stream', (data) {
      if (data is String) onStream(data);
    });

    _socket!.on('end', (_) => onStreamEnd());

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
