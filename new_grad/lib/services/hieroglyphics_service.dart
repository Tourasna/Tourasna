// lib/services/hieroglyphics_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:flutter/material.dart';

class GlyphResult {
  final String gardinerCode;
  final double confidence;
  final List<double> bbox;

  const GlyphResult({
    required this.gardinerCode,
    required this.confidence,
    required this.bbox,
  });

  factory GlyphResult.fromJson(Map<String, dynamic> j) => GlyphResult(
    gardinerCode: j['gardiner_code'],
    confidence: (j['confidence'] as num).toDouble(),
    bbox: List<double>.from(j['bbox']),
  );
}

class SignMeaning {
  final String code;
  final String meaningEn;
  final String meaningAr;
  final String sound;
  final String category;

  const SignMeaning({
    required this.code,
    required this.meaningEn,
    required this.meaningAr,
    required this.sound,
    required this.category,
  });

  factory SignMeaning.fromJson(Map<String, dynamic> j) => SignMeaning(
    code: j['code'],
    meaningEn: j['meaning_en'] ?? '',
    meaningAr: j['meaning_ar'] ?? '',
    sound: j['sound'] ?? '',
    category: j['category'] ?? '',
  );
}

class HieroglyphicsResult {
  final bool success;
  final int glyphCount;
  final String readingDirection;
  final List<GlyphResult> glyphs;
  final String? english;
  final String? arabic;
  final String? transliteration;
  final String? historicalContextEn;
  final String? historicalContextAr;
  final String translationMethod;
  final List<SignMeaning> signMeanings;

  const HieroglyphicsResult({
    required this.success,
    required this.glyphCount,
    required this.readingDirection,
    required this.glyphs,
    this.english,
    this.arabic,
    this.transliteration,
    this.historicalContextEn,
    this.historicalContextAr,
    required this.translationMethod,
    required this.signMeanings,
  });

  factory HieroglyphicsResult.fromJson(Map<String, dynamic> j) {
    final t = j['translation'] as Map<String, dynamic>?;
    return HieroglyphicsResult(
      success: j['success'] ?? false,
      glyphCount: j['glyph_count'] ?? 0,
      readingDirection: j['reading_direction'] ?? 'rtl',
      glyphs: (j['glyphs'] as List? ?? [])
          .map((g) => GlyphResult.fromJson(g))
          .toList(),
      english: t?['english'],
      arabic: t?['arabic'],
      transliteration: t?['transliteration'],
      historicalContextEn: t?['historical_context_en'],
      historicalContextAr: t?['historical_context_ar'],
      translationMethod: t?['translation_method'] ?? 'unknown',
      signMeanings: (t?['sign_meanings'] as List? ?? [])
          .map((s) => SignMeaning.fromJson(s))
          .toList(),
    );
  }
}

class GlyphIcon {
  /// Returns the asset path for a Gardiner code, or null if not found.
  static String? assetPath(String gardinerCode) {
    return 'assets/icons/glyph_icons/$gardinerCode.png';
  }

  /// Widget that shows the glyph PNG, falling back to a text badge.
  static Widget image(
    String gardinerCode, {
    double size = 40,
    Color? background,
  }) {
    final path = assetPath(gardinerCode);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? const Color(0xFFF2EADC),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.asset(
          path!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              gardinerCode,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 10,
                color: Color(0xFF1A3C3C),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HieroglyphicsService {
  static const String _baseUrl = 'http://13.50.201.36:3000';

  static Future<String?> _getToken() async {
    return AuthService().getValidToken();
  }

  static Future<HieroglyphicsResult> translate(
    File imageFile, {
    String readingDirection = 'rtl',
  }) async {
    final token = await _getToken();

    final uri = Uri.parse(
      '$_baseUrl/api/hieroglyphics/translate?reading_direction=$readingDirection',
    );

    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamed = await request.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () =>
          throw Exception('Translation timed out — please try again'),
    );

    final response = await http.Response.fromStream(streamed);

    print(
      'STATUS CODE: ${response.statusCode}',
    ); // ← MUST be here, before the if

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return HieroglyphicsResult.fromJson(json);
      } catch (e) {
        print('JSON PARSE ERROR: $e');
        throw Exception('Failed to parse response: $e');
      }
    } else {
      print('ERROR BODY: ${response.body}');
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Translation failed');
      } catch (_) {
        throw Exception('Server error ${response.statusCode}');
      }
    }
  }
}
