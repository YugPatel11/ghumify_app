import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Service for GPS location with real geolocator
class LocationService {
  /// Check and request location permissions
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
          'Location services (GPS) are turned off. Please turn on GPS on your device.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException(
            'Location permission denied. Please allow location access to share your position.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'Location permission permanently denied. Please enable it in App Settings.');
    }

    return true;
  }

  /// Get current position (lat/lng)
  Future<Position> getCurrentPosition() async {
    await checkAndRequestPermission();

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      if (e is LocationException) rethrow;
      throw LocationException('Could not determine your GPS location. Please ensure you are outdoors or have a clear signal.');
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

  /// Resolves the route starting point following the strict fallback cascade:
  /// 1. Current GPS location (if location permission is granted)
  /// 2. User-picked start point
  /// 3. Hotel or stay location
  /// 4. City center coordinates
  Future<RouteStartPoint> resolveStartPoint({
    required String city,
    double? userPickedLat,
    double? userPickedLng,
    String? userPickedLabel,
    double? hotelLat,
    double? hotelLng,
    String? hotelLabel,
    double? cityCenterLat,
    double? cityCenterLng,
  }) async {
    final targetCityLat = cityCenterLat ?? _getKnownCityCenterLat(city);
    final targetCityLng = cityCenterLng ?? _getKnownCityCenterLng(city);

    // 1. Try GPS location (ONLY if user is actually in or near the destination city < 60 km)
    try {
      final hasPerm = await checkAndRequestPermission();
      if (hasPerm) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        // Privacy: round coordinates to 4 decimal places (~11m precision)
        final roundedLat = double.parse(pos.latitude.toStringAsFixed(4));
        final roundedLng = double.parse(pos.longitude.toStringAsFixed(4));

        bool isWithinCityArea = true;
        if (targetCityLat != null && targetCityLng != null) {
          final distFromCity = calculateDistance(roundedLat, roundedLng, targetCityLat, targetCityLng);
          // If distance > 60 km, user is in another city/state (e.g. Delhi planning Rajkot)
          if (distFromCity > 60.0) {
            isWithinCityArea = false;
          }
        }

        if (isWithinCityArea) {
          return RouteStartPoint(
            latitude: roundedLat,
            longitude: roundedLng,
            label: 'your current location',
            source: RouteStartPointSource.gps,
          );
        }
      }
    } catch (_) {
      // Graceful fallback on permission denied, timeout, or location disabled
    }

    // 2. User-picked start point
    if (userPickedLat != null && userPickedLng != null) {
      return RouteStartPoint(
        latitude: userPickedLat,
        longitude: userPickedLng,
        label: userPickedLabel ?? 'your chosen starting point',
        source: RouteStartPointSource.userPicked,
      );
    }

    // 3. Hotel or stay location
    if (hotelLat != null && hotelLng != null) {
      return RouteStartPoint(
        latitude: hotelLat,
        longitude: hotelLng,
        label: hotelLabel ?? 'your hotel/stay',
        source: RouteStartPointSource.hotel,
      );
    }

    // 4. City Center fallback
    final defaultLat = targetCityLat ?? _getKnownCityCenterLat(city);
    final defaultLng = targetCityLng ?? _getKnownCityCenterLng(city);

    return RouteStartPoint(
      latitude: defaultLat,
      longitude: defaultLng,
      label: '$city center',
      source: RouteStartPointSource.cityCenter,
    );
  }

  /// Known city center latitude fallbacks
  static double _getKnownCityCenterLat(String city) {
    final lower = city.toLowerCase().trim();
    if (lower.contains('rajkot')) return 22.3039;
    if (lower.contains('surat')) return 21.1702;
    if (lower.contains('vadodara')) return 22.3072;
    if (lower.contains('delhi')) return 28.6139;
    if (lower.contains('mumbai')) return 18.9220;
    if (lower.contains('jaipur')) return 26.9124;
    if (lower.contains('udaipur')) return 24.5854;
    if (lower.contains('goa')) return 15.2993;
    if (lower.contains('bengaluru') || lower.contains('bangalore')) return 12.9716;
    if (lower.contains('varanasi')) return 25.3176;
    if (lower.contains('agra')) return 27.1767;
    if (lower.contains('chennai')) return 13.0827;
    if (lower.contains('kolkata')) return 22.5726;
    if (lower.contains('hyderabad')) return 17.3850;
    if (lower.contains('ahmedabad')) return 23.0225;
    if (lower.contains('pune')) return 18.5204;
    if (lower.contains('amritsar')) return 31.6340;
    if (lower.contains('kochi') || lower.contains('cochin')) return 9.9312;
    if (lower.contains('chandigarh')) return 30.7333;
    return 26.9124; // General default
  }

  /// Known city center longitude fallbacks
  static double _getKnownCityCenterLng(String city) {
    final lower = city.toLowerCase().trim();
    if (lower.contains('rajkot')) return 70.8022;
    if (lower.contains('surat')) return 72.8311;
    if (lower.contains('vadodara')) return 73.1812;
    if (lower.contains('delhi')) return 77.2090;
    if (lower.contains('mumbai')) return 72.8347;
    if (lower.contains('jaipur')) return 75.7873;
    if (lower.contains('udaipur')) return 73.7125;
    if (lower.contains('goa')) return 74.1240;
    if (lower.contains('bengaluru') || lower.contains('bangalore')) return 77.5946;
    if (lower.contains('varanasi')) return 82.9739;
    if (lower.contains('agra')) return 78.0081;
    if (lower.contains('chennai')) return 80.2707;
    if (lower.contains('kolkata')) return 88.3639;
    if (lower.contains('hyderabad')) return 78.4867;
    if (lower.contains('ahmedabad')) return 72.5714;
    if (lower.contains('pune')) return 73.8567;
    if (lower.contains('amritsar')) return 74.8723;
    if (lower.contains('kochi') || lower.contains('cochin')) return 76.2673;
    if (lower.contains('chandigarh')) return 76.7794;
    return 75.7873; // General default
  }
}

enum RouteStartPointSource {
  gps,
  userPicked,
  hotel,
  cityCenter,
}

class RouteStartPoint {
  final double latitude;
  final double longitude;
  final String label;
  final RouteStartPointSource source;

  const RouteStartPoint({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.source,
  });

  String get routeMessage => 'Route starts from $label';
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
