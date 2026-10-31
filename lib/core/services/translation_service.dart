import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_keys.dart';
import '../constants/app_constants.dart';
import 'gemini_rest_client.dart';

/// High-performance Translation Service powered by Sarvam AI
/// with local persistent caching, deduplication, chunking, and fallback.
class TranslationService {
  static final TranslationService instance = TranslationService._internal();
  factory TranslationService() => instance;

  TranslationService._internal() {
    _initPersistentCache();
  }

  final GeminiRestClient _geminiClient = GeminiRestClient();

  // In-memory cache: key format = '$targetLang::$text'
  final Map<String, String> _memoryCache = {};

  // Track which language caches have been loaded from SharedPreferences
  final Set<String> _loadedLanguages = {};

  // In-flight deduplication: map key -> active Future
  final Map<String, Future<String>> _inFlight = {};

  // Concurrency semaphore (max 3 concurrent API requests)
  int _activeRequests = 0;
  final List<Completer<void>> _waitQueue = [];

  static const String _sarvamBaseUrl = 'https://api.sarvam.ai/translate';

  static const Map<String, String> _sarvamLanguageMap = {
    'en': 'en-IN',
    'hi': 'hi-IN',
    'gu': 'gu-IN',
    'mr': 'mr-IN',
    'bn': 'bn-IN',
    'ta': 'ta-IN',
    'te': 'te-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'pa': 'pa-IN',
    'od': 'od-IN',
    'as': 'as-IN',
    'mai': 'mai-IN',
    'sat': 'sat-IN',
    'ks': 'ks-IN',
    'ne': 'ne-IN',
    'kok': 'kok-IN',
    'sd': 'sd-IN',
    'doi': 'doi-IN',
    'mni': 'mni-IN',
    'brx': 'brx-IN',
    'sa': 'sa-IN',
    'ur': 'ur-IN',
  };

  /// Check whether language is English
  static bool isEnglish(String? code) {
    if (code == null) return true;
    final clean = code.toLowerCase().trim();
    return clean == 'en' || clean == 'en-in' || clean.startsWith('en_');
  }

  /// Convert arbitrary language code to Sarvam BCP-47 format
  static String toSarvamLanguageCode(String code) {
    final clean = code.toLowerCase().trim();
    if (_sarvamLanguageMap.containsKey(clean)) {
      return _sarvamLanguageMap[clean]!;
    }
    if (clean.contains('-')) return clean;
    return '$clean-IN';
  }

