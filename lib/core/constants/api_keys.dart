/// API Keys Configuration
/// Replace these with your actual API keys before running the app.
class ApiKeys {
  ApiKeys._();

  /// Google Maps & Places API Key
  /// Get from: https://console.cloud.google.com/apis/credentials
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// OpenWeatherMap API Key
  /// Get from: https://openweathermap.org/api
  static const String openWeatherMapApiKey = 'YOUR_OPENWEATHERMAP_API_KEY';

  /// Google Cloud Translation API Key
  /// Get from: https://console.cloud.google.com/apis/credentials
  static const String googleTranslateApiKey = 'YOUR_GOOGLE_TRANSLATE_API_KEY';

  /// Google Gemini AI API Keys (8 keys for failover rotation)
  /// Get from: https://aistudio.google.com/app/apikey
  static const List<String> geminiApiKeys = [
    'YOUR_GEMINI_API_KEY_1',
    'YOUR_GEMINI_API_KEY_2',
    'YOUR_GEMINI_API_KEY_3',
    'YOUR_GEMINI_API_KEY_4',
    'YOUR_GEMINI_API_KEY_5',
    'YOUR_GEMINI_API_KEY_6',
    'YOUR_GEMINI_API_KEY_7',
    'YOUR_GEMINI_API_KEY_8',
  ];
}
