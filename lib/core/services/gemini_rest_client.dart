import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';

/// Task types that determine which Gemini model to use
enum GeminiTaskType {
  /// Complex multi-day itinerary planning, deep reasoning
  complexPlanning,

  /// Fast single modifications, quick edits
  fastModification,

  /// Conversational chat responses
  chat,

  /// General travel questions, place info
  generalQuestion,

  /// Place history/descriptions
  placeInfo,

  /// Translation
  translation,
}

/// Configuration for a Gemini model with fallbacks
class _ModelConfig {
  final List<String> models;
  final double temperature;
  final int maxOutputTokens;

  const _ModelConfig({
    required this.models,
    this.temperature = 0.7,
    this.maxOutputTokens = 8192,
  });
}

/// Direct REST API client for Google Gemini.
///
/// Uses HTTP calls to the generativelanguage.googleapis.com endpoint,
/// giving access to any model (2.5, 3.x) without needing firebase_ai
/// or the deprecated google_generative_ai package.
class GeminiRestClient {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  int _currentKeyIndex = 0;

  /// Model configurations per task type — using VERIFIED available models
  static const Map<GeminiTaskType, _ModelConfig> _taskModels = {
    GeminiTaskType.complexPlanning: _ModelConfig(
      models: [
        'gemini-3.7-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-2.5-flash',
        'gemini-flash-latest',
        'gemini-pro-latest',
      ],
      temperature: 0.6,
      maxOutputTokens: 16384,
    ),
    GeminiTaskType.fastModification: _ModelConfig(
      models: [
        'gemini-3.7-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-2.5-flash',
      ],
      temperature: 0.5,
      maxOutputTokens: 8192,
    ),
    GeminiTaskType.chat: _ModelConfig(
      models: [
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-2.5-flash',
      ],
      temperature: 0.8,
      maxOutputTokens: 4096,
    ),
    GeminiTaskType.generalQuestion: _ModelConfig(
      models: [
        'gemini-3.5-flash',
        'gemini-2.5-flash',
      ],
      temperature: 0.7,
      maxOutputTokens: 2048,
    ),
    GeminiTaskType.placeInfo: _ModelConfig(
      models: [
        'gemini-3.5-flash',
        'gemini-2.5-flash',
      ],
      temperature: 0.8,
      maxOutputTokens: 1024,
    ),
    GeminiTaskType.translation: _ModelConfig(
      models: [
        'gemini-3.5-flash',
        'gemini-2.5-flash',
      ],
      temperature: 0.3,
      maxOutputTokens: 2048,
    ),
  };

  /// Generate content with automatic model fallback and API key rotation.
  Future<String> generateContent({
    required String prompt,
    required GeminiTaskType taskType,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final config = _taskModels[taskType]!;
    final apiKeys = ApiKeys.geminiApiKeys;

    if (apiKeys.isEmpty) {
      throw GeminiRestException('No Gemini API keys configured.');
    }

    final errors = <String>[];
    bool hasAuthError = false;
    bool hasRateLimitError = false;
    bool hasServerError = false;
    bool hasModelError = false;

    // Try each model in the fallback chain
    for (final modelName in config.models) {
      // Try each API key for this model
      for (int i = 0; i < apiKeys.length; i++) {
        final keyIndex = (_currentKeyIndex + i) % apiKeys.length;
        final apiKey = apiKeys[keyIndex];

        if (apiKey.isEmpty || apiKey.startsWith('YOUR_')) continue;

        try {
          final result = await _callApi(
            model: modelName,
            apiKey: apiKey,
            prompt: prompt,
            temperature: config.temperature,
            maxOutputTokens: config.maxOutputTokens,
            conversationHistory: conversationHistory,
          );

          // Success — advance key index for next call (round-robin)
          _currentKeyIndex = (keyIndex + 1) % apiKeys.length;
          return result;
        } on GeminiRateLimitException catch (_) {
          errors.add('[$modelName key#$keyIndex] 429 Rate limited');
          hasRateLimitError = true;
          continue; // Rate limited — try next key immediately
        } on GeminiAuthException catch (_) {
          errors.add('[$modelName key#$keyIndex] 401/403 Auth error');
          hasAuthError = true;
          continue; // Bad key — try next key
        } on GeminiModelNotFoundException catch (_) {
          errors.add('[$modelName] 404 Model not found');
          hasModelError = true;
          break; // Model doesn't exist — skip to next model entirely
        } on GeminiServerException catch (e) {
          errors.add('[$modelName] 5xx Server error: ${e.message}');
          hasServerError = true;
          continue; // Server error - try next key
        } catch (e) {
          errors.add('[$modelName key#$keyIndex] Error: $e');
          continue;
        }
      }
    }

    // Determine the most appropriate error to throw based on what failed
    if (hasAuthError) {
      throw GeminiRestException(
        'There is a problem with the API keys configuration. Please check your keys or billing status.',
      );
    } else if (hasRateLimitError) {
      throw GeminiRestException(
        'The AI service is currently overloaded (Rate Limit Exceeded). Please try again in a moment.',
      );
    } else if (hasServerError) {
      throw GeminiRestException(
        'The AI service is temporarily unavailable (Server Error). Please try again later.',
      );
    } else if (hasModelError) {
      throw GeminiRestException(
        'Failed to find a supported AI model. Please update the application.',
      );
    } else {
      throw GeminiRestException(
        'Failed to generate content. Please try again.\n\nDiagnostics:\n${errors.join('\n')}',
      );
    }
  }

  /// Make a direct REST API call to the Gemini endpoint
  Future<String> _callApi({
    required String model,
    required String apiKey,
    required String prompt,
    required double temperature,
    required int maxOutputTokens,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/$model:generateContent?key=$apiKey',
    );

    final List<Map<String, dynamic>> contents = [];

    if (conversationHistory != null) {
      for (final msg in conversationHistory) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg['content'] ?? ''}
          ],
        });
      }
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxOutputTokens,
        'topP': 0.95,
        'topK': 40,
      },
    });

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String? ?? '';
        }
      }
      throw GeminiRestException('Empty response from model $model');
    } else if (response.statusCode == 429) {
      throw GeminiRateLimitException('Rate limit exceeded for $model');
    } else if (response.statusCode == 404) {
      throw GeminiModelNotFoundException('Model $model not found (404)');
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw GeminiAuthException('Auth error for $model');
    } else if (response.statusCode >= 500) {
      throw GeminiServerException('Server error ${response.statusCode} for $model');
    } else {
      final errorBody = response.body;
      throw GeminiRestException('API error ${response.statusCode} for $model: $errorBody');
    }
  }
}

// ── Exception Types ──

class GeminiRestException implements Exception {
  final String message;
  GeminiRestException(this.message);

  @override
  String toString() => message;
}

class GeminiRateLimitException extends GeminiRestException {
  GeminiRateLimitException(super.message);
}

class GeminiModelNotFoundException extends GeminiRestException {
  GeminiModelNotFoundException(super.message);
}

class GeminiAuthException extends GeminiRestException {
  GeminiAuthException(super.message);
}

class GeminiServerException extends GeminiRestException {
  GeminiServerException(super.message);
}
