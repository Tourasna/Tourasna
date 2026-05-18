import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

// ─── Brand Colors (matching HTML design) ────────────────────────────────────
const _teal = Color(0xFF1A3C3C);
const _gold = Color(0xFFC5A059);
const _cream = Color(0xFFF2EADC);
const _emerald = Color(0xFF0D5B5F);
const _bronze = Color(0xFF8B6F47);

// ─── Egyptian hieroglyph glyphs per category ────────────────────────────────
const _glyphs = [
  '𓉒',
  '𓉒',
  '𓉒',
  '𓇗',
  '𓉒',
  '𓉒',
  '𓇗',
  '𓇗',
  '𓆙',
  '𓆙',
  '𓆙',
  '𓇗',
  '𓇗',
  '𓇗',
  '𓇗',
  '𓃠',
  '𓃠',
  '𓆙',
  '𓉒',
  '𓃠',
  '𓃠',
  '𓃠',
  '𓃠',
  '𓃠',
  '𓃠',
  '𓃠',
  '𓇗',
];

// ─── Accent colors per card (matching HTML palette) ──────────────────────────
const _cardColors = [
  Color(0xFF0D5B5F),
  Color(0xFF1A3C6C),
  Color(0xFF1F4F6F),
  Color(0xFF6B4E71),
  Color(0xFFC5A059),
  Color(0xFFD4A5A0),
  Color(0xFF7A5C6C),
  Color(0xFFE8A87C),
  Color(0xFF2A8FA3),
  Color(0xFF3A9BB8),
  Color(0xFFE8A87C),
  Color(0xFFA67C52),
  Color(0xFF5A9B7A),
  Color(0xFF4A7C7E),
  Color(0xFF2A8FA3),
  Color(0xFFC5A059),
  Color(0xFF8B6F47),
  Color(0xFFD4AF37),
  Color(0xFF8B6F47),
  Color(0xFF8B6F47),
  Color(0xFFE8A87C),
  Color(0xFFE8A87C),
  Color(0xFF4A3F5C),
  Color(0xFFE8A87C),
  Color(0xFFA67C52),
  Color(0xFFC5A059),
  Color(0xFF8B6F47),
];

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => PreferencesPageState();
}

