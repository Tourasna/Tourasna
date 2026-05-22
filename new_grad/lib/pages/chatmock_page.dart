import 'package:flutter/material.dart';
import '../services/chat_socket_service.dart';

class ChatMockPage extends StatefulWidget {
  const ChatMockPage({super.key});

  @override
  State<ChatMockPage> createState() => _ChatMockPageState();
}

class _ChatMockPageState extends State<ChatMockPage> {
  final Color bgColor = const Color(0xFFF2EADC);
  final Color darkColor = const Color(0xFF1A3C3C);
  final Color goldColor = const Color(0xFFC5A059);

  final List<_ChatMessage> messages = [];
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  late final ChatSocketService chatService;

  bool showIntro = true;
  int? _streamingIndex;

  @override
  void initState() {
    super.initState();

    chatService = ChatSocketService();

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
            showIntro = false;
          });
          _scrollToBottom();
        }
      },
      onDisconnected: () {
        if (mounted) debugPrint("❌ Chat disconnected");
      },
      onStream: _handleStreamChunk,
      onStreamEnd: _handleStreamEnd,
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── APP BAR ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(color: darkColor.withOpacity(0.05)),
                ),
              ),
              child: Row(
                children: [
                  // BACK
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: goldColor.withOpacity(0.2)),
                      ),
                      child: Icon(Icons.chevron_left, color: darkColor),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // AVATAR
                  Stack(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: goldColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/fahmy_chat.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: goldColor.withOpacity(0.2),
                              child: Icon(Icons.person, color: darkColor),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: bgColor, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 10),

                  // NAME + STATUS
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fahmy',
                          style: TextStyle(
                            fontFamily: 'Gambetta',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: darkColor,
                          ),
                        ),
                        Text(
                          'Online Guide',
                          style: TextStyle(
                            fontSize: 11,
                            color: darkColor.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // MORE
                  Icon(Icons.more_vert, color: darkColor.withOpacity(0.5)),
                ],
              ),
            ),

            // ── MESSAGES ─────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: messages.isEmpty && showIntro
                    ? 1
                    : messages.length + 1,
                itemBuilder: (context, index) {
                  // Date divider always first
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: darkColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'TODAY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: darkColor.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // Intro greeting if no messages yet
                  if (messages.isEmpty && showIntro) {
                    return _buildBotBubble(
                      'Greetings, traveler! I am Fahmy. Are you ready to discover the secrets of the ancient kings? What monument shall we explore today?',
                    );
                  }

                  final msg = messages[index - 1];
                  return msg.isBot
                      ? _buildBotBubble(msg.text)
                      : _buildUserBubble(msg.text);
                },
              ),
            ),

            // ── INPUT BAR ─────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: bgColor,
                boxShadow: [
                  BoxShadow(
                    color: darkColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // + BUTTON
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: goldColor.withOpacity(0.2)),
                    ),
                    child: Icon(
                      Icons.add,
                      color: darkColor.withOpacity(0.4),
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // TEXT FIELD
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: darkColor.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: darkColor.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: controller,
                        onSubmitted: (_) => sendMessage(),
                        style: TextStyle(
                          color: darkColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask Fahmy...',
                          hintStyle: TextStyle(
                            color: darkColor.withOpacity(0.35),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          suffixIcon: Icon(
                            Icons.sentiment_satisfied_alt_outlined,
                            color: darkColor.withOpacity(0.35),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // SEND BUTTON
                  GestureDetector(
                    onTap: sendMessage,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: darkColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: darkColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AVATAR
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: goldColor.withOpacity(0.3)),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/chatmocka.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: goldColor.withOpacity(0.2),
                  child: Icon(Icons.person, size: 16, color: darkColor),
                ),
              ),
            ),
          ),

          // BUBBLE
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: goldColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: darkColor.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: darkColor, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: darkColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: darkColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isBot;
  _ChatMessage(this.text, this.isBot);
}
