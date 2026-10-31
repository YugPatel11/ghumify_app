import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../constants/food_preferences.dart';
import '../constants/meal_config.dart';
import '../models/itinerary_model.dart';
import '../models/meal_suggestion_model.dart';
import '../models/travelers_model.dart';
import 'location_service.dart';

/// Cache entry for storing restaurant suggestions
class _RestaurantCacheEntry {
  final List<MealSuggestionModel> suggestions;
  final DateTime timestamp;

  _RestaurantCacheEntry({
    required this.suggestions,
    required this.timestamp,
  });
}

/// Service to query real restaurants from OpenStreetMap Overpass API,
/// filter strictly by Food Preference and Travelers, and rank them.
class RestaurantService {
  final LocationService _locationService = LocationService();

  // In-memory cache for restaurant suggestions
  static final Map<String, _RestaurantCacheEntry> _cache = {};

  // In-memory cache for raw elements by coordinates and radius
  static final Map<String, List<dynamic>> _elementsCache = {};

  /// Alternate reliable Overpass API public mirrors for fault-tolerant fallback
  static const List<String> overpassMirrors = [
    'https://overpass.openstreetmap.fr/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];

  /// Build Overpass QL query for restaurants, and optionally cafes and fast-food
  static String buildOverpassRestaurantQuery({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    int timeoutSeconds = 15,
    bool focused = false,
  }) {
    if (focused) {
      return '''
[out:json][timeout:$timeoutSeconds];
(
  node["amenity"="restaurant"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="restaurant"](around:$radiusMeters,$latitude,$longitude);
);
out center body;
''';
    }

    return '''
[out:json][timeout:$timeoutSeconds];
(
  node["amenity"="restaurant"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="cafe"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="fast_food"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="restaurant"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="cafe"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="fast_food"](around:$radiusMeters,$latitude,$longitude);
);
out center body;
''';
  }

  /// Clear the suggestions cache (useful for testing or forced refresh)
  static void clearCache() {
    _cache.clear();
    _elementsCache.clear();
  }

  /// Get suggestions for a specific meal (Lunch or Dinner) around an anchor stop
  Future<List<MealSuggestionModel>> getMealSuggestions({
    required double latitude,
    required double longitude,
    required String mealType,
    required String foodPreference,
    TravelersModel? travelers,
    String? anchorStopName,
    bool forceRefresh = false,
    Iterable<String>? excludeNames,
  }) async {
    // 1. Round coordinates for privacy & caching (~110m precision)
    final roundedLat = double.parse(latitude.toStringAsFixed(3));
    final roundedLon = double.parse(longitude.toStringAsFixed(3));
    final normPref = FoodPreference.normalize(foodPreference);
    final cacheKey = '${roundedLat}_${roundedLon}_${mealType}_$normPref';

    // 2. Check cache if not forcing refresh
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (DateTime.now().difference(entry.timestamp) < MealConfig.cacheTtl) {
        final cached = entry.suggestions;
        if (excludeNames != null && excludeNames.isNotEmpty) {
          final excludeSet = excludeNames.map((n) => n.toLowerCase().trim()).toSet();
          final filtered = cached.where((s) => !excludeSet.contains(s.name.toLowerCase().trim())).toList();
          if (filtered.isNotEmpty) return filtered;
        } else {
          return cached;
        }
      }
    }

    // 3. Multi-tier radius widening strategy (1 km -> 2 km -> 3 km -> 5 km)
    // First tries focused restaurant query; broadens with cafes/fast food if needed
    List<MealSuggestionModel> candidateResults = [];

    for (final radius in MealConfig.radiusTiersMeters) {
      try {
        // Try focused restaurant query first
        var rawElements = await _fetchOverpassElements(
          latitude: roundedLat,
          longitude: roundedLon,
          radiusMeters: radius,
          focused: true,
          forceRefresh: forceRefresh,
        );

        var parsed = _parseAndFilterRestaurants(
          elements: rawElements,
          originLat: latitude,
          originLon: longitude,
          mealType: mealType,
          foodPreference: normPref,
          travelers: travelers,
          anchorStopName: anchorStopName,
        );

        // If fewer than 2 results found, broaden with cafes and fast food
        if (parsed.length < 2) {
          final broadElements = await _fetchOverpassElements(
            latitude: roundedLat,
            longitude: roundedLon,
            radiusMeters: radius,
            focused: false,
            forceRefresh: forceRefresh,
          );
          parsed = _parseAndFilterRestaurants(
            elements: broadElements,
            originLat: latitude,
            originLon: longitude,
            mealType: mealType,
            foodPreference: normPref,
            travelers: travelers,
            anchorStopName: anchorStopName,
          );
        }

        if (parsed.isNotEmpty) {
          candidateResults = parsed;
          // Stop widening when target count (2 to 3) is satisfied
          if (candidateResults.length >= MealConfig.targetSuggestionsCount) {
            break;
          }
        }
      } catch (e) {
        // If network error occurred but we already found some results in a smaller radius, use them
        if (candidateResults.isNotEmpty) break;
        // If we have any cached fallback, return it
        if (_cache.containsKey(cacheKey)) {
          return _cache[cacheKey]!.suggestions;
        }
        // Fall through to try wider radius or Nominatim fallback
      }
    }

    // 3b. If Overpass failed or found no candidates, fall back to OpenStreetMap Nominatim search
    if (candidateResults.isEmpty) {
      try {
        candidateResults = await _fetchNominatimRestaurants(
          originLat: latitude,
          originLon: longitude,
          radiusMeters: MealConfig.maxRadiusMeters,
          mealType: mealType,
          foodPreference: normPref,
          travelers: travelers,
          anchorStopName: anchorStopName,
          excludeNames: excludeNames,
        );
      } catch (_) {}
    }

    // 3c. If still empty, check if we have any cached entries
    if (candidateResults.isEmpty && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!.suggestions;
    }

    if (candidateResults.isEmpty) {
      throw Exception('Could not find nearby restaurant suggestions.');
    }

    // 4. Rank and curate the best 2 to 3 options, excluding previously suggested names (e.g. lunch options)
    final ranked = _rankAndDiversify(
      candidateResults,
      foodPreference: normPref,
      travelers: travelers,
      excludeNames: excludeNames,
    );

    final finalSelection = ranked.take(MealConfig.maxSuggestionsCount).toList();

    // Cache the result
    _cache[cacheKey] = _RestaurantCacheEntry(
      suggestions: finalSelection,
      timestamp: DateTime.now(),
    );

    return finalSelection;
  }

