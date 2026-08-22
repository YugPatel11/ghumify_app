import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/api_keys.dart';
import '../constants/app_constants.dart';

/// Service for Google Cloud Translation API with Firestore caching
class TranslationService {
  static const String _baseUrl = AppConstants.translateBaseUrl;
  static const String _apiKey = ApiKeys.googleTranslateApiKey;
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

    // Check Firestore cache
    try {
      final cached = await _getFromFirestoreCache(
        text: text,
        source: sourceLanguage,
        target: targetLanguage,
      );
      if (cached != null) {
        _memoryCache[cacheKey] = cached;
        return cached;
      }
    } catch (_) {
      // Cache miss, proceed to API
    }

    // Call Google Translate API
    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'q': text,
          'source': sourceLanguage,
          'target': targetLanguage,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translated =
            data['data']['translations'][0]['translatedText'] as String;

        // Cache in memory
        _memoryCache[cacheKey] = translated;

        // Cache in Firestore (fire-and-forget)
        _cacheInFirestore(
          text: text,
          translated: translated,
          source: sourceLanguage,
          target: targetLanguage,
        );

        return translated;
      } else {
        throw TranslationException(
          'Translation failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is TranslationException) rethrow;
      throw TranslationException('Network error during translation: $e');
    }
  }

  /// Translate multiple texts at once (batch)
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    if (texts.isEmpty) return [];
    if (sourceLanguage == targetLanguage) return texts;

    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'q': texts,
          'source': sourceLanguage,
          'target': targetLanguage,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translations = data['data']['translations'] as List;
        return translations
            .map((t) => t['translatedText'] as String)
            .toList();
      } else {
        throw TranslationException(
          'Batch translation failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is TranslationException) rethrow;
      throw TranslationException('Network error during batch translation: $e');
    }
  }

  /// Get cached translation from Firestore
  Future<String?> _getFromFirestoreCache({
    required String text,
    required String source,
    required String target,
  }) async {
    final docId = _generateCacheId(text, source, target);
    final doc = await _firestore
        .collection(AppConstants.translationsCollection)
        .doc(docId)
        .get();

    if (doc.exists) {
      return doc.data()?['translatedText'] as String?;
    }
    return null;
  }

  /// Cache translation in Firestore
  Future<void> _cacheInFirestore({
    required String text,
    required String translated,
    required String source,
    required String target,
  }) async {
    try {
      final docId = _generateCacheId(text, source, target);
      await _firestore
          .collection(AppConstants.translationsCollection)
          .doc(docId)
          .set({
        'sourceText': text,
        'translatedText': translated,
        'sourceLanguage': source,
        'targetLanguage': target,
        'cachedAt': Timestamp.now(),
      });
    } catch (_) {
      // Silently fail — caching is best-effort
    }
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
