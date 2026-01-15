import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/place.dart';
import 'viewer_page.dart';
import '../services/google_tts_service.dart';
import '../services/auth_service.dart';
import '../services/api_keys.dart';

class LandmarkDetailsPage extends StatefulWidget {
  final Place place;
  final AuthService authService;

  const LandmarkDetailsPage({
    super.key,
    required this.place,
    required this.authService,
  });

  @override
  State<LandmarkDetailsPage> createState() => _LandmarkDetailsPageState();
}

class _LandmarkDetailsPageState extends State<LandmarkDetailsPage> {
  late final GoogleTTSService _tts;

  bool _storyLoading = false;
  bool _isPlaying = false;

  String _selectedVoiceDisplayName = 'Charon';
  String _selectedVoiceGender = 'male';
  String _detectedLanguage = 'en-US';

  static const String _baseUrl = 'http://10.0.2.2:4000';

  @override
  void initState() {
    super.initState();
    _tts = GoogleTTSService(apiKey: ApiKeys.googleMapsApiKey);
  }

  @override
  void dispose() {
    _tts.stop();
    _tts.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 🎭 STORY FLOW (BACKEND)
  // ─────────────────────────────────────────────

  Future<void> _startStoryFlow() async {
    if (_isPlaying) {
      await _tts.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    try {
      setState(() => _storyLoading = true);

      final token = widget.authService.token;
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final res = await http.get(
        Uri.parse('$_baseUrl/storytelling/${widget.place.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode != 200) {
        throw Exception('Story fetch failed: ${res.body}');
      }

      final storyText = jsonDecode(res.body)['story'] as String;

      _detectedLanguage = _tts.detectLanguage(storyText);
      final voices = _tts.getVoicesForLanguage(_detectedLanguage);

      if (voices.isNotEmpty) {
        final selectedVoice = voices.firstWhere(
          (v) => v['gender'] == _selectedVoiceGender,
          orElse: () => voices.first,
        );
        _tts.setVoice(selectedVoice['code']!);
        _selectedVoiceDisplayName =
            selectedVoice['displayName'] ?? selectedVoice['name']!;
      }

      setState(() {
        _storyLoading = false;
        _isPlaying = true;
      });

      await _tts.speakStory(storyText);
    } catch (e) {
      debugPrint('❌ STORY ERROR: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Story error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _storyLoading = false;
          _isPlaying = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // 🎨 UI (UNCHANGED)
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final description = widget.place.description ?? 'No description available.';

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
                  icon: _storyLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_isPlaying ? Icons.stop : Icons.volume_up),
                  label: Text(
                    _storyLoading
                        ? 'Loading Story...'
                        : _isPlaying
                        ? 'Stop Story'
                        : 'Start Story',
                  ),
                  onPressed: _storyLoading ? null : _startStoryFlow,
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