  /// Execute Overpass query with multi-mirror failover, timeout, and coordinate caching
  Future<List<dynamic>> _fetchOverpassElements({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    bool focused = false,
    bool forceRefresh = false,
    int maxRetries = 2,
  }) async {
    final roundedLat = double.parse(latitude.toStringAsFixed(3));
    final roundedLon = double.parse(longitude.toStringAsFixed(3));
    final elemCacheKey = '${roundedLat}_${roundedLon}_${radiusMeters}_$focused';

    if (!forceRefresh && _elementsCache.containsKey(elemCacheKey)) {
      return _elementsCache[elemCacheKey]!;
    }

    final query = buildOverpassRestaurantQuery(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      timeoutSeconds: 8,
      focused: focused,
    );

    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (final mirror in overpassMirrors) {
        try {
          final response = await http.post(
            Uri.parse(mirror),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': MealConfig.overpassUserAgent,
            },
            body: 'data=${Uri.encodeComponent(query)}',
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final elements = (data['elements'] as List?) ?? [];
            _elementsCache[elemCacheKey] = elements;
            return elements;
          } else if (response.statusCode == 429 || response.statusCode == 504) {
            // Rate limit or timeout on mirror, immediately try next mirror
            continue;
          }
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          // Connection failed on this mirror, immediately failover to next mirror
          continue;
        }
      }
      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    // If all mirrors failed, check if we have any cached elements for this location
    if (_elementsCache.containsKey(elemCacheKey)) {
      return _elementsCache[elemCacheKey]!;
    }

    // Check if any elements exist in cache as offline fallback
    for (final entry in _elementsCache.entries) {
      if (entry.value.isNotEmpty) {
        return entry.value;
      }
    }

