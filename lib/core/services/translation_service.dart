import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/api_keys.dart';
import '../constants/app_constants.dart';

/// Service for Google Cloud Translation API with Firestore caching
class TranslationService {
  static const String _baseUrl = AppConstants.translateBaseUrl;
  static String get _apiKey => ApiKeys.googleTranslateApiKey;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache for session
  final Map<String, String> _memoryCache = {};

  /// Translate text from source to target language
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    if (text.isEmpty) return text;
    if (sourceLanguage == targetLanguage) return text;

    // Check memory cache first
    final cacheKey = '${sourceLanguage}_${targetLanguage}_$text';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    final mockTranslation = '[Mock $targetLanguage] $text';
    
    _memoryCache[cacheKey] = mockTranslation;
    return mockTranslation;
  }

  /// Translate multiple texts at once (batch)
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    if (texts.isEmpty) return [];
    if (sourceLanguage == targetLanguage) return texts;

    await Future.delayed(const Duration(milliseconds: 300));
    return texts.map((t) => '[Mock $targetLanguage] $t').toList();
  }

  // Firestore calls mocked out
  Future<String?> _getFromFirestoreCache({
    required String text,
    required String source,
    required String target,
  }) async {
    return null;
  }

  Future<void> _cacheInFirestore({
    required String text,
    required String translated,
    required String source,
    required String target,
  }) async {
    // No-op
  }

  String _generateCacheId(String text, String source, String target) {
    // Simple hash for document ID
    final hash = text.hashCode.abs().toString();
    return '${source}_${target}_$hash';
  }

  /// Get the language name in that language
  static String getLanguageName(String code) {
    return AppConstants.supportedLanguages[code] ?? code;
  }

  /// Clear the in-memory cache
  void clearCache() {
    _memoryCache.clear();
  }
}

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);

  @override
  String toString() => message;
}
