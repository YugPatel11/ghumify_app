import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import 'gemini_rest_client.dart';

/// Service for generating translations using Gemini API with Firestore caching
class TranslationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeminiRestClient _geminiClient = GeminiRestClient();

  // In-memory cache for session
  final Map<String, String> _memoryCache = {};

  /// Translate text from source to target language
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    if (text.trim().isEmpty) return text;
    if (sourceLanguage == targetLanguage) return text;

    // Check memory cache first
    final cacheKey = '${sourceLanguage}_${targetLanguage}_$text';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    try {
      final prompt = '''
Translate the following text from ${getLanguageName(sourceLanguage)} to ${getLanguageName(targetLanguage)}.
Return ONLY the translated text, with no extra context or formatting.

Text to translate:
$text
''';

      final responseText = await _geminiClient.generateContent(
        prompt: prompt,
        taskType: GeminiTaskType.translation,
      );

      final result = responseText.trim();
      _memoryCache[cacheKey] = result;
      return result;
    } catch (e) {
      if (e is GeminiRestException) rethrow;
      throw TranslationException('Translation failed: $e');
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

    // Simple implementation: just run in parallel
    // (can be optimized later with a single batch prompt if needed)
    final futures = texts.map((t) => translate(
          text: t,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        ));
    return await Future.wait(futures);
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
