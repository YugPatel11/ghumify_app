/// App-wide constants for Ghumify
class AppConstants {
  AppConstants._();

  // App Identity
  static const String appName = 'Ghumify';
  static const String appTagline = 'Always With You';
  static const String appDescription =
      'Your smart travel companion for exploring Indian cities';

  // Asset Paths
  static const String logoPath = 'assets/images/logo.png';

  // Supported Languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिन्दी',
    'gu': 'ગુજરાતી',
    'mr': 'मराठी',
    'bn': 'বাংলা',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'kn': 'ಕನ್ನಡ',
    'ml': 'മലയാളം',
    'pa': 'ਪੰਜਾਬੀ',
  };

  // Place Categories
  static const List<String> placeCategories = [
    'heritage',
    'temples',
    'nature',
    'food',
    'markets',
    'culture',
    'adventure',
    'hidden_gems',
  ];

  // Interest Tags (for trip planning)
  static const List<String> interestTags = [
    'Famous Places',
    'Heritage & History',
    'Temples & Spirituality',
    'Local Food',
    'Street Food',
    'Markets & Shopping',
    'Nature & Parks',
    'Cultural Experiences',
    'Adventure',
    'Hidden Gems',
    'Photography',
    'Family Friendly',
  ];

  // Travel Modes
  static const List<String> travelModes = [
    'walking',
    'driving',
    'transit',
  ];

  // Pace Preferences
  static const List<String> pacePreferences = [
    'relaxed',
    'moderate',
    'fast',
  ];

  // Firestore Collection Names
  static const String usersCollection = 'users';
  static const String placesCollection = 'places';
  static const String foodSpotsCollection = 'foodSpots';
  static const String marketsCollection = 'markets';
  static const String itinerariesCollection = 'itineraries';
  static const String eventsCollection = 'events';
  static const String translationsCollection = 'translations';
  static const String audioGuidesCollection = 'audioGuides';

  // Weather
  static const String weatherBaseUrl =
      'https://api.openweathermap.org/data/2.5';

  // Google Translate
  static const String translateBaseUrl =
      'https://translation.googleapis.com/language/translate/v2';

  // Defaults
  static const String defaultLanguage = 'en';
  static const double defaultMapZoom = 14.0;
  static const int defaultTripDurationHours = 6;
  static const int maxTripDurationHours = 16;
  static const int minTripDurationHours = 1;
}
