import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class ChatMockPage extends StatefulWidget {
  final AuthService authService;

  const ChatMockPage({super.key, required this.authService});

  @override
  State<ChatMockPage> createState() => _ChatMockPageState();
}

class _ChatMockPageState extends State<ChatMockPage> {
  final List<_ChatMessage> messages = [];
  final TextEditingController controller = TextEditingController();

  bool showIntro = true;
  String? _sessionId;

  static const String _baseUrl = 'http://10.0.2.2:4000';

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    final token = widget.authService.token;
    if (token == null) return;

    final res = await http.post(
      Uri.parse('$_baseUrl/chat/start'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      _sessionId = jsonDecode(res.body)['session_id'];
    }
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty || _sessionId == null) return;

    setState(() {
      messages.add(_ChatMessage(text, false));
      showIntro = false;
    });

    controller.clear();

    final token = widget.authService.token;
    if (token == null) return;

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/chat/message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'session_id': _sessionId, 'message': text}),
      );

      if (res.statusCode != 200) {
        throw Exception(res.body);
      }

      final reply = jsonDecode(res.body)['reply'];

      setState(() {
        messages.add(_ChatMessage(reply, true));
      });
    } catch (_) {
      setState(() {
        messages.add(_ChatMessage("Sorry, something went wrong.", true));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8C7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5E8C7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                if (showIntro) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        "assets/icons/ChatmockAvatar.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Chat now with Horus",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];

                      return Align(
                        alignment: msg.isBot
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (msg.isBot) ...[
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    "assets/icons/ChatmockAvatar.png",
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 260),
                              decoration: BoxDecoration(
                                color: msg.isBot
                                    ? Colors.amber.shade300
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                msg.text,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // INPUT BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: "Type...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: sendMessage,
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isBot;

  _ChatMessage(this.text, this.isBot);
}
