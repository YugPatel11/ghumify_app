/// Central configuration for inter-city transport estimates in India.
/// Provides realistic tariffs, speeds, airport catalogs, and official booking portals.
class TransportConfig {
  TransportConfig._();

  static const String engineName = 'Indian Transit Fare Engine (2026)';
  static const String disclaimerText =
      'Prices and timings are approximate estimates based on distance and standard tariffs. Please verify schedules on official portals before booking.';

  // ── Train Tariffs ──
  static const double trainAvgSpeedKmH = 70.0;
  static const double trainPerKmRate = 1.60; // 3AC benchmark
  static const int trainBaseFare = 150;
  static const String trainBookingUrl = 'https://www.irctc.co.in/nget/train-search';

  // ── Bus Tariffs ──
  static const double busAvgSpeedKmH = 50.0;
  static const double busPerKmRate = 1.75; // AC Semi-Sleeper benchmark
  static const int busBaseFare = 120;
  static const String busBookingUrl = 'https://www.redbus.in/';

  // ── Car / Taxi Tariffs (Per Vehicle) ──
  static const double carAvgSpeedKmH = 65.0;
  static const double carSedanPerKmRate = 14.0;
  static const double carSuvPerKmRate = 19.0;
  static const int carSedanCapacity = 4;
  static const int carSuvCapacity = 6;
  static const String cabBookingUrl = 'https://www.uber.com/in/en/';

  // ── Flight Tariffs ──
  static const double flightMinDistanceKm = 320.0;
  static const double flightAvgSpeedKmH = 650.0;
  static const int flightAirportBufferMinutes = 150; // 2.5 hours airport security & boarding
  static const int flightBaseFare = 3500;
  static const double flightPerKmRate = 3.20;
  static const String flightBookingUrl = 'https://www.makemytrip.com/flights/';

  // ── Commercial Indian Airport Cities Catalog ──
  static const Set<String> commercialAirportCities = {
    'delhi',
    'new delhi',
    'mumbai',
    'bengaluru',
    'bangalore',
    'jaipur',
    'goa',
    'udaipur',
    'varanasi',
    'amritsar',
    'ahmedabad',
    'kolkata',
    'chennai',
    'hyderabad',
    'kochi',
    'pune',
    'chandigarh',
    'lucknow',
    'srinagar',
    'guwahati',
    'bhubaneswar',
    'indore',
    'bhopal',
    'dehradun',
    'patna',
    'coimbatore',
    'visakhapatnam',
    'surat',
    'nagpur',
    'mangalore',
    'madurai',
    'tiruchirappalli',
    'vijayawada',
    'aurangabad',
    'jodhpur',
  };

  /// Checks if a city has an operational commercial airport
  static bool hasCommercialAirport(String city) {
    final normalized = city.trim().toLowerCase();
    for (final airportCity in commercialAirportCities) {
      if (normalized.contains(airportCity) || airportCity.contains(normalized)) {
        return true;
      }
    }
    return false;
  }
}
