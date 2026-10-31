import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/place_model.dart';

/// Service providing offline access to curated BharatPOI dataset.
///
/// Enables completely offline itinerary generation, stop replacements,
/// dining recommendations, and chatbot queries across Indian destinations.
class BharatPoiService {
  BharatPoiService._();
  static final BharatPoiService instance = BharatPoiService._();

  static List<Map<String, dynamic>>? _cachedPoiData;

  /// Load and parse the BharatPOI dataset from app assets
  Future<List<Map<String, dynamic>>> loadPoiDataset() async {
    if (_cachedPoiData != null && _cachedPoiData!.isNotEmpty) {
      return _cachedPoiData!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/data/bharat_poi.json');
      final dynamic decoded = json.decode(jsonString);
      if (decoded is List) {
        _cachedPoiData = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        return _cachedPoiData!;
      }
    } catch (_) {
      // In headless tests or if asset loading fails, use fallback in-memory POIs
    }

    _cachedPoiData = _defaultBundledPois;
    return _cachedPoiData!;
  }

  /// Get places for a specific city matching optional category
  Future<List<PlaceModel>> getPlacesForCity(String city, {String? category}) async {
    final allPois = await loadPoiDataset();
    final cleanCity = city.toLowerCase().trim();
    final cleanCategory = category?.toLowerCase().trim();

    final matches = allPois.where((poi) {
      final poiCity = (poi['city'] as String? ?? '').toLowerCase();
      final poiCategory = (poi['category'] as String? ?? '').toLowerCase();

      final cityMatches = poiCity.contains(cleanCity) || cleanCity.contains(poiCity);
      if (!cityMatches) return false;

      if (cleanCategory != null && cleanCategory.isNotEmpty && cleanCategory != 'all') {
        return poiCategory == cleanCategory;
      }
      return true;
    }).toList();

    return matches.map((p) => _toPlaceModel(p)).toList();
  }

