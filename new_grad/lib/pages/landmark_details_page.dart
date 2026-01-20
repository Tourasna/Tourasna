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

  /// User preference (PERSISTED)
  String _preferredGender = 'male'; // male = Charon, female = Kore
  String _detectedLanguage = 'en-US';

  static const String _voicePrefKey = 'tts_preferred_gender';

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

  // ─────────────────────────────────────────────
  // 🎭 STORY FLOW
  // ─────────────────────────────────────────────

  Future<void> _startStoryFlow() async {
    if (_storyLoading) return;

    // Pause
    if (_isPlaying && !_isPaused) {
      await _tts.pause();
      setState(() => _isPaused = true);
      return;
    }

    // Resume
    if (_isPlaying && _isPaused) {
      await _tts.resume();
      setState(() => _isPaused = false);
      return;
    }

    try {
      setState(() => _storyLoading = true);

      // Fetch & cache story once
      final storyText = _cachedStory ??= await StorytellingService.getStory(
        widget.place.id,
      );

      // 🔥 ALWAYS apply preferred voice
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ─────────────────────────────────────────────
  // 🎤 VOICE SELECTOR (CHARON / KORE)
  // ─────────────────────────────────────────────

  void _showVoiceSelector() {
    _tts.stop();
    setState(() {
      _isPlaying = false;
      _isPaused = false;
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Narrator',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Charon'),
                  selected: _preferredGender == 'male',
                  onSelected: (v) {
                    if (!v) return;
                    _preferredGender = 'male';
                    _saveVoicePreference('male');
                    _tts.setVoiceForText(
                      widget.place.description ?? widget.place.name,
                      preferredGender: 'male',
                    );
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('Kore'),
                  selected: _preferredGender == 'female',
                  onSelected: (v) {
                    if (!v) return;
                    _preferredGender = 'female';
                    _saveVoicePreference('female');
                    _tts.setVoiceForText(
                      widget.place.description ?? widget.place.name,
                      preferredGender: 'female',
                    );
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🎨 UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final description = widget.place.description ?? 'No description available.';

    IconData icon;
    String label;

    if (_storyLoading) {
      icon = Icons.hourglass_top;
      label = 'Loading Story...';
    } else if (_isPlaying && !_isPaused) {
      icon = Icons.pause;
      label = 'Pause Story';
    } else if (_isPlaying && _isPaused) {
      icon = Icons.play_arrow;
      label = 'Resume Story';
    } else {
      icon = Icons.volume_up;
      label = 'Play Story';
    }

    return WillPopScope(
      onWillPop: () async {
        await _tts.stop();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.place.name),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _showVoiceSelector,
              child: Text(
                _preferredGender == 'male' ? 'Charon' : 'Kore',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.place.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    description,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(icon),
                  label: Text(label),
                  onPressed: _startStoryFlow,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('View 3D Model'),
                  onPressed: () {
                    _tts.stop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewerPage(place: widget.place),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
