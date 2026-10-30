/// Constants and configuration for Nearby Safety (Hospitals & Police Stations)
class SafetyConstants {
  /// OpenStreetMap attribution string
  static const String osmAttribution = '© OpenStreetMap contributors';
  static const String osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

  /// Standard User-Agent header for Overpass API requests
  static const String overpassUserAgent =
      'GhumifyApp/1.0 (Travel Companion; contact@ghumify.app)';

  /// Emergency contact numbers (India standard)
  static const String nationalEmergencyNumber = '112';
  static const String policeEmergencyNumber = '100';
  static const String ambulanceEmergencyNumber = '108';
  static const String womenHelplineNumber = '1091';

  /// Emergency disclaimer text
  static const String emergencyDisclaimer =
      'Data comes from OpenStreetMap and may be incomplete or out of date. '
      'In an emergency, call your local emergency number.';

  /// Overpass cache duration (24 hours)
  static const Duration cacheTtl = Duration(hours: 24);

  /// Radius search tiers in meters
  static const int initialRadiusMeters = 3000; // 3 km
  static const int expandedRadiusMeters = 5000; // 5 km
  static const int maxRadiusMeters = 10000; // 10 km

  /// Result caps
  static const int maxResultsPerCategory = 5;
}
