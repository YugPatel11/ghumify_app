import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';
import '../models/place_model.dart';

/// Service for Google Places API integration
class PlacesService {
  static String get _baseUrl => 'https://maps.googleapis.com/maps/api/place';
  static String get _apiKey => ApiKeys.googleMapsApiKey;

  /// Search for places nearby a location
  Future<List<PlaceModel>> searchNearby({
    required double latitude,
    required double longitude,
    required String type, // tourist_attraction, restaurant, etc.
    int radius = 5000,
    String? keyword,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return _getMockPlaces(type, 'Local City');
  }

  /// Search for tourist attractions in a city
  Future<List<PlaceModel>> searchTouristAttractions(String city) async {
    await Future.delayed(const Duration(seconds: 1));
    return _getMockPlaces('tourist_attraction', city);
  }

  /// Search for food spots in a city
  Future<List<PlaceModel>> searchFoodSpots(String city) async {
    await Future.delayed(const Duration(seconds: 1));
    return _getMockPlaces('restaurant', city);
  }

  /// Search for markets in a city
  Future<List<PlaceModel>> searchMarkets(String city) async {
    await Future.delayed(const Duration(seconds: 1));
    return _getMockPlaces('market', city);
  }

  /// Get detailed info for a specific place
  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'name': 'Mock Place $placeId',
      'formatted_address': '123 Mock Street, City, Country',
      'rating': 4.5,
      'user_ratings_total': 120,
      'formatted_phone_number': '+1 234 567 8900',
      'website': 'https://example.com',
      'types': ['tourist_attraction'],
    };
  }

  /// Autocomplete for city/place search
  Future<List<Map<String, String>>> autocomplete(String query) async {
    if (query.length < 2) return [];
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'description': '$query City, India', 'placeId': 'mock_id_1'},
      {'description': '$query District, India', 'placeId': 'mock_id_2'},
    ];
  }

  /// Get place photo URL
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    // Return a placeholder image since we don't have real photo references
    return 'https://via.placeholder.com/$maxWidth\x3Ftext=Place+Photo';
  }

  /// Get distance and duration between two points
  Future<Map<String, dynamic>> getDistanceMatrix({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'distance': '5.0 km',
      'distanceValue': 5000,
      'duration': '15 mins',
      'durationValue': 900,
    };
  }

  /// Get city name from coordinates
  Future<String> _getCityFromCoords(double lat, double lon) async {
    return 'Mock City';
  }

  /// Helper to generate mock places
  List<PlaceModel> _getMockPlaces(String type, String city) {
    return List.generate(5, (index) => PlaceModel(
      id: 'mock_place_${type}_$index',
      name: 'Mock ${type.substring(0, 1).toUpperCase() + type.substring(1)} ${index + 1}',
      category: type,
      city: city,
      state: 'Mock State',
      description: 'A wonderful $type spot in $city.',
      latitude: 28.6139 + (index * 0.01),
      longitude: 77.2090 + (index * 0.01),
      address: '${index + 1} Mock Street, $city',
      rating: 4.0 + (index * 0.1),
      reviewCount: 100 + (index * 10),
    ));
  }
}

class PlacesException implements Exception {
  final String message;
  PlacesException(this.message);

  @override
  String toString() => message;
}
