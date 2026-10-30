/// Central configuration for itinerary meal suggestions (Lunch & Dinner)
class MealConfig {
  // ── Meal Types ──
  static const String lunch = 'lunch';
  static const String dinner = 'dinner';

  // ── Meal Windows ──
  // Lunch: 12:30 to 14:30
  static const String lunchStartTime = '12:30';
  static const String lunchEndTime = '14:30';
  static const String lunchDefaultTime = '13:00';
  static const int lunchDefaultDurationMinutes = 75;

  // Dinner: 19:00 to 21:00 (earlier if minors present)
  static const String dinnerStartTime = '19:00';
  static const String dinnerEndTime = '21:00';
  static const String dinnerDefaultTime = '19:30';
  static const String dinnerEarlyDefaultTime = '19:00';
  static const int dinnerDefaultDurationMinutes = 90;

  // ── Search Radii (in meters) ──
  // Starts at 1 km, then expands up to 5 km if few results are found
  static const List<int> radiusTiersMeters = [1000, 2000, 3000, 5000];
  static const int initialRadiusMeters = 1000;
  static const int maxRadiusMeters = 5000;

  // ── Results Limits ──
  static const int targetSuggestionsCount = 3;
  static const int minSuggestionsCount = 1;
  static const int maxSuggestionsCount = 3;

  // ── Caching ──
  static const Duration cacheTtl = Duration(hours: 6);

  // ── OSM / Overpass Settings ──
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const String overpassUserAgent =
      'GhumifyApp/1.0 (https://github.com/YugPatel11/ghumify_app; meal-suggestions)';
  static const String osmAttribution = '© OpenStreetMap contributors';
  static const String disclaimer =
      'Restaurant details may change. Please check opening hours and menu before you go.';

  // ── Kids / Family Protection ──
  static const List<String> nightlifeAmenities = [
    'bar',
    'pub',
    'nightclub',
    'biergarten',
    'hookah_lounge',
  ];

  static const List<String> familyFriendlyCuisines = [
    'family',
    'ice_cream',
    'dessert',
    'pizza',
    'bakery',
    'cafe',
    'indian',
    'thali',
    'south_indian',
    'dosa',
  ];

  // ── Scoring Weights ──
  static const double distanceWeight = 0.35;
  static const double dietaryMatchWeight = 0.35;
  static const double ratingWeight = 0.15;
  static const double varietyWeight = 0.15;
  static const double kidFriendlyBonus = 0.20;

  /// Helper to convert "HH:mm" time string into minutes since midnight
  static int timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1].split(' ')[0]);
        return hours * 60 + minutes;
      }
    } catch (_) {}
    return 0;
  }

  /// Helper to format minutes since midnight into "HH:mm"
  static String minutesToTime(int totalMinutes) {
    final clamped = totalMinutes.clamp(0, 24 * 60 - 1);
    final hours = clamped ~/ 60;
    final mins = clamped % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Check if a time string falls within the lunch window
  static bool isWithinLunchWindow(String timeStr) {
    final mins = timeToMinutes(timeStr);
    return mins >= timeToMinutes(lunchStartTime) && mins <= timeToMinutes(lunchEndTime);
  }

  /// Check if a time string falls within the dinner window
  static bool isWithinDinnerWindow(String timeStr) {
    final mins = timeToMinutes(timeStr);
    return mins >= timeToMinutes(dinnerStartTime) && mins <= timeToMinutes(dinnerEndTime);
  }
}
