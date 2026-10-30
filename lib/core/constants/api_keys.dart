import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Keys Configuration
/// Reads from the .env file.
class ApiKeys {
  ApiKeys._();

  /// Feature flag for backend AI Router (default: false)
  static bool get aiRouterEnabled =>
      (dotenv.env['AI_ROUTER_ENABLED'] ?? 'false').toLowerCase() == 'true';

  /// Backend Base URL for router (default: http://10.0.2.2:3000)
  static String get backendBaseUrl =>
      dotenv.env['BACKEND_BASE_URL'] ?? 'http://10.0.2.2:3000';

  /// Feature flag for local rule-based chat fallback (default: false)
  static bool get localChatFallbackEnabled =>
      (dotenv.env['LOCAL_CHAT_FALLBACK_ENABLED'] ?? 'false').toLowerCase() == 'true';

  /// Developer-only flag to force local chat tier (default: false, ignored if fallback disabled)
  static bool get forceLocalChat =>
      localChatFallbackEnabled &&
      (dotenv.env['FORCE_LOCAL_CHAT'] ?? 'false').toLowerCase() == 'true';

  /// Google Maps & Places API Key
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'YOUR_GOOGLE_MAPS_API_KEY';

  /// OpenWeatherMap API Key
  static String get openWeatherMapApiKey => dotenv.env['OPENWEATHERMAP_API_KEY'] ?? 'YOUR_OPENWEATHERMAP_API_KEY';

  /// Google Cloud Translation API Key
  static String get googleTranslateApiKey => dotenv.env['GOOGLE_TRANSLATE_API_KEY'] ?? 'YOUR_GOOGLE_TRANSLATE_API_KEY';

  /// Google Gemini AI API Keys (8 keys for failover rotation)
  static List<String> get geminiApiKeys => [
    dotenv.env['GEMINI_API_KEY_1'] ?? '',
    dotenv.env['GEMINI_API_KEY_2'] ?? '',
    dotenv.env['GEMINI_API_KEY_3'] ?? '',
    dotenv.env['GEMINI_API_KEY_4'] ?? '',
    dotenv.env['GEMINI_API_KEY_5'] ?? '',
    dotenv.env['GEMINI_API_KEY_6'] ?? '',
    dotenv.env['GEMINI_API_KEY_7'] ?? '',
    dotenv.env['GEMINI_API_KEY_8'] ?? '',
  ].where((key) => key.isNotEmpty).toList();
}
