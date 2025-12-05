import 'package:flutter/material.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pageBackgroundColor = Color(0xFFF5E5D1);

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: pageBackgroundColor,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // As requested, ignoring the top-right icons
      ),
      body: SafeArea( // Using SafeArea to avoid notches and status bar
        child: Stack( // Using Stack to position the bird image
          clipBehavior: Clip.none, // Allows painting outside bounds if necessary (good practice for edge items)
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // Ensure content is centered horizontally
                children: [
                  const SizedBox(height: 20),
                  // 1. OVAL CONTAINER FOR MIDDLE LOGO
                  Container(
                    width: 110, // Slightly wider for oval shape
                    height: 100, // Keep original height
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50), // Adjust for oval shape
                      border: Border.all(color: Colors.grey.shade400),
                      image: const DecorationImage(
                        image: AssetImage("assets/icons/Secondary_chatbot_logo.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Good Evening, User_Name",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    "Can I help you with anything?",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Choose a Prompt Below or Write Your\nOwn to Start Chatting with Chatbot",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Center the row itself
                    children: [
                      Expanded(child: _buildSuggestedMessage("Suggested Message")),
                      const SizedBox(width: 15),
                      Expanded(child: _buildSuggestedMessage("Suggested Message")),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextButton.icon(
                    onPressed: () {
                      // Handle refresh prompts
                    },
                    icon: const Icon(Icons.refresh, color: Colors.black54),
                    label: const Text(
                      "Refresh prompts",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Placeholder to ensure scroll area extends below the bird
                  const SizedBox(height: 200), // Adjusted height to make space for the bird and prevent scroll issues
                ],
              ),
            ),
            Positioned(
              right: 0, // Align to the right edge
              bottom: -40, // FIXED: Set to 0 so it sits on top of the input bar and isn't covered
              child: Image(
                image: const AssetImage("assets/images/Chatbot_Avatar.png"),
                width: 200, // Set the exact width as in the original
                height: 200, // Set the exact height as in the original
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 12.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12.0,
        ),
        color: pageBackgroundColor,
        child: Container(
          decoration: BoxDecoration(
            color: pageBackgroundColor,
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(color: Colors.black),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "How Can Horus Help you ?",
                    contentPadding: EdgeInsets.only(left: 20.0),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.black54),
                onPressed: () {
                  // Handle attach file
                },
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.black54),
                onPressed: () {
                  // Handle camera
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.black),
                onPressed: () {
                  // Handle send message
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedMessage(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}