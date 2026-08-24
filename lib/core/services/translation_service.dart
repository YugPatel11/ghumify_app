import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';
import '../constants/app_constants.dart';
import 'gemini_rest_client.dart';

/// Service for generating translations using DeepL Free API with Gemini fallback
class TranslationService {
  final GeminiRestClient _geminiClient = GeminiRestClient();

  // In-memory cache for session
  final Map<String, String> _memoryCache = {};

  // DeepL Free API endpoint
  static const String _deeplBaseUrl = 'https://api-free.deepl.com/v2/translate';

  // DeepL supported language codes (mapped from app codes)
  static const Map<String, String> _deeplLanguageMap = {
    'en': 'EN',
    'hi': 'HI',
    'ar': 'AR',
    'ja': 'JA',
    'ko': 'KO',
    'zh': 'ZH',
    'de': 'DE',
    'fr': 'FR',
    'es': 'ES',
    'pt': 'PT-BR',
    'ru': 'RU',
    'tr': 'TR',
  };

  /// Check if a language is supported by DeepL
  bool _isDeeplSupported(String langCode) {
    return _deeplLanguageMap.containsKey(langCode);
  }

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

    // Try DeepL first if both languages are supported
    if (_isDeeplSupported(sourceLanguage) && _isDeeplSupported(targetLanguage)) {
      try {
        final result = await _translateWithDeepL(
          text: text,
          sourceLang: sourceLanguage,
          targetLang: targetLanguage,
        );
        _memoryCache[cacheKey] = result;
        return result;
      } catch (e) {
        // DeepL failed, fall through to Gemini
      }
    }

    // Fallback to Gemini for unsupported languages or DeepL failure
    try {
      final result = await _translateWithGemini(
        text: text,
        sourceLang: sourceLanguage,
        targetLang: targetLanguage,
      );
      _memoryCache[cacheKey] = result;
      return result;
    } catch (e) {
      if (e is GeminiRestException) {
        throw TranslationException('Translation service unavailable. Please check your internet connection and try again.');
      }
      throw TranslationException('Translation failed. Please try again later.');
    }
  }

  /// Translate using DeepL Free API
  Future<String> _translateWithDeepL({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final apiKey = ApiKeys.googleTranslateApiKey; // Actually DeepL key
    if (apiKey.isEmpty || apiKey.startsWith('YOUR_')) {
      throw TranslationException('Translation API key not configured.');
    }

    final response = await http.post(
      Uri.parse(_deeplBaseUrl),
      headers: {
        'Authorization': 'DeepL-Auth-Key $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': [text],
        'source_lang': _deeplLanguageMap[sourceLang] ?? sourceLang.toUpperCase(),
        'target_lang': _deeplLanguageMap[targetLang] ?? targetLang.toUpperCase(),
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final translations = data['translations'] as List?;
      if (translations != null && translations.isNotEmpty) {
        return translations[0]['text'] as String? ?? text;
      }
      throw TranslationException('Empty translation response.');
    } else if (response.statusCode == 403) {
      throw TranslationException('Translation API key is invalid.');
    } else if (response.statusCode == 429) {
      throw TranslationException('Translation limit reached. Please try again later.');
    } else if (response.statusCode == 456) {
      throw TranslationException('Translation quota exceeded for this month.');
    } else {
      throw TranslationException('DeepL error ${response.statusCode}');
    }
  }

  /// Translate using Gemini AI (fallback for languages DeepL doesn't support)
  Future<String> _translateWithGemini({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final prompt = '''
Translate the following text from ${getLanguageName(sourceLang)} to ${getLanguageName(targetLang)}.
Return ONLY the translated text, with no extra context or formatting.

Text to translate:
$text
''';

    final responseText = await _geminiClient.generateContent(
      prompt: prompt,
      taskType: GeminiTaskType.translation,
    );

    return responseText.trim();
  }

  /// Translate multiple texts at once (batch)
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    if (texts.isEmpty) return [];
    if (sourceLanguage == targetLanguage) return texts;

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
