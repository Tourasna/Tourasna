import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => PreferencesPageState();
}

class PreferencesPageState extends State<PreferencesPage> {
  final List<String> _preferences = [
    "Cultural",
    "Adventure",
    "Heritage",
    "Nature",
    "Romantic",
    "Honeymoon Escapes",
    "Instagrammable Spots",
    "Wellness",
    "Local Experiences",
    "Open-Door Experience Categories",
    "Weekend & Short Getaways",
    "Urban & Creative Culture",
    "Relaxation",
    "Food & Local Flavors",
    "Outdoor Experience Categories",
    "Eco & Green Escapes",
    "Rural & Open-Air Villages",
    "Nile & Water-Based Experiences",
    "Active & Outdoor Sports",
    "Offbeat & Remote Escapes",
  ];

  final Set<String> _selectedPreferences = {};

  void _clearSelections() {
    setState(() {
      _selectedPreferences.clear();
    });
  }

  void _skipPage() {
    debugPrint("Skip button pressed");
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
      const SnackBar(
        content: Text("Note: Long press for more information about the preferences"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageBackgroundColor = Color(0xFFF5E5D1);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: pageBackgroundColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
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
            Text(
              "/",
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
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
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Note: Long press for more information about the preferences",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    itemCount: _preferences.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      final preference = _preferences[index];
                      final isSelected = _selectedPreferences.contains(preference);
                      return PreferenceTile(
                        title: preference,
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
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        debugPrint("Selected: $_selectedPreferences");
                      },
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
            ),
          ],
        ),
      ),
    );
  }
}

class PreferenceTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PreferenceTile({
    super.key,
    required this.title,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


