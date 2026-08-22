import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';
import '../models/place_model.dart';

/// Service for Google Places API integration
class PlacesService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place';
  static const String _apiKey = ApiKeys.googleMapsApiKey;

  /// Search for places nearby a location
  Future<List<PlaceModel>> searchNearby({
    required double latitude,
    required double longitude,
    required String type, // tourist_attraction, restaurant, etc.
    int radius = 5000,
    String? keyword,
  }) async {
    try {
      var url = '$_baseUrl/nearbysearch/json'
          '?location=$latitude,$longitude'
          '&radius=$radius'
          '&type=$type'
          '&key=$_apiKey';

      if (keyword != null && keyword.isNotEmpty) {
        url += '&keyword=${Uri.encodeComponent(keyword)}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          // Get city name from reverse geocode
          final city = await _getCityFromCoords(latitude, longitude);
          return results
              .map((r) => PlaceModel.fromGooglePlaces(
                  r as Map<String, dynamic>, city))
              .toList();
        }
        return [];
      } else {
        throw PlacesException(
          'Places search failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is PlacesException) rethrow;
      throw PlacesException('Network error searching places: $e');
    }
  }

  /// Search for tourist attractions in a city
  Future<List<PlaceModel>> searchTouristAttractions(String city) async {
    try {
      final url = '$_baseUrl/textsearch/json'
          '?query=tourist+attractions+in+${Uri.encodeComponent(city)}'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((r) => PlaceModel.fromGooglePlaces(
                  r as Map<String, dynamic>, city))
              .toList();
        }
        return [];
      } else {
        throw PlacesException(
          'Text search failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is PlacesException) rethrow;
      throw PlacesException('Network error searching attractions: $e');
    }
  }

  /// Search for food spots in a city
  Future<List<PlaceModel>> searchFoodSpots(String city) async {
    try {
      final url = '$_baseUrl/textsearch/json'
          '?query=famous+food+places+in+${Uri.encodeComponent(city)}'
          '&type=restaurant'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((r) => PlaceModel.fromGooglePlaces(
                  r as Map<String, dynamic>, city))
              .toList();
        }
        return [];
      } else {
        throw PlacesException(
          'Food search failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is PlacesException) rethrow;
      throw PlacesException('Network error searching food: $e');
    }
  }

  /// Search for markets in a city
  Future<List<PlaceModel>> searchMarkets(String city) async {
    try {
      final url = '$_baseUrl/textsearch/json'
          '?query=famous+markets+bazaar+in+${Uri.encodeComponent(city)}'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((r) => PlaceModel.fromGooglePlaces(
                  r as Map<String, dynamic>, city))
              .toList();
        }
        return [];
      } else {
        throw PlacesException(
          'Market search failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is PlacesException) rethrow;
      throw PlacesException('Network error searching markets: $e');
    }
  }

  /// Get detailed info for a specific place
  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    try {
      final url = '$_baseUrl/details/json'
          '?place_id=$placeId'
          '&fields=name,formatted_address,geometry,rating,user_ratings_total,'
          'photos,opening_hours,formatted_phone_number,website,reviews,'
          'types,editorial_summary'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data['result'] as Map<String, dynamic>;
        }
        throw PlacesException('Place details not found');
      } else {
        throw PlacesException(
          'Place details failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is PlacesException) rethrow;
      throw PlacesException('Network error getting place details: $e');
    }
  }

  /// Autocomplete for city/place search
  Future<List<Map<String, String>>> autocomplete(String query) async {
    if (query.length < 2) return [];

    try {
      final url = '$_baseUrl/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&types=(cities)'
          '&components=country:in'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((p) {
            return {
              'description': p['description'] as String,
              'placeId': p['place_id'] as String,
            };
          }).toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get place photo URL
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/photo'
        '?maxwidth=$maxWidth'
        '&photo_reference=$photoReference'
        '&key=$_apiKey';
  }

  /// Get distance and duration between two points
  Future<Map<String, dynamic>> getDistanceMatrix({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=$originLat,$originLng'
          '&destinations=$destLat,$destLng'
          '&mode=$mode'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final element = data['rows'][0]['elements'][0];
          return {
            'distance': element['distance']?['text'] ?? 'N/A',
            'distanceValue': element['distance']?['value'] ?? 0,
            'duration': element['duration']?['text'] ?? 'N/A',
            'durationValue': element['duration']?['value'] ?? 0,
          };
        }
      }
      return {
        'distance': 'N/A',
        'distanceValue': 0,
        'duration': 'N/A',
        'durationValue': 0,
      };
    } catch (e) {
      return {
        'distance': 'N/A',
        'distanceValue': 0,
        'duration': 'N/A',
        'durationValue': 0,
      };
    }
  }

  /// Get city name from coordinates
  Future<String> _getCityFromCoords(double lat, double lon) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=$lat,$lon'
          '&result_type=locality'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final components =
              data['results'][0]['address_components'] as List;
          for (final comp in components) {
            final types = comp['types'] as List;
            if (types.contains('locality')) {
              return comp['long_name'] as String;
            }
          }
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}

class PlacesException implements Exception {
  final String message;
  PlacesException(this.message);

  @override
  String toString() => message;
}
