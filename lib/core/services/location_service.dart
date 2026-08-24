import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Service for GPS location with real geolocator
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

  /// Get current position (lat/lng)
  Future<Position> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) {
      throw LocationException(
          'Location permission denied. Please enable location access in your settings.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      throw LocationException('Could not determine your location. Please try again.');
    }
  }

  /// Get current city name using GPS + reverse geocoding
  Future<String> getCurrentCity() async {
    try {
      final position = await getCurrentPosition();
      // We can't easily reverse geocode without geocoding package on web
      // Return coordinates-based description as fallback
      return 'Current Location (${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)})';
    } catch (e) {
      throw LocationException('Could not determine your city: $e');
    }
  }

  /// Calculate distance between two coordinates in km using Haversine formula
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double earthRadius = 6371.0; // km
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(startLat)) *
            cos(_toRadians(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