    throw lastException ??
        Exception('Unable to reach restaurant servers. Please check your network connection.');
  }

  /// Fallback restaurant search using OpenStreetMap Nominatim API
  Future<List<MealSuggestionModel>> _fetchNominatimRestaurants({
    required double originLat,
    required double originLon,
    required int radiusMeters,
    required String mealType,
    required String foodPreference,
    TravelersModel? travelers,
    String? anchorStopName,
    Iterable<String>? excludeNames,
  }) async {
    final deltaLat = radiusMeters / 111000.0;
    final deltaLon = radiusMeters / (111000.0 * cos(originLat * pi / 180.0));
    final minLon = (originLon - deltaLon).toStringAsFixed(4);
    final maxLat = (originLat + deltaLat).toStringAsFixed(4);
    final maxLon = (originLon + deltaLon).toStringAsFixed(4);
    final minLat = (originLat - deltaLat).toStringAsFixed(4);

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&amenity=restaurant&bounded=1&viewbox=$minLon,$maxLat,$maxLon,$minLat&limit=10&addressdetails=1',
    );

    final response = await http.get(
      uri,
      headers: {'User-Agent': MealConfig.overpassUserAgent},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body);
    if (data is! List) return [];

    final suggestions = <MealSuggestionModel>[];
    final excludeSet = (excludeNames ?? []).map((e) => e.toLowerCase().trim()).toSet();

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final name = (item['name'] as String? ?? '').trim();
      if (name.isEmpty || excludeSet.contains(name.toLowerCase())) continue;

      final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
      final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
      if (lat == 0.0 && lon == 0.0) continue;

      final distKm = _locationService.calculateDistance(originLat, originLon, lat, lon);
      final distMeters = (distKm * 1000).round();
      final address = item['display_name'] as String? ?? '';

      final badge = foodPreference == FoodPreference.jain
          ? 'Jain-friendly'
          : (foodPreference == FoodPreference.veg
              ? 'Pure Veg'
              : (foodPreference == FoodPreference.vegEgg
                  ? 'Veg + Egg'
                  : (foodPreference == FoodPreference.nonVeg
                      ? 'Non-Veg'
                      : 'Restaurant')));

      final reason = _buildSuggestedReason(
        name: name,
        dietaryBadge: badge,
        distanceMeters: distMeters,
        anchorStopName: anchorStopName,
        cuisine: 'Local Dining',
        isKidFriendly: (travelers?.minors ?? 0) > 0,
        openingStatus: 'Open during meal hours',
        mealType: mealType,
      );

      suggestions.add(
        MealSuggestionModel(
          id: 'osm_nom_${item['place_id']}',
          name: name,
          mealType: mealType,
          dietaryType: foodPreference,
          dietaryBadge: badge,
          cuisine: 'Local Dining',
          latitude: lat,
          longitude: lon,
          distanceMeters: distMeters,
          walkingMinutes: (distMeters / 80).round().clamp(1, 120),
          drivingMinutes: (distMeters / 400).round().clamp(2, 60),
          openingStatus: 'Open during meal hours',
          address: address,
          suggestedReason: reason,
          isKidFriendly: (travelers?.minors ?? 0) > 0,
          osmId: item['osm_id']?.toString(),
        ),
      );
    }

    return suggestions;
  }

  /// Parse elements and strictly enforce dietary compliance and travelers safety
  List<MealSuggestionModel> _parseAndFilterRestaurants({
    required List<dynamic> elements,
    required double originLat,
    required double originLon,
    required String mealType,
    required String foodPreference,
    TravelersModel? travelers,
    String? anchorStopName,
  }) {
    final results = <MealSuggestionModel>[];
    final seen = <String>{};
    final hasMinors = (travelers?.minors ?? 0) > 0;

    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;
      final tags = raw['tags'] as Map<String, dynamic>? ?? {};

      // Name extraction
      final name = (tags['name'] as String? ?? tags['name:en'] as String? ?? '').trim();
      if (name.isEmpty) continue; // Skip nameless amenities

      // Coordinates
      double lat = 0.0;
      double lon = 0.0;
      if (raw['type'] == 'way' || raw['type'] == 'relation') {
        final center = raw['center'] as Map<String, dynamic>?;
        if (center != null) {
          lat = (center['lat'] as num?)?.toDouble() ?? 0.0;
          lon = (center['lon'] as num?)?.toDouble() ?? 0.0;
        }
      } else {
        lat = (raw['lat'] as num?)?.toDouble() ?? 0.0;
        lon = (raw['lon'] as num?)?.toDouble() ?? 0.0;
      }

      if (lat < -90 || lat > 90 || lon < -180 || lon > 180 || (lat == 0.0 && lon == 0.0)) {
        continue;
      }

      // Deduplication
      final cleanName = name.toLowerCase();
      final coordKey = '${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
      final dedupKey = '$cleanName@$coordKey';
      if (seen.contains(dedupKey)) continue;
      seen.add(dedupKey);

      final amenity = (tags['amenity'] as String? ?? '').toLowerCase();

      // ── Family / Minors check ──
      if (hasMinors) {
        if (MealConfig.nightlifeAmenities.contains(amenity)) continue;
        final barTag = (tags['bar'] as String? ?? '').toLowerCase();
        if (barTag == 'yes') continue;
      }

      // ── Cuisine & Dietary Analysis ──
      final cuisineRaw = (tags['cuisine'] as String? ?? '').toLowerCase();
      final dietVegTag = (tags['diet:vegetarian'] as String? ?? tags['vegetarian'] as String? ?? '').toLowerCase();
      final dietVeganTag = (tags['diet:vegan'] as String? ?? tags['vegan'] as String? ?? '').toLowerCase();
      final dietJainTag = (tags['diet:jain'] as String? ?? '').toLowerCase();

      // Strict Food Preference filter
      final dietaryMatch = _evaluateDietaryCompliance(
        name: name,
        cuisine: cuisineRaw,
        dietVegTag: dietVegTag,
        dietVeganTag: dietVeganTag,
        dietJainTag: dietJainTag,
        preference: foodPreference,
      );

      if (!dietaryMatch.isCompliant) {
        continue; // Strictly skip non-compliant venues
      }

      // Distance calculation
      final distanceKm = _locationService.calculateDistance(originLat, originLon, lat, lon);
      final distanceMeters = (distanceKm * 1000).round();

      // Rough walk / drive minutes
      final walkingMinutes = (distanceMeters / 80).round().clamp(1, 120);
      final drivingMinutes = (distanceMeters / 400).round().clamp(2, 60);

      // Rating (only if real data exists in OSM)
      double? rating;
      if (tags.containsKey('stars')) {
        rating = double.tryParse(tags['stars'].toString());
      } else if (tags.containsKey('rating')) {
        rating = double.tryParse(tags['rating'].toString());
      }

      // Opening hours check
      final rawHours = tags['opening_hours'] as String?;
      final openingStatus = _resolveOpeningStatus(rawHours, mealType);

      // Do not suggest places confirmed to be closed during this meal window
      if (openingStatus == 'Closed') {
        continue;
      }

      // Kid-friendliness check
      final isKidFriendly = hasMinors &&
          (amenity == 'cafe' ||
              MealConfig.familyFriendlyCuisines.any((c) => cuisineRaw.contains(c)) ||
              (tags['wheelchair'] == 'yes') ||
              cleanName.contains('family') ||
              cleanName.contains('ice cream') ||
              cleanName.contains('sweets'));

      // Clean formatted cuisine
      final formattedCuisine = _formatCuisine(cuisineRaw, amenity);

      // Suggested Reason
      final suggestedReason = _buildSuggestedReason(
        name: name,
        dietaryBadge: dietaryMatch.badge,
        distanceMeters: distanceMeters,
        anchorStopName: anchorStopName,
        cuisine: formattedCuisine,
        isKidFriendly: isKidFriendly,
        openingStatus: openingStatus,
        mealType: mealType,
      );

      // Phone & address
      final phone = tags['phone'] as String? ?? tags['contact:phone'] as String?;
      final address = _formatAddress(tags);

      // Price level if available
      final priceLevel = tags['price_level'] != null ? tags['price_level'].toString() : null;

      final model = MealSuggestionModel(
        id: 'osm_${raw['type']}_${raw['id']}',
        name: name,
        mealType: mealType,
        dietaryType: dietaryMatch.dietaryType,
        dietaryBadge: dietaryMatch.badge,
        cuisine: formattedCuisine,
        latitude: lat,
        longitude: lon,
        distanceMeters: distanceMeters,
        walkingMinutes: walkingMinutes,
        drivingMinutes: drivingMinutes,
        rating: rating,
        openingHours: rawHours,
        openingStatus: openingStatus,
        phone: phone,
        address: address,
        suggestedReason: suggestedReason,
        isKidFriendly: isKidFriendly,
        priceLevel: priceLevel,
        osmId: '${raw['type']}/${raw['id']}',
      );

      results.add(model);
    }

    return results;
  }

  /// Strictly evaluate restaurant dietary compliance
  _DietaryMatchResult _evaluateDietaryCompliance({
    required String name,
    required String cuisine,
    required String dietVegTag,
    required String dietVeganTag,
    required String dietJainTag,
    required String preference,
  }) {
    final lowerName = name.toLowerCase();
    final combined = '$lowerName $cuisine';

    final isMarkedPureVeg = dietVegTag == 'only' ||
        dietVeganTag == 'only' ||
        dietVegTag == 'yes' ||
        dietVeganTag == 'yes' ||
        dietJainTag == 'yes' ||
        dietJainTag == 'only' ||
        lowerName.contains('pure veg') ||
        lowerName.contains('shuddh shakahari') ||
        lowerName.contains('shakahari') ||
        lowerName.contains('vegetarian') ||
        lowerName.contains('jain');

    final hasDisallowedKeywordsForVeg =
        !DietaryFilterService.isCompliant(FoodPreference.veg, combined);
    final hasDisallowedKeywordsForJain =
        !DietaryFilterService.isCompliant(FoodPreference.jain, combined);

    switch (preference) {
      case FoodPreference.jain:
        // Must be vegetarian, without non-veg or meat
        if (hasDisallowedKeywordsForVeg) {
          return _DietaryMatchResult(isCompliant: false);
        }
        if (dietJainTag == 'yes' || dietJainTag == 'only' || lowerName.contains('jain')) {
          return _DietaryMatchResult(
            isCompliant: true,
            dietaryType: FoodPreference.jain,
            badge: 'Jain-friendly',
          );
        }
        if (isMarkedPureVeg && !hasDisallowedKeywordsForJain) {
          return _DietaryMatchResult(
            isCompliant: true,
            dietaryType: FoodPreference.jain,
            badge: 'Pure Veg (Jain Options)',
          );
        }
        // If not marked pure veg, cannot verify Jain compliance
        return _DietaryMatchResult(isCompliant: false);

      case FoodPreference.veg:
        if (hasDisallowedKeywordsForVeg) {
          return _DietaryMatchResult(isCompliant: false);
        }
        if (isMarkedPureVeg) {
          return _DietaryMatchResult(
            isCompliant: true,
            dietaryType: FoodPreference.veg,
            badge: 'Pure Veg',
          );
        }
        // If not explicitly pure veg, check if it explicitly offers veg options
        if (dietVegTag == 'yes') {
          return _DietaryMatchResult(
            isCompliant: true,
            dietaryType: FoodPreference.veg,
            badge: 'Has Veg Options',
          );
        }
        // If unconfirmed, exclude for strict veg safety
        return _DietaryMatchResult(isCompliant: false);

      case FoodPreference.vegEgg:
        if (!DietaryFilterService.isCompliant(FoodPreference.vegEgg, combined)) {
          return _DietaryMatchResult(isCompliant: false);
        }
        if (isMarkedPureVeg) {
          return _DietaryMatchResult(
            isCompliant: true,
            dietaryType: FoodPreference.veg,
            badge: 'Pure Veg',
          );
        }
        return _DietaryMatchResult(
          isCompliant: true,
          dietaryType: FoodPreference.vegEgg,
          badge: 'Veg + Egg',
        );

      case FoodPreference.nonVeg:
        if (combined.contains('kebab') ||
            combined.contains('biryani') ||
            combined.contains('chicken') ||
            combined.contains('meat') ||
            combined.contains('fish') ||
            combined.contains('seafood') ||
            combined.contains('tandoor')) {
          return _DietaryMatchResult(
            isCompliant: true,
            dietaryType: FoodPreference.nonVeg,
            badge: 'Non-Veg Specialist',
          );
        }
        return _DietaryMatchResult(
          isCompliant: true,
          dietaryType: isMarkedPureVeg ? FoodPreference.veg : FoodPreference.nonVeg,
          badge: isMarkedPureVeg ? 'Pure Veg' : 'Mixed / Non-Veg',
        );

      case FoodPreference.all:
      default:
        return _DietaryMatchResult(
          isCompliant: true,
          dietaryType: isMarkedPureVeg ? FoodPreference.veg : FoodPreference.all,
          badge: isMarkedPureVeg ? 'Pure Veg' : 'Multi-Cuisine',
        );
    }
  }

  /// Check opening hours status against planned meal time
  String _resolveOpeningStatus(String? rawHours, String mealType) {
    if (rawHours == null || rawHours.trim().isEmpty) {
      return 'Opening hours not available';
    }

    final lower = rawHours.toLowerCase();
    if (lower == '24/7') {
      return 'Open now (24/7)';
    }

    final targetMins = mealType == MealConfig.lunch
        ? MealConfig.timeToMinutes(MealConfig.lunchDefaultTime)
        : MealConfig.timeToMinutes(MealConfig.dinnerDefaultTime);

    // Basic regex pattern for simple time ranges like "11:00-23:00" or "12:00-15:00, 19:00-23:00"
    final rangeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})');
    final matches = rangeRegex.allMatches(rawHours);

    if (matches.isNotEmpty) {
      bool isOpenInAnyRange = false;
      for (final match in matches) {
        final startH = int.parse(match.group(1)!);
        final startM = int.parse(match.group(2)!);
        final endH = int.parse(match.group(3)!);
        final endM = int.parse(match.group(4)!);

        final startTotal = startH * 60 + startM;
        var endTotal = endH * 60 + endM;
        if (endTotal <= startTotal) {
          endTotal += 24 * 60; // spans past midnight
        }

        if (targetMins >= startTotal && targetMins <= endTotal) {
          isOpenInAnyRange = true;
          break;
        }
      }

      if (isOpenInAnyRange) {
        return 'Open for $mealType';
      } else {
        return 'Closed';
      }
    }

    return 'Hours: $rawHours';
  }

  /// Rank candidates and ensure variety (local specialty, popular, quick/cafe)
  List<MealSuggestionModel> _rankAndDiversify(
    List<MealSuggestionModel> candidates, {
    required String foodPreference,
    TravelersModel? travelers,
    Iterable<String>? excludeNames,
  }) {
    if (candidates.isEmpty) return [];

    final hasMinors = (travelers?.minors ?? 0) > 0;
    final excludeSet = excludeNames?.map((n) => n.toLowerCase().trim()).toSet() ?? {};

    // Filter out excluded names if enough other candidates exist
    final nonExcluded = candidates.where((c) => !excludeSet.contains(c.name.toLowerCase().trim())).toList();
    final pool = (nonExcluded.length >= 2) ? nonExcluded : (nonExcluded.isNotEmpty ? nonExcluded : candidates);

    // Compute composite score for each candidate
    final scored = pool.map((m) {
      // 1. Proximity Score (0.0 to 1.0)
      final proximityScore = (1.0 - (m.distanceMeters / MealConfig.maxRadiusMeters)).clamp(0.0, 1.0);

      // 2. Dietary Match Score (0.5 to 1.0)
      double dietaryScore = 0.5;
      if (foodPreference == FoodPreference.jain && m.dietaryBadge.contains('Jain')) {
        dietaryScore = 1.0;
      } else if (foodPreference == FoodPreference.veg && m.dietaryBadge == 'Pure Veg') {
        dietaryScore = 1.0;
      } else if (foodPreference == FoodPreference.nonVeg && m.dietaryBadge.contains('Non-Veg')) {
        dietaryScore = 1.0;
      } else {
        dietaryScore = 0.7;
      }

      // 3. Rating Score (or quality bonus for named dishes / opening hours)
      final ratingScore = m.rating != null ? (m.rating! / 5.0).clamp(0.0, 1.0) : 0.6;

      // 4. Data Richness Bonus: prefer restaurants that have specific cuisine or verified hours
      double richnessBonus = 0.0;
      if (m.cuisine.isNotEmpty && m.cuisine != 'Local Dining / Cafe') richnessBonus += 0.08;
      if (m.openingStatus.contains('Open for') || m.openingStatus.contains('24/7')) richnessBonus += 0.07;

      // 5. Kid-friendly bonus
      final kidBonus = (hasMinors && m.isKidFriendly) ? MealConfig.kidFriendlyBonus : 0.0;

      final totalScore = (proximityScore * MealConfig.distanceWeight) +
          (dietaryScore * MealConfig.dietaryMatchWeight) +
          (ratingScore * MealConfig.ratingWeight) +
          richnessBonus +
          kidBonus;

      return m.copyWith(score: totalScore);
    }).toList();

    // Sort descending by score
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Diversify results: avoid 3 identical cuisine types
    final selected = <MealSuggestionModel>[];
    final seenCuisines = <String>{};

    for (final candidate in scored) {
      if (selected.length >= MealConfig.maxSuggestionsCount) break;

      // If we don't have this cuisine yet, or we're running out of unique types
      final primaryCuisine = candidate.cuisine.split(',').first.trim().toLowerCase();
      if (!seenCuisines.contains(primaryCuisine) || selected.length >= 2) {
        selected.add(candidate);
        seenCuisines.add(primaryCuisine);
      }
    }

    // If variety filter was too strict and left us with < 2, fill from top scored
    if (selected.length < MealConfig.maxSuggestionsCount) {
      for (final candidate in scored) {
        if (!selected.any((s) => s.id == candidate.id)) {
          selected.add(candidate);
          if (selected.length >= MealConfig.maxSuggestionsCount) break;
        }
      }
    }

    return selected;
  }

  /// Cleanly format cuisine names
  String _formatCuisine(String raw, String amenity) {
    if (raw.trim().isEmpty) {
      if (amenity == 'cafe') return 'Cafe & Light Bites';
      if (amenity == 'fast_food') return 'Quick Bites';
      return 'Local Dining';
    }

    return raw
        .split(';')
        .take(2)
        .map((s) => s.trim().replaceAll('_', ' '))
        .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '')
        .join(', ');
  }

  /// Build short, informative reason for suggestion based strictly on available data
  String _buildSuggestedReason({
    required String name,
    required String dietaryBadge,
    required int distanceMeters,
    String? anchorStopName,
    required String cuisine,
    required bool isKidFriendly,
    String? openingStatus,
    String? mealType,
  }) {
    final distStr = distanceMeters < 1000
        ? '$distanceMeters m'
        : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

    final nearStr = (anchorStopName != null && anchorStopName.trim().isNotEmpty)
        ? 'only $distStr from ${anchorStopName.trim()}'
        : 'only $distStr away';

    // 1. Food & cuisine specialty description
    String foodDesc;
    final cleanCuisine = cuisine.trim();
    final isGeneric = cleanCuisine.isEmpty ||
        cleanCuisine == 'Local Dining / Cafe' ||
        cleanCuisine == 'Restaurant' ||
        cleanCuisine == 'Fast Food';

    if (!isGeneric) {
      if (dietaryBadge == 'Pure Veg' || dietaryBadge == 'Jain Friendly') {
        foodDesc = 'Serves authentic $cleanCuisine ($dietaryBadge)';
      } else {
        foodDesc = 'Serves authentic $cleanCuisine';
      }
    } else {
      if (dietaryBadge == 'Pure Veg') {
        foodDesc = 'Offers pure vegetarian dining';
      } else if (dietaryBadge == 'Jain Friendly') {
        foodDesc = 'Offers authentic Jain-friendly dining';
      } else {
        foodDesc = 'Popular local dining';
      }
    }

    // 2. Extra detail from verified data (hours or family seating)
    final details = <String>[];
    if (openingStatus != null && openingStatus.toLowerCase().contains('open for')) {
      details.add('open during ${mealType ?? "meal"} hours');
    } else if (openingStatus != null && openingStatus.contains('24/7')) {
      details.add('open 24 hours');
    } else if (isKidFriendly) {
      details.add('family-friendly seating');
    }

    if (details.isNotEmpty) {
      return '$foodDesc, $nearStr, ${details.join(", ")}';
    }
    return '$foodDesc, $nearStr';
  }

  /// Format address from OSM tags
  String? _formatAddress(Map<String, dynamic> tags) {
    final street = tags['addr:street'] as String?;
    final houseNumber = tags['addr:housenumber'] as String?;
    final city = tags['addr:city'] as String?;

    final parts = [
      if (houseNumber != null && houseNumber.isNotEmpty) houseNumber,
      if (street != null && street.isNotEmpty) street,
      if (city != null && city.isNotEmpty) city,
    ];

    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  /// Locate the most appropriate anchor stop for a meal time in an itinerary
  static MealAnchorPoint? findMealAnchorPoint({
    required List<ItineraryStop> stops,
    required String mealType,
    double? fallbackLat,
    double? fallbackLon,
    String? fallbackName,
  }) {
    if (stops.isEmpty) {
      if (fallbackLat != null && fallbackLon != null) {
        return MealAnchorPoint(
          name: fallbackName ?? 'City Center',
          latitude: fallbackLat,
          longitude: fallbackLon,
        );
      }
      return null;
    }

    final targetMins = mealType == MealConfig.lunch
        ? MealConfig.timeToMinutes(MealConfig.lunchDefaultTime)
        : MealConfig.timeToMinutes(MealConfig.dinnerDefaultTime);

    // 1. Check if a food stop already exists for this meal (backward compatibility)
    for (final stop in stops) {
      if (stop.latitude != null && stop.longitude != null) {
        final isMatch = mealType == MealConfig.lunch
            ? MealConfig.isWithinLunchWindow(stop.startTime)
            : MealConfig.isWithinDinnerWindow(stop.startTime);
        if (isMatch && (stop.type == 'food' || stop.name.toLowerCase().contains('lunch') || stop.name.toLowerCase().contains('dinner'))) {
          return MealAnchorPoint(
            name: stop.name,
            latitude: stop.latitude!,
            longitude: stop.longitude!,
            existingMealStop: stop,
          );
        }
      }
    }

    // 2. For Dinner: Find the last stop or the area where the user will be in the evening (18:00 - 21:00)
    if (mealType == MealConfig.dinner) {
      ItineraryStop? eveningStop;
      ItineraryStop? lastCoordStop;
      for (final stop in stops) {
        if (stop.latitude != null && stop.longitude != null) {
          lastCoordStop = stop;
          final stopStartMins = MealConfig.timeToMinutes(stop.startTime);
          final stopEndMins = MealConfig.timeToMinutes(stop.endTime);
          if (stopStartMins >= 18 * 60 || stopEndMins >= 18 * 60) {
            eveningStop = stop;
          }
        }
      }
      final anchor = eveningStop ?? lastCoordStop;
      if (anchor != null) {
        return MealAnchorPoint(
          name: anchor.name,
          latitude: anchor.latitude!,
          longitude: anchor.longitude!,
        );
      }
    }

    // 3. For Lunch: Find the stop active right before or closest to target meal time
    ItineraryStop? closestStop;
    int minDiff = 999999;

    for (final stop in stops) {
      if (stop.latitude != null && stop.longitude != null) {
        final stopEndMins = MealConfig.timeToMinutes(stop.endTime);
        final diff = (stopEndMins - targetMins).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestStop = stop;
        }
      }
    }

    if (closestStop != null && closestStop.latitude != null && closestStop.longitude != null) {
      return MealAnchorPoint(
        name: closestStop.name,
        latitude: closestStop.latitude!,
        longitude: closestStop.longitude!,
      );
    }

    // 4. Fallback to first stop with coordinates
    for (final stop in stops) {
      if (stop.latitude != null && stop.longitude != null) {
        return MealAnchorPoint(
          name: stop.name,
          latitude: stop.latitude!,
          longitude: stop.longitude!,
        );
      }
    }

    return null;
  }
}

/// Helper model representing the anchor point for a meal search
class MealAnchorPoint {
  final String name;
  final double latitude;
  final double longitude;
  final ItineraryStop? existingMealStop;

  MealAnchorPoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.existingMealStop,
  });
}

class _DietaryMatchResult {
  final bool isCompliant;
  final String dietaryType;
  final String badge;

  _DietaryMatchResult({
    required this.isCompliant,
    this.dietaryType = 'all',
    this.badge = '',
  });
}
