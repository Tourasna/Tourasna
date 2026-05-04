import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import 'viewer_page.dart';
import '../services/google_tts_service.dart';
import '../services/api_keys.dart';
import '../services/storytelling_service.dart';

class LandmarkDetailsPage extends StatefulWidget {
  final Place place;

  const LandmarkDetailsPage({super.key, required this.place});

  @override
  State<LandmarkDetailsPage> createState() => _LandmarkDetailsPageState();
}

class _LandmarkDetailsPageState extends State<LandmarkDetailsPage>
    with WidgetsBindingObserver {
  late final GoogleTTSService _tts;

  bool _storyLoading = false;
  bool _isPlaying = false;
  bool _isPaused = false;

  String? _cachedStory;

  String _preferredGender = 'male';
  String _detectedLanguage = 'en-US';

  static const String _voicePrefKey = 'tts_preferred_gender';

  final Color bgColor = const Color(0xFFF2EADC);
  final Color darkColor = const Color(0xFF1A3C3C);
  final Color goldColor = const Color(0xFFC5A059);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts = GoogleTTSService(apiKey: ApiKeys.googleMapsApiKey);
    _loadVoicePreference();
  }

  Future<void> _loadVoicePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_voicePrefKey);

    if (saved != null && mounted) {
      setState(() => _preferredGender = saved);
    }
  }

  Future<void> _saveVoicePreference(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voicePrefKey, gender);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
    _tts.shutdown();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _tts.stop();

      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
        });
      }
    }
  }

  Future<void> _startStoryFlow() async {
    if (_storyLoading) return;

    if (_isPlaying && !_isPaused) {
      await _tts.pause();
      setState(() => _isPaused = true);
      return;
    }

    if (_isPlaying && _isPaused) {
      await _tts.resume();
      setState(() => _isPaused = false);
      return;
    }

    try {
      setState(() => _storyLoading = true);

      final storyText = _cachedStory ??= await StorytellingService.getStory(
        widget.place.id,
      );

      _detectedLanguage = _tts.detectLanguage(storyText);

      _tts.setVoiceForText(storyText, preferredGender: _preferredGender);

      if (!mounted) return;

      setState(() {
        _storyLoading = false;
        _isPlaying = true;
        _isPaused = false;
      });

      await _tts.speakStory(storyText);

      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
        });
      }
    } catch (e) {
      _showError('Story error: $e');
    } finally {
      if (mounted) {
        setState(() => _storyLoading = false);
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showVoiceSelector() {
    _tts.stop();

    setState(() {
      _isPlaying = false;
      _isPaused = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Choose Narrator",
                style: TextStyle(
                  color: darkColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Charon"),
                      selected: _preferredGender == 'male',
                      selectedColor: goldColor,
                      onSelected: (_) {
                        _preferredGender = 'male';
                        _saveVoicePreference('male');
                        Navigator.pop(context);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Kore"),
                      selected: _preferredGender == 'female',
                      selectedColor: goldColor,
                      onSelected: (_) {
                        _preferredGender = 'female';
                        _saveVoicePreference('female');
                        Navigator.pop(context);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.75),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldColor.withOpacity(.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: goldColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: darkColor.withOpacity(.8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool dark = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: dark ? goldColor : goldColor),
        label: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: dark ? Colors.white : darkColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: dark ? darkColor : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: dark ? Colors.transparent : goldColor.withOpacity(.2),
            ),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final description = widget.place.description ?? "No description available.";

    IconData storyIcon;
    String storyText;

    if (_storyLoading) {
      storyIcon = Icons.hourglass_top;
      storyText = "Loading Story";
    } else if (_isPlaying && !_isPaused) {
      storyIcon = Icons.pause;
      storyText = "Pause Story";
    } else if (_isPlaying && _isPaused) {
      storyIcon = Icons.play_arrow;
      storyText = "Resume Story";
    } else {
      storyIcon = Icons.volume_up;
      storyText = "Hear Monument Story";
    }

    return WillPopScope(
      onWillPop: () async {
        await _tts.stop();
        return true;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  /// HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () {
                            _tts.stop();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(Icons.chevron_left, color: darkColor),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "MONUMENT DETAILS",
                          style: TextStyle(
                            color: darkColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: _showVoiceSelector,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.record_voice_over,
                              color: darkColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// BODY
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// IMAGE
                          Container(
                            height: 260,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              image: DecorationImage(
                                image: NetworkImage(widget.place.imageUrl),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 18,
                                  color: Colors.black.withOpacity(.12),
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(.35),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 15,
                                          color: Colors.amber,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "4.9",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          Text(
                            "ANCIENT WONDERS",
                            style: TextStyle(
                              color: goldColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            widget.place.name,
                            style: TextStyle(
                              color: darkColor,
                              fontSize: 31,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _infoChip(Icons.location_on, "Giza Plateau"),
                              _infoChip(Icons.access_time, "08:00 - 17:00"),
                              _infoChip(Icons.confirmation_num, "200 EGP"),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Text(
                            description,
                            style: TextStyle(
                              color: darkColor.withOpacity(.8),
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 24),

                          _mainButton(
                            icon: storyIcon,
                            text: storyText,
                            onTap: _startStoryFlow,
                            dark: true,
                          ),

                          const SizedBox(height: 12),

                          _mainButton(
                            icon: Icons.view_in_ar,
                            text: "View 3D Model",
                            dark: false,
                            onTap: () {
                              _tts.stop();

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ViewerPage(place: widget.place),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              /// BOTTOM NAV
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 15,
                        color: Colors.black.withOpacity(.08),
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Icon(Icons.explore, color: goldColor),
                      Icon(Icons.favorite_border, color: darkColor),
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE2D1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: goldColor.withOpacity(.4),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.remove_red_eye,
                          color: darkColor,
                          size: 30,
                        ),
                      ),
                      Icon(Icons.calendar_today, color: darkColor),
                      Icon(Icons.person_outline, color: darkColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
