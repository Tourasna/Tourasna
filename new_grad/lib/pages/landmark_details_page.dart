import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';
import 'viewer_page.dart';
import '../services/google_tts_service.dart';
import '../services/api_keys.dart';

class LandmarkDetailsPage extends StatefulWidget {
  final Place place;

  const LandmarkDetailsPage({super.key, required this.place});

  @override
  State<LandmarkDetailsPage> createState() => _LandmarkDetailsPageState();
}

class _LandmarkDetailsPageState extends State<LandmarkDetailsPage> {
  final supabase = Supabase.instance.client;

  // ✅ Google TTS Service (Chirp 3 HD - 97% human-like!)
  late final GoogleTTSService _tts;

  bool _storyLoading = false;
  bool _isPlaying = false;

  // Voice info
  String _selectedVoiceDisplayName = 'Charon';
  String _selectedVoiceGender = 'male';
  String _detectedLanguage = 'en-US';

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

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎭 STORY FLOW
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startStoryFlow() async {
    // If already playing, stop
    if (_isPlaying) {
      await _tts.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    try {
      setState(() => _storyLoading = true);

      // 1️⃣ Fetch existing story from database
      final existing = await supabase
          .from('storytelling')
          .select('story')
          .eq('place_id', widget.place.id)
          .maybeSingle();

      String storyText;

      if (existing == null || existing['story'] == null) {
        // 2️⃣ Generate story using Edge Function (Grok)
        debugPrint('📝 No cached story found, generating with Grok...');

        final res = await supabase.functions.invoke(
          'generate-story',
          body: {"place_id": widget.place.id},
        );

        if (res.status != 200 ||
            res.data == null ||
            res.data['story'] == null) {
          throw "Story generation failed";
        }

        storyText = res.data['story'].toString();
        debugPrint('✅ Story generated and saved');
      } else {
        // 3️⃣ Use cached story
        storyText = existing['story'].toString();
        debugPrint('✅ Using cached story');
      }

      // 4️⃣ Detect language and set voice
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

      debugPrint(
        '🌍 Language: $_detectedLanguage | Voice: $_selectedVoiceDisplayName',
      );

      // 5️⃣ Speak story with Google TTS (Chirp 3 HD)
      setState(() {
        _storyLoading = false;
        _isPlaying = true;
      });

      await _tts.speakStory(storyText);
    } catch (e) {
      debugPrint("❌ STORY ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Story error: ${e.toString().substring(0, 50)}...",
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎤 VOICE SELECTOR
  // ═══════════════════════════════════════════════════════════════════════════

  void _showVoiceSelector() {
    _tts.stop();
    if (mounted) setState(() => _isPlaying = false);

    // Detect language from place description or name
    final text = widget.place.description ?? widget.place.name;
    _detectedLanguage = _tts.detectLanguage(text);

    final availableVoices = _tts.getVoicesForLanguage(_detectedLanguage);
    final currentVoice = _tts.getCurrentVoice();

    final langInfo = _tts.getSupportedLanguages().firstWhere(
      (l) => l['code'] == _detectedLanguage,
      orElse: () => {'code': 'en-US', 'name': 'English', 'flag': '🇺🇸'},
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title with detected language
            Row(
              children: [
                Text(langInfo['flag']!, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose Narrator',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A5D57),
                        ),
                      ),
                      Text(
                        'Language: ${langInfo['name']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Voice options
            ...availableVoices.map((voice) {
              final isSelected = voice['code'] == currentVoice;
              final isMale = voice['gender'] == 'male';
              final displayName = voice['displayName'] ?? voice['name']!;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isMale
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isMale ? Icons.man : Icons.woman,
                      size: 32,
                      color: isMale ? Colors.blue : Colors.pink,
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.orange
                          : const Color(0xFF1A5D57),
                    ),
                  ),
                  subtitle: Text(
                    voice['style']!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview button
                      IconButton(
                        icon: Icon(
                          Icons.play_circle_fill,
                          size: 36,
                          color: isSelected ? Colors.orange : Colors.grey,
                        ),
                        onPressed: () async {
                          await _tts.stop();
                          _tts.setVoice(voice['code']!);

                          // Preview text based on language
                          String preview = _detectedLanguage.startsWith('ar')
                              ? 'مرحباً بكم في ${widget.place.name}، أحد أعظم المعالم في مصر.'
                              : _detectedLanguage.startsWith('fr')
                              ? 'Bienvenue à ${widget.place.name}, l\'un des plus grands monuments d\'Égypte.'
                              : _detectedLanguage.startsWith('de')
                              ? 'Willkommen bei ${widget.place.name}, einem der größten Denkmäler Ägyptens.'
                              : _detectedLanguage.startsWith('es')
                              ? 'Bienvenidos a ${widget.place.name}, uno de los monumentos más grandes de Egipto.'
                              : _detectedLanguage.startsWith('it')
                              ? 'Benvenuti a ${widget.place.name}, uno dei più grandi monumenti dell\'Egitto.'
                              : 'Welcome to ${widget.place.name}, one of Egypt\'s greatest landmarks.';

                          await _tts.speakStory(preview);
                        },
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.orange,
                          size: 28,
                        ),
                    ],
                  ),
                  onTap: () {
                    _tts.setVoice(voice['code']!);
                    setState(() {
                      _selectedVoiceDisplayName = displayName;
                      _selectedVoiceGender = voice['gender']!;
                    });
                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              isMale ? Icons.man : Icons.woman,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Text('Narrator: $displayName'),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1A5D57),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            }).toList(),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 BUILD UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final description = widget.place.description ?? "No description available.";

    // Get language info for display
    final langInfo = _tts.getSupportedLanguages().firstWhere(
      (l) => l['code'] == _detectedLanguage,
      orElse: () => {'flag': '🌍'},
    );

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
            // Voice selector button
            TextButton.icon(
              onPressed: _showVoiceSelector,
              icon: Text(
                langInfo['flag']!,
                style: const TextStyle(fontSize: 20),
              ),
              label: Text(
                _selectedVoiceDisplayName,
                style: const TextStyle(color: Color(0xFF1A5D57), fontSize: 13),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                widget.place.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Description
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    description,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ✅ Start Story Button (with Google TTS)
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
                        ? "Loading Story..."
                        : _isPlaying
                        ? "Stop Story"
                        : "Start Story",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: _isPlaying ? Colors.red : Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _storyLoading ? null : _startStoryFlow,
                ),
              ),

              const SizedBox(height: 12),

              // View 3D Model Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text(
                    "View 3D Model",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    _tts.stop(); // Stop TTS when navigating
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