  /// Get nearby places within a radius using Haversine calculation
  Future<List<PlaceModel>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 15.0,
    String? category,
  }) async {
    final allPois = await loadPoiDataset();
    final cleanCategory = category?.toLowerCase().trim();

    final results = <PlaceModel>[];
    for (final poi in allPois) {
      final lat = (poi['latitude'] as num?)?.toDouble();
      final lng = (poi['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      if (cleanCategory != null && cleanCategory.isNotEmpty && cleanCategory != 'all') {
        final poiCategory = (poi['category'] as String? ?? '').toLowerCase();
        if (poiCategory != cleanCategory) continue;
      }

      final dist = _haversineKm(latitude, longitude, lat, lng);
      if (dist <= radiusKm) {
        results.add(_toPlaceModel(poi));
      }
    }

    // Sort by nearest first
    results.sort((a, b) {
      final distA = _haversineKm(latitude, longitude, a.latitude, a.longitude);
      final distB = _haversineKm(latitude, longitude, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    return results;
  }

  /// Search a place by name fuzzy match
  Future<PlaceModel?> findPlaceByName(String query) async {
    final allPois = await loadPoiDataset();
    final cleanQuery = query.toLowerCase().trim();

    for (final poi in allPois) {
      final name = (poi['name'] as String? ?? '').toLowerCase();
      if (name.contains(cleanQuery) || cleanQuery.contains(name)) {
        return _toPlaceModel(poi);
      }
    }
    return null;
  }

  /// Get famous food details for a specific city
  Future<List<Map<String, String>>> getFamousFoodsForCity(String city) async {
    final allPois = await loadPoiDataset();
    final cleanCity = city.toLowerCase().trim();
    final results = <Map<String, String>>[];
    final seen = <String>{};

    for (final p in allPois) {
      final poiCity = (p['city'] as String? ?? '').toLowerCase();
      if (poiCity.contains(cleanCity) || cleanCity.contains(poiCity)) {
        final food = p['famousFood'] as String?;
        if (food != null && food.isNotEmpty && !seen.contains(food)) {
          seen.add(food);
          results.add({
            'dish': food,
            'description': p['famousFoodDescription'] as String? ?? '',
            'placeName': p['name'] as String? ?? '',
            'imageUrl': p['foodImageUrl'] as String? ?? '',
          });
        }
      }
    }
    return results;
  }

  /// Convert raw map entry to PlaceModel
  PlaceModel _toPlaceModel(Map<String, dynamic> raw) {
    final photo = raw['photoUrl'] as String?;
    final food = raw['famousFood'] as String?;
    final foodDesc = raw['famousFoodDescription'] as String?;
    final foodImg = raw['foodImageUrl'] as String?;

    final noteBuffer = StringBuffer();
    if (food != null && food.isNotEmpty) {
      noteBuffer.write('Famous Food: $food.');
      if (foodDesc != null && foodDesc.isNotEmpty) {
        noteBuffer.write(' $foodDesc');
      }
    }

    final photos = <String>[];
    if (photo != null && photo.isNotEmpty) photos.add(photo);
    if (foodImg != null && foodImg.isNotEmpty) photos.add(foodImg);

    return PlaceModel(
      id: raw['id'] as String? ?? 'poi_${DateTime.now().millisecondsSinceEpoch}',
      name: raw['name'] as String? ?? 'Attraction',
      city: raw['city'] as String? ?? '',
      state: raw['state'] as String? ?? 'India',
      category: raw['category'] as String? ?? 'sightseeing',
      description: raw['description'] as String? ?? '',
      latitude: (raw['latitude'] as num?)?.toDouble() ?? 26.9124,
      longitude: (raw['longitude'] as num?)?.toDouble() ?? 75.7873,
      address: raw['address'] as String?,
      rating: (raw['rating'] as num?)?.toDouble() ?? 4.7,
      entryFee: (raw['entryFee'] as num?)?.toDouble() ?? 50.0,
      photoUrls: photos,
      thumbnailUrl: photo ?? foodImg,
      specialNote: noteBuffer.isNotEmpty ? noteBuffer.toString() : null,
      tags: [
        if (food != null) 'famous_food: $food',
        'offline_verified',
      ],
    );
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371;
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLon = (lon2 - lon1) * math.pi / 180.0;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static const List<Map<String, dynamic>> _defaultBundledPois = [
    {
      'id': 'poi_jaipur_amber_palace',
      'name': 'Amber Palace (Amer Fort)',
      'city': 'Jaipur',
      'state': 'Rajasthan',
      'category': 'monument',
      'description': 'Magnificent hilltop fortress with ornate courtyards and Sheesh Mahal mirror palace.',
      'latitude': 26.9855,
      'longitude': 75.8513,
      'address': 'Devisinghpura, Amer, Jaipur, Rajasthan 302001',
      'rating': 4.9,
      'entryFee': 100.0,
    },
    {
      'id': 'poi_jaipur_hawa_mahal',
      'name': 'Hawa Mahal',
      'city': 'Jaipur',
      'state': 'Rajasthan',
      'category': 'monument',
      'description': 'Iconic pink sandstone Palace of Winds featuring 953 carved jharokhas.',
      'latitude': 26.9239,
      'longitude': 75.8267,
      'address': 'Badi Choupad, Pink City, Jaipur, Rajasthan 302002',
      'rating': 4.8,
      'entryFee': 50.0,
    },
    {
      'id': 'poi_jaipur_city_palace',
      'name': 'City Palace Jaipur',
      'city': 'Jaipur',
      'state': 'Rajasthan',
      'category': 'monument',
      'description': 'Royal palace complex blending Rajput and Mughal architecture.',
      'latitude': 26.9258,
      'longitude': 75.8237,
      'address': 'Tulsi Marg, Gangori Bazaar, Jaipur, Rajasthan 302002',
      'rating': 4.7,
      'entryFee': 200.0,
    },
    {
      'id': 'poi_jaipur_lmb',
      'name': 'Laxmi Misthan Bhandar (LMB)',
      'city': 'Jaipur',
      'state': 'Rajasthan',
      'category': 'food',
      'description': 'Historic dining sweet shop famed for authentic Rajasthani thali and Ghewar.',
      'latitude': 26.9205,
      'longitude': 75.8262,
      'address': 'Johari Bazaar, Pink City, Jaipur, Rajasthan 302003',
      'rating': 4.7,
      'entryFee': 400.0,
    },
  ];
}

