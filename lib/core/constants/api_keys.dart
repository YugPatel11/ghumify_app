import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Keys Configuration
/// Reads from the .env file.
class ApiKeys {
  ApiKeys._();

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
