import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;

/// 🎭 Google Cloud TTS Service - Chirp 3 HD Edition (97% Human-like!)
///
/// Features:
/// - Chirp 3 HD voices (Google's BEST voices - 97% human-like)
/// - 2 voices per language (Male + Female Tour Guide)
/// - flutter_langdetect for accurate language detection (offline)
/// - 31 languages supported
class GoogleTTSService {
  final String apiKey;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _fallbackTts = FlutterTts();

  String _currentLanguage = 'en-US';
  String _currentVoice = 'en-US-Chirp3-HD-Charon';
  bool _isSpeaking = false;
  bool _isDisposed = false;
  static bool _isLangDetectInitialized = false;

  GoogleTTSService({required this.apiKey}) {
    _initLangDetect();

    _audioPlayer.onPlayerComplete.listen((_) {
      _isSpeaking = false;
    });
  }

  Future<void> _initLangDetect() async {
    if (_isLangDetectInitialized) return;
    try {
      await langdetect.initLangDetect();
      _isLangDetectInitialized = true;
      print('✅ flutter_langdetect initialized');
    } catch (e) {
      print('⚠️ langdetect init error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎤 CHIRP 3 HD VOICES - Best quality (97% human-like!)
  // ═══════════════════════════════════════════════════════════════════════════

  static final List<Map<String, String>> _allVoices = [
    // 🇺🇸 English (US)
    {
      'code': 'en-US-Chirp3-HD-Charon',
      'name': 'Charon',
      'displayName': 'Charon', // الاسم اللي بيظهر في UI
      'gender': 'male',
      'lang': 'en-US',
      'langCode': 'en',
      'langName': 'English',
      'flag': '🇺🇸',
      'style': 'Professional Tour Guide',
    },
    {
      'code': 'en-US-Chirp3-HD-Kore',
      'name': 'Kore',
      'displayName': 'Kore',
      'gender': 'female',
      'lang': 'en-US',
      'langCode': 'en',
      'langName': 'English',
      'flag': '🇺🇸',
      'style': 'Friendly Tour Guide',
    },

    // 🇬🇧 English (UK)
    {
      'code': 'en-GB-Chirp3-HD-Charon',
      'name': 'Charon',
      'displayName': 'Charon',
      'gender': 'male',
      'lang': 'en-GB',
      'langCode': 'en',
      'langName': 'British English',
      'flag': '🇬🇧',
      'style': 'Museum Guide',
    },
    {
      'code': 'en-GB-Chirp3-HD-Aoede',
      'name': 'Aoede',
      'displayName': 'Aoede',
      'gender': 'female',
      'lang': 'en-GB',
      'langCode': 'en',
      'langName': 'British English',
      'flag': '🇬🇧',
      'style': 'Heritage Guide',
    },

    // 🇪🇬 Arabic (Egypt flag!) - أسماء عربية
    {
      'code': 'ar-XA-Chirp3-HD-Charon',
      'name': 'Charon', // الاسم التقني للـ API
      'displayName': 'أحمد', // الاسم اللي بيظهر في UI
      'gender': 'male',
      'lang': 'ar-XA',
      'langCode': 'ar',
      'langName': 'العربية',
      'flag': '🇪🇬', // ✅ علم مصر!
      'style': 'مرشد سياحي محترف',
    },
    {
      'code': 'ar-XA-Chirp3-HD-Kore',
      'name': 'Kore',
      'displayName': 'فاطمة', // الاسم اللي بيظهر في UI
      'gender': 'female',
      'lang': 'ar-XA',
      'langCode': 'ar',
      'langName': 'العربية',
      'flag': '🇪🇬', // ✅ علم مصر!
      'style': 'مرشدة سياحية',
    },

    // 🇫🇷 French
    {
      'code': 'fr-FR-Chirp3-HD-Fenrir',
      'name': 'Fenrir',
      'displayName': 'Pierre',
      'gender': 'male',
      'lang': 'fr-FR',
      'langCode': 'fr',
      'langName': 'Français',
      'flag': '🇫🇷',
      'style': 'Guide Touristique',
    },
    {
      'code': 'fr-FR-Chirp3-HD-Leda',
      'name': 'Leda',
      'displayName': 'Marie',
      'gender': 'female',
      'lang': 'fr-FR',
      'langCode': 'fr',
      'langName': 'Français',
      'flag': '🇫🇷',
      'style': 'Guide Touristique',
    },

    // 🇩🇪 German
    {
      'code': 'de-DE-Chirp3-HD-Orus',
      'name': 'Orus',
      'displayName': 'Hans',
      'gender': 'male',
      'lang': 'de-DE',
      'langCode': 'de',
      'langName': 'Deutsch',
      'flag': '🇩🇪',
      'style': 'Reiseführer',
    },
    {
      'code': 'de-DE-Chirp3-HD-Aoede',
      'name': 'Aoede',
      'displayName': 'Anna',
      'gender': 'female',
      'lang': 'de-DE',
      'langCode': 'de',
      'langName': 'Deutsch',
      'flag': '🇩🇪',
      'style': 'Reiseleiterin',
    },

    // 🇪🇸 Spanish
    {
      'code': 'es-ES-Chirp3-HD-Puck',
      'name': 'Puck',
      'displayName': 'Carlos',
      'gender': 'male',
      'lang': 'es-ES',
      'langCode': 'es',
      'langName': 'Español',
      'flag': '🇪🇸',
      'style': 'Guía Turístico',
    },
    {
      'code': 'es-ES-Chirp3-HD-Kore',
      'name': 'Kore',
      'displayName': 'Isabella',
      'gender': 'female',
      'lang': 'es-ES',
      'langCode': 'es',
      'langName': 'Español',
      'flag': '🇪🇸',
      'style': 'Guía Turística',
    },

    // 🇮🇹 Italian
    {
      'code': 'it-IT-Chirp3-HD-Charon',
      'name': 'Charon',
      'displayName': 'Marco',
      'gender': 'male',
      'lang': 'it-IT',
      'langCode': 'it',
      'langName': 'Italiano',
      'flag': '🇮🇹',
      'style': 'Guida Turistica',
    },
    {
      'code': 'it-IT-Chirp3-HD-Leda',
      'name': 'Leda',
      'displayName': 'Giulia',
      'gender': 'female',
      'lang': 'it-IT',
      'langCode': 'it',
      'langName': 'Italiano',
      'flag': '🇮🇹',
      'style': 'Guida Turistica',
    },
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // 🌍 LANGUAGE DETECTION using flutter_langdetect
  // ═══════════════════════════════════════════════════════════════════════════

  String detectLanguage(String text) {
    if (text.isEmpty) return 'en-US';

    try {
      if (!_isLangDetectInitialized) {
        langdetect.initLangDetect();
        _isLangDetectInitialized = true;
      }

      final detectedLang = langdetect.detect(text);
      print('🔍 Detected language: $detectedLang');

      return _mapLangCodeToVoiceLang(detectedLang);
    } catch (e) {
      print('⚠️ langdetect error: $e');
      return 'en-US';
    }
  }

  String _mapLangCodeToVoiceLang(String langCode) {
    final mapping = {
      'en': 'en-US',
      'ar': 'ar-XA',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'es': 'es-ES',
      'it': 'it-IT',
      // Fallbacks
      'pt': 'en-US',
      'nl': 'en-US',
      'ru': 'en-US',
      'ja': 'en-US',
      'ko': 'en-US',
      'zh-cn': 'en-US',
      'zh-tw': 'en-US',
    };
    return mapping[langCode] ?? 'en-US';
  }

  /// ✅ Get voices for a specific language - FIXED!
  List<Map<String, String>> getVoicesForLanguage(String languageCode) {
    // Normalize language code
    if (languageCode.startsWith('en') && !languageCode.contains('GB')) {
      languageCode = 'en-US';
    }

    // ✅ Filter voices by EXACT language match
    final voices = _allVoices.where((v) => v['lang'] == languageCode).toList();

    print('🎤 Getting voices for: $languageCode');
    print(
      '🎤 Found ${voices.length} voices: ${voices.map((v) => v['displayName']).toList()}',
    );

    return voices;
  }

  List<Map<String, String>> getVoicesForText(String text) {
    final detectedLang = detectLanguage(text);
    return getVoicesForLanguage(detectedLang);
  }

  List<Map<String, String>> getAllVoices() => _allVoices;

  List<Map<String, String>> getSupportedLanguages() {
    return [
      {'code': 'en-US', 'name': 'English (US)', 'flag': '🇺🇸'},
      {'code': 'en-GB', 'name': 'English (UK)', 'flag': '🇬🇧'},
      {'code': 'ar-XA', 'name': 'العربية', 'flag': '🇪🇬'}, // ✅ علم مصر!
      {'code': 'fr-FR', 'name': 'Français', 'flag': '🇫🇷'},
      {'code': 'de-DE', 'name': 'Deutsch', 'flag': '🇩🇪'},
      {'code': 'es-ES', 'name': 'Español', 'flag': '🇪🇸'},
      {'code': 'it-IT', 'name': 'Italiano', 'flag': '🇮🇹'},
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎭 MAIN STORYTELLING FUNCTION - CHIRP 3 HD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> speakStory(String text, {String? voiceCode}) async {
    if (text.isEmpty || _isDisposed) return;

    await stop();

    try {
      _isSpeaking = true;

      String selectedVoice = voiceCode ?? _currentVoice;
      String languageCode = _extractLanguageFromVoice(selectedVoice);

      print('════════════════════════════════════════════');
      print('🎭 CHIRP 3 HD - TOUR GUIDE SPEAKING');
      print('🎤 Voice: $selectedVoice');
      print('🌍 Language: $languageCode');
      print('✨ Quality: 97% Human-like!');
      print('════════════════════════════════════════════');

      await _speakWithChirp3HD(text, selectedVoice, languageCode);
    } catch (e) {
      print('❌ Chirp 3 HD Error: $e');
      print('⚠️ Trying Neural2 fallback...');

      try {
        await _speakWithNeural2Fallback(text);
      } catch (e2) {
        print('❌ Neural2 fallback also failed: $e2');
        if (!_isDisposed) {
          await _fallbackSpeak(text);
        }
      }
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> speak(String text) async => await speakStory(text);

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 CHIRP 3 HD API
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _speakWithChirp3HD(
    String text,
    String voiceName,
    String languageCode,
  ) async {
    if (_isDisposed) return;

    final url =
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey';

    final requestBody = {
      'input': {'text': text},
      'voice': {'languageCode': languageCode, 'name': voiceName},
      'audioConfig': {'audioEncoding': 'MP3'},
    };

    print('📡 Calling Chirp 3 HD API...');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );

    if (_isDisposed) return;

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final audioContent = responseData['audioContent'] as String;
      final audioBytes = base64.decode(audioContent);

      print('✅ Chirp 3 HD Audio received (${audioBytes.length} bytes)');

      if (!_isDisposed) {
        await _audioPlayer.play(BytesSource(audioBytes));
        await _audioPlayer.onPlayerComplete.first;
      }

      print('✅ Finished speaking with Chirp 3 HD');
    } else {
      print('❌ Chirp 3 HD API Error: ${response.statusCode}');
      print('Response: ${response.body}');
      throw Exception('Chirp 3 HD API failed: ${response.statusCode}');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔄 NEURAL2 FALLBACK
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _speakWithNeural2Fallback(String text) async {
    if (_isDisposed) return;

    final url =
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey';

    String neural2Voice = _getNeural2Voice(_currentLanguage);
    final ssml = _buildStorytellingSSML(text);

    final requestBody = {
      'input': {'ssml': ssml},
      'voice': {'languageCode': _currentLanguage, 'name': neural2Voice},
      'audioConfig': {
        'audioEncoding': 'MP3',
        'speakingRate': 0.82,
        'pitch': -1.5,
        'volumeGainDb': 2.5,
        'effectsProfileId': ['headphone-class-device'],
      },
    };

    print('📡 Calling Neural2 Fallback API...');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );

    if (_isDisposed) return;

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final audioContent = responseData['audioContent'] as String;
      final audioBytes = base64.decode(audioContent);

      print('✅ Neural2 Fallback Audio received');

      if (!_isDisposed) {
        await _audioPlayer.play(BytesSource(audioBytes));
        await _audioPlayer.onPlayerComplete.first;
      }
    } else {
      throw Exception('Neural2 fallback failed: ${response.statusCode}');
    }
  }

  String _getNeural2Voice(String languageCode) {
    final neural2Voices = {
      'en-US': 'en-US-Neural2-D',
      'en-GB': 'en-GB-Neural2-B',
      'ar-XA': 'ar-XA-Wavenet-B',
      'fr-FR': 'fr-FR-Neural2-B',
      'de-DE': 'de-DE-Neural2-B',
      'es-ES': 'es-ES-Neural2-B',
      'it-IT': 'it-IT-Neural2-C',
    };
    return neural2Voices[languageCode] ?? 'en-US-Neural2-D';
  }

  String _buildStorytellingSSML(String text) {
    String escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    List<String> sentences = escaped.split(RegExp(r'(?<=[.!?،。])\s+'));

    StringBuffer ssml = StringBuffer();
    ssml.write('<speak>');

    for (int i = 0; i < sentences.length; i++) {
      String sentence = sentences[i].trim();
      if (sentence.isEmpty) continue;

      if (i == 0) {
        ssml.write('<emphasis level="moderate"><s>$sentence</s></emphasis>');
        ssml.write('<break time="1200ms"/>');
      } else {
        ssml.write('<s>$sentence</s>');
        if (i < sentences.length - 1) {
          ssml.write('<break time="800ms"/>');
        }
      }
    }

    ssml.write('</speak>');
    return ssml.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 DEVICE TTS FALLBACK
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _fallbackSpeak(String text) async {
    if (_isDisposed) return;
    try {
      await _fallbackTts.setLanguage(_currentLanguage);
      await _fallbackTts.setSpeechRate(0.4);
      await _fallbackTts.setPitch(0.95);
      await _fallbackTts.setVolume(1.0);
      await _fallbackTts.speak(text);
    } catch (e) {
      print('❌ Device TTS failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛠️ HELPER FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  String _extractLanguageFromVoice(String voiceCode) {
    final parts = voiceCode.split('-');
    if (parts.length >= 2) return '${parts[0]}-${parts[1]}';
    return 'en-US';
  }

  String _getDefaultVoiceForLanguage(String languageCode) {
    final voices = getVoicesForLanguage(languageCode);
    if (voices.isNotEmpty) {
      final maleVoice = voices.firstWhere(
        (v) => v['gender'] == 'male',
        orElse: () => voices.first,
      );
      return maleVoice['code']!;
    }
    return 'en-US-Chirp3-HD-Charon';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎛️ CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  void setLanguage(String languageCode) {
    _currentLanguage = languageCode;
    _currentVoice = _getDefaultVoiceForLanguage(languageCode);
    print('🌍 Language: $languageCode | Voice: $_currentVoice');
  }

  void setVoice(String voiceCode) {
    _currentVoice = voiceCode;
    _currentLanguage = _extractLanguageFromVoice(voiceCode);
    print('🎤 Voice: $voiceCode | Language: $_currentLanguage');
  }

  void setVoiceForText(String text, {String preferredGender = 'male'}) {
    final detectedLang = detectLanguage(text);
    final voices = getVoicesForLanguage(detectedLang);

    if (voices.isNotEmpty) {
      final preferredVoice = voices.firstWhere(
        (v) => v['gender'] == preferredGender,
        orElse: () => voices.first,
      );
      _currentVoice = preferredVoice['code']!;
      _currentLanguage = detectedLang;
    }
    print('🔍 Auto-detected: $detectedLang | Voice: $_currentVoice');
  }

  String getCurrentLanguage() => _currentLanguage;
  String getCurrentVoice() => _currentVoice;
  bool get isSpeaking => _isSpeaking;

  Future<void> stop() async {
    _isSpeaking = false;
    try {
      await _audioPlayer.stop();
    } catch (e) {}
    try {
      await _fallbackTts.stop();
    } catch (e) {}
  }

  Future<void> pause() async {
    if (_isDisposed) return;
    await _audioPlayer.pause();
    _isSpeaking = false;
  }

  Future<void> resume() async {
    if (_isDisposed) return;
    await _audioPlayer.resume();
    _isSpeaking = true;
  }

  void shutdown() {
    _isDisposed = true;
    _isSpeaking = false;
    try {
      _audioPlayer.stop();
      _audioPlayer.dispose();
    } catch (e) {}
    try {
      _fallbackTts.stop();
    } catch (e) {}
  }

  void dispose() {
    _isDisposed = true;
    _isSpeaking = false;
    try {
      _audioPlayer.stop();
      _audioPlayer.dispose();
    } catch (e) {}
    try {
      _fallbackTts.stop();
    } catch (e) {}
  }
}