class PreferencesPageState extends State<PreferencesPage>
    with TickerProviderStateMixin {
  final List<String> _preferences = [
    "Museum",
    "Pharaonic Site",
    "Islamic Monument",
    "Coptic Site",
    "Ancient Monument",
    "Landmark",
    "Art Gallery",
    "Cultural Center",
    "Nile Cruise",
    "Nile View Restaurant",
    "Rooftop Restaurant",
    "Traditional Restaurant",
    "Park / Garden",
    "Nature Reserve",
    "Zoo / Aquarium",
    "Shopping Mall",
    "Bazaar / Souq",
    "Gold & Jewelry Market",
    "Antiques",
    "Souvenir Shop",
    "Activity",
    "Day Trip Site",
    "Escape Room",
    "Sport & Recreation",
    "Horse Riding",
    "Theme Park",
    "Food Tour",
  ];

  final List<String> _subtitles = [
    "Knowledge",
    "Regal",
    "Grandeur",
    "Sacred",
    "Eternal",
    "Iconic",
    "Vision",
    "Heritage",
    "Serenity",
    "Breeze",
    "Starlit",
    "Authentic",
    "Tranquil",
    "Wild",
    "Wildlife",
    "Modern",
    "Market",
    "Divine",
    "Relics",
    "Memories",
    "Adventure",
    "Explore",
    "Mystery",
    "Energy",
    "Noble",
    "Joy",
    "Flavors",
  ];

  final List<String> _preferenceImages = [
    "assets/images/preferences/Museum.png",
    "assets/images/preferences/Pharaonic_Site.jpeg",
    "assets/images/preferences/Islamic_Monument.png",
    "assets/images/preferences/Coptic_Site.png",
    "assets/images/preferences/Ancient_Monument.png",
    "assets/images/preferences/Landmark.png",
    "assets/images/preferences/Art_Gallery.png",
    "assets/images/preferences/Cultural_Center.png",
    "assets/images/preferences/Nile_Cruise-2.png",
    "assets/images/preferences/Nile_View_Restaurant.png",
    "assets/images/preferences/Rooftop_Restaurant.jpeg",
    "assets/images/preferences/Traditional_Restaurant.png",
    "assets/images/preferences/Park_Garden.jpeg",
    "assets/images/preferences/Nature_Reserve.png",
    "assets/images/preferences/Zoo_Aquarium.png",
    "assets/images/preferences/Shopping_Mall.png",
    "assets/images/preferences/Bazaar_Souq.png",
    "assets/images/preferences/Gold_Jewelry_Market.png",
    "assets/images/preferences/Antiques.png",
    "assets/images/preferences/Souvenir_Shop.png",
    "assets/images/preferences/Activity.png",
    "assets/images/preferences/Day_Trip_Site.png",
    "assets/images/preferences/Escape_Room.png",
    "assets/images/preferences/Sport_Recreation-2.png",
    "assets/images/preferences/Horse_Riding.png",
    "assets/images/preferences/Theme_Park.png",
    "assets/images/preferences/Food_Tour.png",
  ];

  final Set<String> _selectedPreferences = {};

  // ─── Animation controllers for each card ──────────────────────────────────
  // Controllers use 0.0–1.0; Tween maps to 1.0–1.03 for scale.
  List<AnimationController> _scaleControllers = [];
  List<Animation<double>> _scaleAnims = [];

  @override
  void initState() {
    super.initState();
    _scaleControllers = List.generate(
      _preferences.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _scaleAnims = _scaleControllers.map((c) {
      return Tween<double>(
        begin: 1.0,
        end: 1.03,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _scaleControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // DATE NORMALIZER
  // ─────────────────────────────────────────────
  String _normalizeDate(String input) {
    final parts = input.split('/');
    return "${parts[2]}-${parts[1]}-${parts[0]}";
  }

  void _clearSelections() {
    setState(() => _selectedPreferences.clear());
    for (final c in _scaleControllers) {
      c.reverse();
    }
  }

  void _skipPage() {
    Navigator.pushReplacementNamed(context, '/homescreen');
  }

  void _toggleSelection(String preference, int index) {
    setState(() {
      if (_selectedPreferences.contains(preference)) {
        _selectedPreferences.remove(preference);
        _scaleControllers[index].reverse();
      } else {
        _selectedPreferences.add(preference);
        _scaleControllers[index].forward();
      }
    });
    HapticFeedback.lightImpact();
  }

  void _showInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Long press for more information"),
        backgroundColor: _teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // COMPLETE ONBOARDING
  // ─────────────────────────────────────────────
  Future<void> _savePreferencesAndFinish() async {
    final token = await AuthService().getValidToken();

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Not authenticated"),
          backgroundColor: _teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (_selectedPreferences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Select at least one preference"),
          backgroundColor: _gold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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

      final res = await ApiClient.put('/api/profiles/complete', body: body);

      if (res.statusCode != 200) {
        throw Exception(res.body);
      }

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
        SnackBar(
          content: const Text("Failed to complete onboarding"),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _cream,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _cream,
        body: Stack(
          children: [
            // ── Subtle papyrus-style dot texture overlay ──────────────────
            Positioned.fill(child: CustomPaint(painter: _PapyrusPainter())),

            Column(
              children: [
                // ── Header ────────────────────────────────────────────────
                _buildHeader(context),

                // ── Scrollable grid ───────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    child: GridView.builder(
                      itemCount: _preferences.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.85,
                          ),
                      itemBuilder: (context, index) {
                        final preference = _preferences[index];
                        final isSelected = _selectedPreferences.contains(
                          preference,
                        );
                        return AnimatedBuilder(
                          animation: _scaleAnims[index],
                          builder: (context, child) => Transform.scale(
                            scale: _scaleAnims[index].value,
                            child: child,
                          ),
                          child: _PreferenceCard(
                            title: preference,
                            subtitle: _subtitles[index],
                            imagePath: _preferenceImages[index],
                            glyph: _glyphs[index % _glyphs.length],
                            accentColor:
                                _cardColors[index % _cardColors.length],
                            isSelected: isSelected,
                            onTap: () => _toggleSelection(preference, index),
                            onLongPress: _showInfo,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // ── Sticky footer ─────────────────────────────────────────────
            Positioned(bottom: 0, left: 0, right: 0, child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  // ── Header widget ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x4DC5A059), width: 2)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x14C5A059), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back + Clear/Skip row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: _teal,
                        size: 20,
                      ),
                    ),
                  ),
                  // Clear / Skip
                  Row(
                    children: [
                      TextButton(
                        onPressed: _clearSelections,
                        child: Text(
                          "Clear",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        "/",
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                      TextButton(
                        onPressed: _skipPage,
                        child: Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Title block
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  const Text(
                    "Select Your Interests",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _teal,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Choose categories that match your travel style",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _gold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Gold divider line
                  Center(
                    child: Container(
                      width: 40,
                      height: 2,
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(1),
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

  // ── Footer widget ──────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final count = _selectedPreferences.length;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_cream, _cream, _cream.withOpacity(0)],
          stops: const [0, 0.7, 1],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      child: GestureDetector(
        onTap: _savePreferencesAndFinish,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: _teal,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: _teal.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                count == 0 ? "EMBARK" : "EMBARK  ($count)",
                style: const TextStyle(
                  color: _cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, color: _cream, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Preference Card ────────────────────────────────────────────────────────
class _PreferenceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final String glyph;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PreferenceCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.glyph,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_PreferenceCard> createState() => _PreferenceCardState();
}

class _PreferenceCardState extends State<_PreferenceCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _imgController;
  late final Animation<double> _imgScale;

  @override
  void initState() {
    super.initState();
    _imgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _imgScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _imgController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _imgController.dispose();
    super.dispose();
  }

  void _onHoverStart() {
    setState(() => _hovered = true);
    _imgController.forward();
  }

  void _onHoverEnd() {
    setState(() => _hovered = false);
    _imgController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool selected = widget.isSelected;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _onHoverStart(),
      onTapUp: (_) => _onHoverEnd(),
      onTapCancel: _onHoverEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? _teal : Colors.white.withOpacity(0.45),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? _gold
                : (_hovered ? _gold.withOpacity(0.5) : const Color(0x0D1A3C3C)),
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _teal.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  const BoxShadow(
                    color: Color(0x4D1A3C3C),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Image area — flex to fill card like original code ──────
            Expanded(
              flex: 4,
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image with zoom on hover
                    AnimatedBuilder(
                      animation: _imgScale,
                      builder: (_, child) =>
                          Transform.scale(scale: _imgScale.value, child: child),
                      child: Image.asset(
                        widget.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: widget.accentColor,
                          child: Center(
                            child: Text(
                              widget.glyph,
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Gradient overlay
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: selected
                              ? [_teal.withOpacity(0.6), _gold.withOpacity(0.4)]
                              : [
                                  _teal.withOpacity(_hovered ? 0.15 : 0.3),
                                  _gold.withOpacity(_hovered ? 0.1 : 0.2),
                                ],
                        ),
                      ),
                    ),

                    // Egyptian glyph watermark
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Text(
                        widget.glyph,
                        style: TextStyle(
                          fontSize: 18,
                          color: _cream.withOpacity(0.2),
                        ),
                      ),
                    ),

                    // Check badge (selected state)
                    if (selected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: _gold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Text content ─────────────────────────────────────────────
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: selected ? _cream : _teal,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: selected ? _gold : _gold.withOpacity(0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Gold bottom accent line ──────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _gold.withOpacity(_hovered || selected ? 0.5 : 0),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Papyrus dot texture painter ────────────────────────────────────────────
class _PapyrusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    const spacing = 8.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PapyrusPainter old) => false;
}
