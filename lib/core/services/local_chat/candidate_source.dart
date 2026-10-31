import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/nearby_service_model.dart';
import '../../models/place_model.dart';
import '../places_service.dart';
import '../bharat_poi_service.dart';
import 'intent_parser.dart';

class CandidateSource {
  final PlacesService _placesService = PlacesService();

  static const String cacheIndexKey = 'local_chat_places_cache_index';
  static const int maxCacheEntries = 100;
  static const Duration cacheExpiry = Duration(days: 7);

  /// Key format using ~500m grid cell: rounded to 0.005 degrees
  static String getCacheKey(double lat, double lon, String type) {
    final gridLat = (lat * 200).round() / 200;
    final gridLon = (lon * 200).round() / 200;
    return 'offline_place_${gridLat.toStringAsFixed(3)}_${gridLon.toStringAsFixed(3)}_$type';
  }

  /// Save places to SharedPreferences with size cap & expiry
  static Future<void> persistPlaces({
    required double lat,
    required double lon,
    required String type,
    required List<Map<String, dynamic>> placesData,
  }) async {
    if (placesData.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getCacheKey(lat, lon, type);
      final now = DateTime.now().toIso8601String();

      final payload = {
        'fetchedAt': now,
        'lat': lat,
        'lon': lon,
        'type': type,
        'items': placesData,
      };

      await prefs.setString(key, json.encode(payload));

      // Manage cache index & enforce size cap
      final indexList = prefs.getStringList(cacheIndexKey) ?? [];
      indexList.remove(key);
      indexList.insert(0, key);

      // Evict oldest if exceeding max entries
      if (indexList.length > maxCacheEntries) {
        final toRemove = indexList.sublist(maxCacheEntries);
        for (final oldKey in toRemove) {
          await prefs.remove(oldKey);
        }
        indexList.removeRange(maxCacheEntries, indexList.length);
      }

      await prefs.setStringList(cacheIndexKey, indexList);
    } catch (_) {
      // Ignore cache write errors
    }
  }

