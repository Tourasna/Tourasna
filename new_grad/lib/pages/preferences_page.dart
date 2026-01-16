import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => PreferencesPageState();
}

class PreferencesPageState extends State<PreferencesPage> {
  static const String _baseUrl = 'http://192.168.1.9:4000';

  final List<String> _preferences = [
    "Fun & Games",
    "Water & Amusement Parks",
    "Outdoor Activities",
    "Concerts & Shows",
    "Zoos & Aquariums",
    "Shopping",
    "Nature & Parks",
    "Sights & Landmarks",
    "Museums",
    "Traveler Resources",
  ];

  final List<String> _preferenceImages = [
    "assets/images/FunNGames.jpg",
    "assets/images/waternamusementparks.jpg",
    "assets/images/outdooractivities.jpg",
    "assets/images/concertsnshows.jpg",
    "assets/images/zoonaquirium.jpg",
    "assets/images/shopping.jpg",
    "assets/images/naturenparks.jpg",
    "assets/images/sitesnlandmarks.jpg",
    "assets/images/musuems.jpg",
    "assets/images/travellerresources.jpg",
  ];

  final Set<String> _selectedPreferences = {};

  // ─────────────────────────────────────────────
  // DATE NORMALIZER
  // ─────────────────────────────────────────────
  String _normalizeDate(String input) {
    final parts = input.split('/');
    return "${parts[2]}-${parts[1]}-${parts[0]}"; // YYYY-MM-DD
  }

  void _clearSelections() {
    setState(() => _selectedPreferences.clear());
  }

  void _skipPage() {
    Navigator.pushReplacementNamed(context, '/homescreen');
  }

  void _toggleSelection(String preference) {
    setState(() {
      if (_selectedPreferences.contains(preference)) {
        _selectedPreferences.remove(preference);
      } else {
        _selectedPreferences.add(preference);
      }
    });
  }

  void _showInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Long press for more information")),
    );
  }

  // ─────────────────────────────────────────────
  // COMPLETE ONBOARDING (ONE CALL)
  // ─────────────────────────────────────────────
  Future<void> _savePreferencesAndFinish() async {
    final token = AuthService().token;

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Not authenticated")));
      return;
    }

    if (_selectedPreferences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one preference")),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final firstName = prefs.getString('onboarding_firstName');
      final lastName = prefs.getString('onboarding_lastName');
      final username = prefs.getString('onboarding_username');
      final gender = prefs.getString('onboarding_gender');
      final nationality = prefs.getString('onboarding_nationality');
      final dobRaw = prefs.getString('onboarding_dob');

      if (firstName == null ||
          lastName == null ||
          username == null ||
          gender == null ||
          nationality == null ||
          dobRaw == null) {
        throw Exception('Missing cached signup data');
      }

      final body = {
        "firstName": firstName,
        "lastName": lastName,
        "username": username,
        "gender": gender,
        "nationality": nationality,
        "dateOfBirth": _normalizeDate(dobRaw),
        "preferences": _selectedPreferences.toList(),
      };

      final res = await http.put(
        Uri.parse('$_baseUrl/profiles/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode != 200) {
        throw Exception(res.body);
      }

      // 🧹 CLEAR CACHED SIGNUP DATA
      await prefs.remove('onboarding_firstName');
      await prefs.remove('onboarding_lastName');
      await prefs.remove('onboarding_username');
      await prefs.remove('onboarding_gender');
      await prefs.remove('onboarding_nationality');
      await prefs.remove('onboarding_dob');

      Navigator.pushReplacementNamed(context, '/homescreen');
    } catch (e) {
      debugPrint("❌ Onboarding failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to complete onboarding")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const pageBackgroundColor = Color(0xFFF5E5D1);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: pageBackgroundColor,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
          actions: [
            TextButton(
              onPressed: _clearSelections,
              child: Text(
                "Clear",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text("/", style: TextStyle(color: Colors.grey[700], fontSize: 16)),
            TextButton(
              onPressed: _skipPage,
              child: Text(
                "Skip",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "Choose your own tourism\nPreferences :",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Note: Long press for more information",
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  GridView.builder(
                    itemCount: _preferences.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16.0,
                          mainAxisSpacing: 16.0,
                          childAspectRatio: 0.85,
                        ),
                    itemBuilder: (context, index) {
                      final preference = _preferences[index];
                      final imgPath = _preferenceImages[index];
                      final isSelected = _selectedPreferences.contains(
                        preference,
                      );

                      return PreferenceTile(
                        title: preference,
                        imagePath: imgPath,
                        isSelected: isSelected,
                        onTap: () => _toggleSelection(preference),
                        onLongPress: _showInfo,
                      );
                    },
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                color: pageBackgroundColor,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    color: Colors.black,
                  ),
                  child: InkWell(
                    onTap: _savePreferencesAndFinish,
                    borderRadius: BorderRadius.circular(10.0),
                    child: const Center(
                      child: Text(
                        "Confirm",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PreferenceTile extends StatelessWidget {
  final String title;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PreferenceTile({
    super.key,
    required this.title,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: AssetImage(imagePath),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