  /// Initialize persistent cache from SharedPreferences
  Future<void> _initPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('ghumify_tr_cache_')) {
          final targetLang = key.substring('ghumify_tr_cache_'.length);
          final rawJson = prefs.getString(key);
          if (rawJson != null) {
            final Map<String, dynamic> decoded = jsonDecode(rawJson);
            decoded.forEach((k, v) {
              if (v is String) {
                _memoryCache['$targetLang::$k'] = v;
              }
            });
            _loadedLanguages.add(targetLang);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading persistent translation cache: $e');
    }
  }

  /// Ensure cache for a specific language is loaded from storage
  Future<void> _ensureLanguageCacheLoaded(String targetLang) async {
    if (_loadedLanguages.contains(targetLang)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'ghumify_tr_cache_$targetLang';
      final rawJson = prefs.getString(key);
      if (rawJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(rawJson);
        decoded.forEach((k, v) {
          if (v is String) {
            _memoryCache['$targetLang::$k'] = v;
          }
        });
      }
      _loadedLanguages.add(targetLang);
    } catch (_) {}
  }

  /// Persist an entry to SharedPreferences
  Future<void> _persistEntry(String targetLang, String original, String translated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'ghumify_tr_cache_$targetLang';
      Map<String, dynamic> data = {};
      final rawJson = prefs.getString(key);
      if (rawJson != null) {
        try {
          data = jsonDecode(rawJson) as Map<String, dynamic>;
        } catch (_) {}
      }
      data[original] = translated;
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('Error persisting translation entry: $e');
    }
  }

  /// Fast synchronous lookup in memory cache
  String? getCached(String text, {required String targetLang}) {
    if (isEnglish(targetLang)) return text;
    final clean = text.trim();
    if (clean.isEmpty || _shouldSkipTranslation(clean)) return text;
    final cacheKey = '$targetLang::$clean';
    return _memoryCache[cacheKey];
  }

  /// Main translation method with deduplication and concurrency control
  Future<String> translateText(
    String text, {
    required String targetLang,
    String sourceLang = 'en',
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return text;
    if (isEnglish(targetLang)) return text;
    if (_shouldSkipTranslation(clean)) return text;

    await _ensureLanguageCacheLoaded(targetLang);

    final cacheKey = '$targetLang::$clean';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // Deduplicate in-flight requests for the exact same text and language
    if (_inFlight.containsKey(cacheKey)) {
      return await _inFlight[cacheKey]!;
    }

    final future = _queueAndExecuteTranslation(clean, targetLang, sourceLang);
    _inFlight[cacheKey] = future;

    try {
      final result = await future;
      _memoryCache[cacheKey] = result;
      _persistEntry(targetLang, clean, result);
      return result;
    } catch (e) {
      debugPrint('Translation error for "$clean": $e');
      return clean; // Silent fallback to English
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  /// Concurrency throttle queue
  Future<String> _queueAndExecuteTranslation(
    String text,
    String targetLang,
    String sourceLang,
  ) async {
    // Acquire semaphore token
    while (_activeRequests >= 3) {
      final completer = Completer<void>();
      _waitQueue.add(completer);
      await completer.future;
    }
    _activeRequests++;

    try {
      // Chunking if text exceeds 1800 characters
      if (text.length > 1800) {
        return await _translateLargeText(text, targetLang, sourceLang);
      }
      return await _translateSingleChunk(text, targetLang, sourceLang);
    } finally {
      _activeRequests--;
      if (_waitQueue.isNotEmpty) {
        final next = _waitQueue.removeAt(0);
        if (!next.isCompleted) next.complete();
      }
    }
  }

  /// Translate a single chunk under 1800 characters
  Future<String> _translateSingleChunk(
    String text,
    String targetLang,
    String sourceLang,
  ) async {
    final sarvamKey = ApiKeys.sarvamApiKey;
    final hasValidSarvamKey = sarvamKey.isNotEmpty && !sarvamKey.startsWith('your_');

    if (hasValidSarvamKey) {
      try {
        return await _callSarvamWithRetry(text, targetLang, sourceLang);
      } catch (e) {
        debugPrint('Sarvam translation failed, attempting fallback: $e');
      }
    }

    // Fallback: Gemini AI
    try {
      return await _translateWithGemini(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
    } catch (_) {}

    return text;
  }

  /// Call Sarvam Translate API with automatic retry on 429
  Future<String> _callSarvamWithRetry(
    String text,
    String targetLang,
    String sourceLang,
  ) async {
    final targetCode = toSarvamLanguageCode(targetLang);
    final sourceCode = isEnglish(sourceLang) ? 'en-IN' : toSarvamLanguageCode(sourceLang);

    final uri = Uri.parse(_sarvamBaseUrl);
    final headers = {
      'Content-Type': 'application/json',
      'api-subscription-key': ApiKeys.sarvamApiKey,
    };
    final body = jsonEncode({
      'input': text,
      'source_language_code': sourceCode,
      'target_language_code': targetCode,
      'model': 'sarvam-translate:v1',
      'mode': 'formal',
    });

    http.Response response;
    try {
      response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw TranslationException('Sarvam request timed out');
    }

    if (response.statusCode == 429) {
      // Rate limit backoff: wait 1.5 seconds and retry once
      await Future.delayed(const Duration(milliseconds: 1500));
      response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final translated = data['translated_text'] as String?;
      if (translated != null && translated.trim().isNotEmpty) {
        return translated.trim();
      }
    }

    throw TranslationException('Sarvam API returned HTTP ${response.statusCode}: ${response.body}');
  }

  /// Chunk large text and re-assemble
  Future<String> _translateLargeText(
    String text,
    String targetLang,
    String sourceLang,
  ) async {
    final paragraphs = text.split('\n');
    final translatedChunks = <String>[];

    for (final p in paragraphs) {
      if (p.trim().isEmpty) {
        translatedChunks.add('');
        continue;
      }
      if (p.length <= 1800) {
        final tr = await _translateSingleChunk(p, targetLang, sourceLang);
        translatedChunks.add(tr);
      } else {
        // Split by sentences
        final sentences = p.split(RegExp(r'(?<=[.!?])\s+'));
        var currentChunk = '';
        for (final s in sentences) {
          if (currentChunk.length + s.length > 1700) {
            final tr = await _translateSingleChunk(currentChunk, targetLang, sourceLang);
            translatedChunks.add(tr);
            currentChunk = s;
          } else {
            currentChunk = currentChunk.isEmpty ? s : '$currentChunk $s';
          }
        }
        if (currentChunk.isNotEmpty) {
          final tr = await _translateSingleChunk(currentChunk, targetLang, sourceLang);
          translatedChunks.add(tr);
        }
      }
    }

    return translatedChunks.join('\n');
  }

  /// Translate using Gemini AI as robust secondary fallback
  Future<String> _translateWithGemini({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final prompt = '''
Translate the following text from ${getLanguageName(sourceLang)} to ${getLanguageName(targetLang)}.
Return ONLY the translated text, with no extra context or quotes.

Text to translate:
$text
''';

    final responseText = await _geminiClient.generateContent(
      prompt: prompt,
      taskType: GeminiTaskType.translation,
    );

    return responseText.trim();
  }

  /// Determine if string should bypass translation
  bool _shouldSkipTranslation(String text) {
    if (text.length <= 1) return true;
    if (text == 'Ghumify') return true;

    // Pure numbers, dates, currency, times
    if (RegExp(r'^[\d\s.,:;!?₹$%#@+\-*/()—–-]+$').hasMatch(text)) return true;
    if (RegExp(r'^\d{1,2}:\d{2}(\s*(AM|PM))?$', caseSensitive: false).hasMatch(text)) return true;

    // URLs and Emails
    if (text.contains('http://') || text.contains('https://') || text.contains('@')) return true;

    return false;
  }

  /// Legacy method preserved for compatibility with TranslatorScreen
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    return translateText(
      text,
      targetLang: targetLanguage,
      sourceLang: sourceLanguage,
    );
  }

  /// Batch translate multiple texts
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    if (texts.isEmpty) return [];
    if (isEnglish(targetLanguage)) return texts;

    return Future.wait(
      texts.map((t) => translateText(t, targetLang: targetLanguage, sourceLang: sourceLanguage)),
    );
  }

  /// Get display name for language
  static String getLanguageName(String code) {
    return AppConstants.supportedLanguages[code] ?? code;
  }

  /// Clear the memory and persistent cache
  Future<void> clearCache() async {
    _memoryCache.clear();
    _loadedLanguages.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('ghumify_tr_cache_')) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }
}

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);

  @override
  String toString() => message;
}
