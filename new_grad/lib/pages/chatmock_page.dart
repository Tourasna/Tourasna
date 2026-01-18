import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chat_socket_service.dart';

class ChatMockPage extends StatefulWidget {
  final AuthService authService;

  const ChatMockPage({super.key, required this.authService});

  @override
  State<ChatMockPage> createState() => _ChatMockPageState();
}

class _ChatMockPageState extends State<ChatMockPage> {
  final List<_ChatMessage> messages = [];
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  late final ChatSocketService chatService;

  bool showIntro = true;
  int? _streamingIndex;

  @override
  void initState() {
    super.initState();

    chatService = ChatSocketService(widget.authService);

    chatService.connect(
      onConnected: () async {
        debugPrint("✅ Chat connected");

        final history = await chatService.fetchHistory();
        if (!mounted) return;

        if (history.isNotEmpty) {
          setState(() {
            messages.addAll(
              history.map(
                (m) => _ChatMessage(
                  m['content'] ?? '',
                  m['sender'] == 'assistant',
                ),
              ),
            );
            showIntro = false; // hide intro once we have messages
          });
          _scrollToBottom();
        }
      },
      onDisconnected: () {
        debugPrint("❌ Chat disconnected");
      },
      onStream: _handleStreamChunk,
      onStreamEnd: _handleStreamEnd,
    );
  }

  // ─────────────────────────────────────────────
  // STREAM HANDLING (UX)
  // ─────────────────────────────────────────────
  void _handleStreamChunk(String chunk) {
    if (!mounted) return;

    setState(() {
      showIntro = false;

      if (_streamingIndex == null) {
        messages.add(_ChatMessage(chunk, true));
        _streamingIndex = messages.length - 1;
      } else {
        final current = messages[_streamingIndex!];
        messages[_streamingIndex!] = _ChatMessage(current.text + chunk, true);
      }
    });

    _scrollToBottom();
  }

  void _handleStreamEnd() {
    _streamingIndex = null;
  }

  // ─────────────────────────────────────────────
  // SEND MESSAGE (UX)
  // ─────────────────────────────────────────────
  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(_ChatMessage(text, false));
      showIntro = false;
      _streamingIndex = null;
    });

    controller.clear();
    chatService.sendMessage(text);

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    chatService.disconnect();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // UI (from the UI mock)
  // ─────────────────────────────────────────────
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
                    controller: scrollController,
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

          // INPUT BAR (from the UI mock, UX: submit-to-send kept)
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
                            onSubmitted: (_) => sendMessage(),
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
                          onPressed: () {
                            // keep your UI behavior here if you want
                          },
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
