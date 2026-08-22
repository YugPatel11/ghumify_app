/// Service for GPS location and reverse geocoding (Mock Mode)
class LocationService {
  /// Check and request location permissions
  Future<bool> checkAndRequestPermission() async {
    return true; // Mock: always granted
  }

  /// Get current city name using GPS (mocked)
  Future<String> getCurrentCity() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'New Delhi'; // Mock city
  }

  /// Calculate distance between two coordinates in km
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    // Simple approximation for mock
    final dx = (endLat - startLat) * 111.0;
    final dy = (endLng - startLng) * 111.0;
    return (dx * dx + dy * dy);
  }
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
