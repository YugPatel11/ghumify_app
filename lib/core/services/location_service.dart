import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Service for GPS location and reverse geocoding
class LocationService {
  /// Check and request location permissions
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current device position
  Future<Position> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) {
      throw LocationException(
        'Location permissions are denied. Please enable them in settings.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      throw LocationException('Failed to get current location: $e');
    }
  }

  /// Get city name from coordinates
  Future<String> getCityFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return place.locality ?? place.subAdministrativeArea ?? 'Unknown City';
      }
      return 'Unknown City';
    } catch (e) {
      throw LocationException('Failed to get city name: $e');
    }
  }

  /// Get coordinates from city name
  Future<Position?> getPositionFromCity(String city) async {
    try {
      final locations = await locationFromAddress('$city, India');
      if (locations.isNotEmpty) {
        return Position(
          latitude: locations.first.latitude,
          longitude: locations.first.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      return null;
    } catch (e) {
      throw LocationException('Failed to find location for "$city": $e');
    }
  }

  /// Get current city name using GPS
  Future<String> getCurrentCity() async {
    final position = await getCurrentPosition();
    return getCityFromPosition(position);
  }

  /// Calculate distance between two coordinates in km
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
        1000;
  }
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