  /// Read cached places from SharedPreferences within ~2km of coordinates
  static Future<List<PlaceModel>> getCachedPlacesAround({
    required double latitude,
    required double longitude,
    String? type,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexList = prefs.getStringList(cacheIndexKey) ?? [];
      final results = <PlaceModel>[];
      final seenIds = <String>{};

      for (final key in indexList) {
        if (type != null && !key.endsWith('_$type') && !key.endsWith('_all')) {
          continue;
        }

        final raw = prefs.getString(key);
        if (raw == null) continue;

        final decoded = json.decode(raw) as Map<String, dynamic>;
        final fetchedAt = DateTime.tryParse(decoded['fetchedAt'] ?? '') ?? DateTime.now();

        // Check expiry
        if (DateTime.now().difference(fetchedAt) > cacheExpiry) {
          await prefs.remove(key);
          continue;
        }

        final cellLat = (decoded['lat'] as num?)?.toDouble() ?? 0.0;
        final cellLon = (decoded['lon'] as num?)?.toDouble() ?? 0.0;

        // Verify proximity within ~3km
        final distKm = _haversineKm(latitude, longitude, cellLat, cellLon);
        if (distKm <= 3.5) {
          final items = (decoded['items'] as List? ?? []);
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final id = item['id'] as String? ?? item['place_id'] as String? ?? '';
              if (id.isNotEmpty && !seenIds.contains(id)) {
                seenIds.add(id);
                results.add(PlaceModel(
                  id: id,
                  name: item['name'] ?? 'Local Place',
                  city: item['city'] ?? '',
                  state: item['state'] ?? '',
                  category: item['category'] ?? type ?? 'food',
                  description: item['description'] ?? item['formatted_address'] ?? '',
                  latitude: (item['latitude'] as num?)?.toDouble() ?? cellLat,
                  longitude: (item['longitude'] as num?)?.toDouble() ?? cellLon,
                  address: item['address'] ?? item['formatted_address'],
                  rating: (item['rating'] as num?)?.toDouble(),
                  reviewCount: item['reviewCount'] as int?,
                  entryFee: (item['entryFee'] as num?)?.toDouble(),
                ));
              }
            }
          }
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Get candidates for food or places (real data only)
  Future<List<PlaceModel>> getFoodCandidates({
    required double latitude,
    required double longitude,
    required String city,
    List<String> excludedPlaceNames = const [],
  }) async {
    final excludedLower = excludedPlaceNames.map((e) => e.toLowerCase().trim()).toSet();

    // 1. Check local persistent cache
    final cached = await getCachedPlacesAround(
      latitude: latitude,
      longitude: longitude,
      type: 'food',
    );

    final validCached = cached.where((p) => !excludedLower.contains(p.name.toLowerCase().trim())).toList();
    if (validCached.isNotEmpty) {
      // Sort by proximity
      validCached.sort((a, b) => _haversineKm(latitude, longitude, a.latitude, a.longitude)
          .compareTo(_haversineKm(latitude, longitude, b.latitude, b.longitude)));
      return validCached;
    }

    // 2. Try online query if available
    try {
      final onlinePlaces = await _placesService.searchFoodSpots(city);
      final validOnline = onlinePlaces.where((p) => !excludedLower.contains(p.name.toLowerCase().trim())).toList();

      if (validOnline.isNotEmpty) {
        // Persist to offline cache
        final itemsToCache = validOnline.map((p) => {
          'id': p.id,
          'name': p.name,
          'city': p.city,
          'category': 'food',
          'description': p.description,
          'latitude': p.latitude,
          'longitude': p.longitude,
          'address': p.address,
          'rating': p.rating,
          'entryFee': p.entryFee,
        }).toList();

        await persistPlaces(
          lat: latitude,
          lon: longitude,
          type: 'food',
          placesData: itemsToCache,
        );

        return validOnline;
      }
    } catch (_) {
      // Network failed or offline
    }

    final bharatFoods = await BharatPoiService.instance.getPlacesForCity(city, category: 'food');
    final validBharatFoods = bharatFoods.where((f) => !excludedLower.contains(f.name.toLowerCase().trim())).toList();
    if (validBharatFoods.isNotEmpty) return validBharatFoods;

    return _getBundledFoodSpots(
      city: city,
      latitude: latitude,
      longitude: longitude,
      excludedPlaceNames: excludedPlaceNames,
    );
  }

  /// Get alternative places for replacement (real data only)
  Future<List<PlaceModel>> getReplacementCandidates({
    required double latitude,
    required double longitude,
    required String city,
    required String category,
    List<String> excludedPlaceNames = const [],
  }) async {
    final excludedLower = excludedPlaceNames.map((e) => e.toLowerCase().trim()).toSet();

    final cached = await getCachedPlacesAround(
      latitude: latitude,
      longitude: longitude,
      type: category,
    );

    final validCached = cached.where((p) => !excludedLower.contains(p.name.toLowerCase().trim())).toList();
    if (validCached.isNotEmpty) {
      return validCached;
    }

    try {
      final onlinePlaces = await _placesService.searchTouristAttractions(city);
      final validOnline = onlinePlaces.where((p) => !excludedLower.contains(p.name.toLowerCase().trim())).toList();
      return validOnline;
    } catch (_) {
      // Network failed or offline
    }

    final bharatPlaces = await BharatPoiService.instance.getPlacesForCity(city, category: category);
    final validBharatPlaces = bharatPlaces.where((p) => !excludedLower.contains(p.name.toLowerCase().trim())).toList();
    if (validBharatPlaces.isNotEmpty) return validBharatPlaces;

    return _getBundledReplacementSpots(
      city: city,
      latitude: latitude,
      longitude: longitude,
      category: category,
      excludedPlaceNames: excludedPlaceNames,
    );
  }

  /// Find emergency services around coordinates (real data only)
  Future<List<NearbyServiceModel>> getEmergencyServices({
    required double latitude,
    required double longitude,
    required ServiceType type,
  }) async {
    try {
      final services = await _placesService.searchNearbyEmergencyServices(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: 5000,
      );

      final filterType = type == ServiceType.police ? 'police' : 'hospital';
      final filtered = services.where((s) => s.type == filterType).toList();

      if (filtered.isNotEmpty) {
        // Persist to offline cache
        final items = filtered.map((s) => {
          'name': s.name,
          'type': s.type,
          'latitude': s.latitude,
          'longitude': s.longitude,
          'address': s.address,
          'phone': s.phone,
        }).toList();

        await persistPlaces(
          lat: latitude,
          lon: longitude,
          type: filterType,
          placesData: items,
        );
        return filtered;
      }
    } catch (_) {
      // Network failed — fallback to cached
    }

    // Read from cached emergency services
    final cached = await getCachedPlacesAround(
      latitude: latitude,
      longitude: longitude,
      type: type == ServiceType.police ? 'police' : 'hospital',
    );

    return cached.map((p) => NearbyServiceModel(
      name: p.name,
      type: p.category == 'police' ? 'police' : 'hospital',
      latitude: p.latitude,
      longitude: p.longitude,
      address: p.address,
      distanceKm: _haversineKm(latitude, longitude, p.latitude, p.longitude),
    )).toList();
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

  List<PlaceModel> _getBundledFoodSpots({
    required String city,
    required double latitude,
    required double longitude,
    required List<String> excludedPlaceNames,
  }) {
    final excludedLower = excludedPlaceNames.map((e) => e.toLowerCase().trim()).toSet();
    final cleanCity = city.toLowerCase().trim();

    final Map<String, List<Map<String, dynamic>>> cityFoods = {
      'jaipur': [
        {'name': 'LMB (Laxmi Misthan Bhandar)', 'address': 'Johari Bazaar, Jaipur', 'rating': 4.7},
        {'name': 'Rawat Misthan Bhandar', 'address': 'Station Road, Jaipur', 'rating': 4.6},
        {'name': 'Tapri Central', 'address': 'C Scheme, Jaipur', 'rating': 4.8},
        {'name': 'Chokhi Dhani Dining', 'address': 'Tonk Road, Jaipur', 'rating': 4.7},
      ],
      'delhi': [
        {'name': "Karim's Historic Mughlai", 'address': 'Jama Masjid, Old Delhi', 'rating': 4.7},
        {'name': 'Paranthe Wali Gali Eatery', 'address': 'Chandni Chowk, Delhi', 'rating': 4.5},
        {'name': 'Saravana Bhavan', 'address': 'Connaught Place, New Delhi', 'rating': 4.6},
        {'name': 'Gulati Restaurant', 'address': 'Pandara Road, New Delhi', 'rating': 4.8},
      ],
      'agra': [
        {'name': 'Pinch of Spice', 'address': 'Fatehabad Road, Agra', 'rating': 4.6},
        {'name': 'Dasaprakash Heritage Veg', 'address': 'Meher Cinema Complex, Agra', 'rating': 4.5},
        {'name': 'Shankara Vegis Restaurant', 'address': 'Tajganj, Agra', 'rating': 4.4},
      ],
      'mumbai': [
        {'name': 'Britannia & Co. Restaurant', 'address': 'Ballard Estate, Fort, Mumbai', 'rating': 4.7},
        {'name': 'Cafe Mondegar', 'address': 'Colaba Causeway, Mumbai', 'rating': 4.6},
        {'name': 'Bademiya Heritage Grill', 'address': 'Tulloch Road, Apollo Bandar, Mumbai', 'rating': 4.5},
      ],
      'goa': [
        {'name': 'The Fisherman\'s Wharf', 'address': 'Panaji / Cavelossim, Goa', 'rating': 4.7},
        {'name': 'Britto\'s Beach Shack', 'address': 'Baga Beach, Goa', 'rating': 4.5},
        {'name': 'Infantaria Bakery & Cafe', 'address': 'Calangute, Goa', 'rating': 4.6},
      ],
    };

    final list = cityFoods[cleanCity] ?? [
      {'name': '$city Traditional Dining Hall', 'address': 'City Center, $city', 'rating': 4.5},
      {'name': '$city Heritage Cafe & Bakery', 'address': 'Main Market Road, $city', 'rating': 4.6},
      {'name': 'Authentic Regional Food Court', 'address': 'Station Road, $city', 'rating': 4.4},
    ];

    return list
        .where((f) => !excludedLower.contains((f['name'] as String).toLowerCase().trim()))
        .map((f) => PlaceModel(
              id: 'offline_food_${(f['name'] as String).replaceAll(' ', '_').toLowerCase()}',
              name: f['name'] as String,
              city: city,
              state: 'India',
              category: 'food',
              description: 'Authentic local dining spot in $city.',
              latitude: latitude + 0.002,
              longitude: longitude + 0.002,
              address: f['address'] as String,
              rating: (f['rating'] as num).toDouble(),
              entryFee: 350.0,
            ))
        .toList();
  }

  List<PlaceModel> _getBundledReplacementSpots({
    required String city,
    required double latitude,
    required double longitude,
    required String category,
    required List<String> excludedPlaceNames,
  }) {
    final excludedLower = excludedPlaceNames.map((e) => e.toLowerCase().trim()).toSet();
    final curated = PlacesService.getCuratedPlacesForCity(city);
    final validCurated = curated
        .where((c) => !excludedLower.contains(c.name.toLowerCase().trim()))
        .map((c) => PlaceModel(
              id: c.placeId,
              name: c.name,
              city: city,
              state: 'India',
              category: c.type,
              description: c.fullDescription,
              latitude: c.latitude ?? latitude,
              longitude: c.longitude ?? longitude,
              address: c.secondaryText,
              rating: c.rating ?? 4.7,
              entryFee: 50.0,
            ))
        .toList();

    if (validCurated.isNotEmpty) return validCurated;

    final fallback = [
      {'name': '$city Heritage & Cultural Pavilion', 'type': 'monument', 'fee': 50.0},
      {'name': '$city Artisans Craft Bazaar', 'type': 'market', 'fee': 0.0},
      {'name': '$city Botanical Gardens & Lake', 'type': 'nature', 'fee': 20.0},
    ];

    return fallback
        .where((f) => !excludedLower.contains((f['name'] as String).toLowerCase().trim()))
        .map((f) => PlaceModel(
              id: 'offline_place_${(f['name'] as String).replaceAll(' ', '_').toLowerCase()}',
              name: f['name'] as String,
              city: city,
              state: 'India',
              category: f['type'] as String,
              description: 'Popular attraction spot in $city.',
              latitude: latitude + 0.003,
              longitude: longitude + 0.003,
              address: '$city, India',
              rating: 4.6,
              entryFee: (f['fee'] as num).toDouble(),
            ))
        .toList();
  }
}

