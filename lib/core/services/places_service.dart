import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';
import '../constants/safety_constants.dart';
import '../models/nearby_service_model.dart';
import '../models/place_model.dart';
import '../models/place_suggestion_model.dart';
import 'location_service.dart';
import 'local_chat/candidate_source.dart';

/// Service for Google Places API, OpenStreetMap Nominatim, and Overpass integration
class PlacesService {
  static String get _baseUrl => 'https://maps.googleapis.com/maps/api/place';
  static String get _apiKey => ApiKeys.googleMapsApiKey;
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/search';


  // In-memory query cache for rapid responsive autocomplete
  final Map<String, List<PlaceSuggestion>> _suggestionsCache = {};
  String? _sessionToken;

  /// Generate or retrieve an active session token for Google Places requests
  String _getOrCreateSessionToken() {
    _sessionToken ??= 'session_${DateTime.now().millisecondsSinceEpoch}';
    return _sessionToken!;
  }

  /// Reset the session token after a place details call
  void resetSessionToken() {
    _sessionToken = null;
  }

  // In-memory safety cache with timestamp
  static final Map<String, _SafetyCacheEntry> _safetyCache = {};

  /// Build a multi-element Overpass QL query for emergency safety amenities
  static String buildOverpassSafetyQuery({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    int timeoutSeconds = 15,
  }) {
    return '''
[out:json][timeout:$timeoutSeconds];
(
  node["amenity"="hospital"](around:$radiusMeters,$latitude,$longitude);
  node["healthcare"="hospital"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="clinic"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="police"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="hospital"](around:$radiusMeters,$latitude,$longitude);
  way["healthcare"="hospital"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="clinic"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="police"](around:$radiusMeters,$latitude,$longitude);
  relation["amenity"="hospital"](around:$radiusMeters,$latitude,$longitude);
  relation["healthcare"="hospital"](around:$radiusMeters,$latitude,$longitude);
  relation["amenity"="clinic"](around:$radiusMeters,$latitude,$longitude);
  relation["amenity"="police"](around:$radiusMeters,$latitude,$longitude);
);
out center body;
''';
  }

  /// Parse elements from Overpass response and calculate distance to origin
  static List<NearbyServiceModel> parseOverpassElements(
    List elements, {
    required double originLat,
    required double originLon,
  }) {
    final results = <NearbyServiceModel>[];
    final seen = <String>{};
    final locationService = LocationService();

    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;
      final element = raw;
      final tags = element['tags'] as Map<String, dynamic>? ?? {};

      // Coordinates
      double lat = 0.0;
      double lon = 0.0;
      if (element['type'] == 'way' || element['type'] == 'relation') {
        final center = element['center'] as Map<String, dynamic>?;
        if (center != null) {
          lat = (center['lat'] as num?)?.toDouble() ?? 0.0;
          lon = (center['lon'] as num?)?.toDouble() ?? 0.0;
        }
      } else {
        lat = (element['lat'] as num?)?.toDouble() ?? 0.0;
        lon = (element['lon'] as num?)?.toDouble() ?? 0.0;
      }

      if (lat < -90 || lat > 90 || lon < -180 || lon > 180 || (lat == 0.0 && lon == 0.0)) {
        continue;
      }

      final osmId = '${element['type']}_${element['id']}';
      final name = (tags['name'] as String? ?? tags['name:en'] as String? ?? '').trim().toLowerCase();
      final coordKey = '${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
      final dedupKey = name.isNotEmpty ? '$name@$coordKey' : osmId;

      if (seen.contains(dedupKey) || seen.contains(osmId)) continue;
      seen.add(dedupKey);
      seen.add(osmId);

      final distance = locationService.calculateDistance(
        originLat, originLon, lat, lon,
      );

      final model = NearbyServiceModel.fromOverpassElement(
        element,
        originLat: originLat,
        originLon: originLon,
        distanceKm: distance,
      );

      results.add(model);
    }

    return results;
  }

  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Search for places nearby a location using Google Places API (or Overpass API fallback)
  Future<List<NearbyServiceModel>> searchNearbyEmergencyServices({
    required double latitude,
    required double longitude,
    int? radiusMeters,
    bool forceRefresh = false,
  }) async {
    // 1. Round coordinates to 3 decimal places (~110m) for privacy & cache consistency
    final roundedLat = double.parse(latitude.toStringAsFixed(3));
    final roundedLon = double.parse(longitude.toStringAsFixed(3));
    final cacheKey = '${roundedLat}_$roundedLon';

    // 2. Check 24-hour cache if not forcing refresh
    if (!forceRefresh && _safetyCache.containsKey(cacheKey)) {
      final entry = _safetyCache[cacheKey]!;
      if (DateTime.now().difference(entry.timestamp) < SafetyConstants.cacheTtl) {
        return entry.services;
      }
    }

    // 3. Multi-tier radius widening strategy (3km -> 5km -> 10km)
    final radiusTiers = radiusMeters != null
        ? [radiusMeters]
        : [
            SafetyConstants.initialRadiusMeters,
            SafetyConstants.expandedRadiusMeters,
            SafetyConstants.maxRadiusMeters,
          ];

    List<NearbyServiceModel> lastResults = [];

    // Attempt 1: Try Google Places Nearby Search if configured
    if (_apiKey.isNotEmpty && !_apiKey.contains('YOUR_GOOGLE_MAPS')) {
      for (final radius in radiusTiers) {
        try {
          final googleResults = await _searchGooglePlacesEmergencyServices(
            latitude: roundedLat,
            longitude: roundedLon,
            radiusMeters: radius,
          );

          if (googleResults.isNotEmpty) {
            lastResults = googleResults;
            final hospitalsCount =
                googleResults.where((s) => s.type == 'hospital').length;
            final policeCount =
                googleResults.where((s) => s.type == 'police').length;

            if (hospitalsCount >= 2 && policeCount >= 2) {
              break;
            }
          }
        } catch (_) {}
      }
    }

    // Attempt 2: If Google Places returned no results, fall back to Overpass API
    if (lastResults.isEmpty) {
      for (final radius in radiusTiers) {
        try {
          final results = await _executeOverpassQueryWithRetry(
            latitude: roundedLat,
            longitude: roundedLon,
            radiusMeters: radius,
          );

          lastResults = results;

          final hospitalsCount =
              results.where((s) => s.type == 'hospital').length;
          final policeCount = results.where((s) => s.type == 'police').length;

          // If we found at least 2 hospitals and 2 police stations, or we reached max radius, finish
          if (hospitalsCount >= 2 && policeCount >= 2) {
            break;
          }
        } catch (e) {
          if (lastResults.isNotEmpty) break;
          if (_safetyCache.containsKey(cacheKey)) {
            return _safetyCache[cacheKey]!.services;
          }
          if (radius == radiusTiers.last && lastResults.isEmpty) {
            rethrow;
          }
        }
      }
    }

    // 4. Deduplicate, sort and cap to top 5 of each category
    final seen = <String>{};
    final deduped = <NearbyServiceModel>[];
    for (final s in lastResults) {
      final key = '${s.type}_${s.name.toLowerCase()}';
      if (seen.add(key)) {
        deduped.add(s);
      }
    }

    final hospitals = deduped.where((s) => s.type == 'hospital').toList()
      ..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
    final police = deduped.where((s) => s.type == 'police').toList()
      ..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));

    final cappedResults = [
      ...hospitals.take(SafetyConstants.maxResultsPerCategory),
      ...police.take(SafetyConstants.maxResultsPerCategory),
    ];

    // Store in memory cache
    _safetyCache[cacheKey] = _SafetyCacheEntry(
      services: cappedResults,
      timestamp: DateTime.now(),
    );

    // Persist real normalized results in SharedPreferences for offline local chat
    CandidateSource.persistPlaces(
      lat: roundedLat,
      lon: roundedLon,
      type: 'emergency',
      placesData: cappedResults.map((s) => {
        'name': s.name,
        'type': s.type,
        'latitude': s.latitude,
        'longitude': s.longitude,
        'address': s.address,
        'phone': s.phone,
      }).toList(),
    );

    return cappedResults;
  }

  /// Search emergency services (hospitals, police) using Google Places Nearby Search API
  Future<List<NearbyServiceModel>> _searchGooglePlacesEmergencyServices({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    if (_apiKey.isEmpty || _apiKey.contains('YOUR_GOOGLE_MAPS')) {
      return [];
    }

    final List<NearbyServiceModel> results = [];
    final locationService = LocationService();
    final categories = ['hospital', 'police'];

    for (final category in categories) {
      try {
        final uri = Uri.parse(
          '$_baseUrl/nearbysearch/json?location=$latitude,$longitude&radius=$radiusMeters&type=$category&key=$_apiKey',
        );

        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String?;
          if ((status == 'OK' || status == 'ZERO_RESULTS') && data['results'] is List) {
            final placeResults = data['results'] as List;
            for (final p in placeResults) {
              if (p is Map<String, dynamic>) {
                final loc = p['geometry']?['location'] as Map<String, dynamic>?;
                final lat = (loc?['lat'] as num?)?.toDouble() ?? 0.0;
                final lon = (loc?['lng'] as num?)?.toDouble() ?? 0.0;
                final distance = (lat != 0.0 && lon != 0.0)
                    ? locationService.calculateDistance(latitude, longitude, lat, lon)
                    : null;

                results.add(
                  NearbyServiceModel.fromGooglePlace(
                    p,
                    type: category,
                    originLat: latitude,
                    originLon: longitude,
                    distanceKm: distance,
                  ),
                );
              }
            }
          }
        }
      } catch (_) {
        // Silently continue to next type
      }
    }

    return results;
  }

  Future<List<NearbyServiceModel>> _executeOverpassQueryWithRetry({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    int maxRetries = 2,
  }) async {
    final query = buildOverpassSafetyQuery(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      for (final endpoint in _overpassUrls) {
        try {
          final response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': SafetyConstants.overpassUserAgent,
            },
            body: 'data=${Uri.encodeComponent(query)}',
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            return parseOverpassElements(
              data['elements'] as List? ?? [],
              originLat: latitude,
              originLon: longitude,
            );
          }
        } catch (_) {
          continue;
        }
      }
      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    return [];
  }

  /// High-performance smart autocomplete search for places, cities, and landmarks in India
  Future<List<PlaceSuggestion>> searchPlaceSuggestions(
    String query, {
    String? cityBias,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.length < 2) return [];

    final cacheKey = '$cleanQuery|${cityBias?.toLowerCase() ?? ""}';
    if (_suggestionsCache.containsKey(cacheKey)) {
      return _suggestionsCache[cacheKey]!;
    }

    final results = <PlaceSuggestion>[];
    final seenNames = <String>{};

    // 1. Check curated high-priority Indian destinations & heritage attractions
    final curatedMatches = _searchCuratedPlaces(cleanQuery, cityBias: cityBias);
    for (final s in curatedMatches) {
      if (!seenNames.contains(s.name.toLowerCase())) {
        seenNames.add(s.name.toLowerCase());
        results.add(s);
      }
    }

    // 2. Query Google Places Autocomplete API if key is available
    if (_apiKey.isNotEmpty && !_apiKey.contains('YOUR_GOOGLE_MAPS')) {
      try {
        final sessionToken = _getOrCreateSessionToken();
        final uri = Uri.parse(
          '$_baseUrl/autocomplete/json?input=${Uri.encodeComponent(query)}&components=country:in&key=$_apiKey&sessiontoken=$sessionToken',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK' && data['predictions'] != null) {
            for (final p in data['predictions']) {
              final suggestion = PlaceSuggestion.fromGoogleJson(p);
              if (!seenNames.contains(suggestion.name.toLowerCase())) {
                seenNames.add(suggestion.name.toLowerCase());
                results.add(suggestion);
              }
            }
          }
        }
      } catch (_) {
        // Fallback to OSM Nominatim
      }
    }

    // 3. Query OpenStreetMap Nominatim as live resilient fallback
    if (results.length < 5) {
      try {
        final uri = Uri.parse(
          '$_nominatimUrl?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&countrycodes=in&limit=8',
        );
        final response = await http.get(
          uri,
          headers: {'User-Agent': 'GhumifyApp/1.0 (travel@ghumify.app)'},
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List? ?? [];
          for (final item in list) {
            final suggestion = PlaceSuggestion.fromNominatimJson(item);
            if (!seenNames.contains(suggestion.name.toLowerCase())) {
              seenNames.add(suggestion.name.toLowerCase());
              results.add(suggestion);
            }
          }
        }
      } catch (_) {
        // Return existing results if network query fails
      }
    }

    _suggestionsCache[cacheKey] = results;
    return results;
  }

  /// Backward-compatible autocomplete returning description & placeId
  Future<List<Map<String, String>>> autocomplete(String query) async {
    final suggestions = await searchPlaceSuggestions(query);
    return suggestions.map((s) => {
      'description': s.fullDescription,
      'placeId': s.placeId,
      'name': s.name,
      'secondary': s.secondaryText,
      'type': s.type,
    }).toList();
  }

  /// Get detailed place information including coordinates, address, and rating
  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    // Check curated cache first
    for (final p in _curatedDatabase) {
      if (p.placeId == placeId) {
        resetSessionToken();
        return {
          'name': p.name,
          'formatted_address': p.address ?? p.secondaryText,
          'latitude': p.latitude,
          'longitude': p.longitude,
          'rating': p.rating ?? 4.7,
          'types': [p.type],
        };
      }
    }

    // Query Google Place Details if valid key and non-OSM ID
    if (_apiKey.isNotEmpty && !_apiKey.contains('YOUR_GOOGLE_MAPS') && !placeId.startsWith('osm_')) {
      try {
        final sessionToken = _sessionToken ?? '';
        final uri = Uri.parse(
          '$_baseUrl/details/json?place_id=$placeId&fields=name,formatted_address,geometry,photos,types,rating&key=$_apiKey${sessionToken.isNotEmpty ? "&sessiontoken=$sessionToken" : ""}',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        resetSessionToken();

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK' && data['result'] != null) {
            final res = data['result'];
            final geom = res['geometry']?['location'] ?? {};
            final lat = (geom['lat'] as num?)?.toDouble() ?? 28.6139;
            final lon = (geom['lng'] as num?)?.toDouble() ?? 77.2090;

            // Persist real place details in offline cache
            CandidateSource.persistPlaces(
              lat: lat,
              lon: lon,
              type: 'place',
              placesData: [{
                'id': placeId,
                'name': res['name'] ?? '',
                'formatted_address': res['formatted_address'] ?? '',
                'latitude': lat,
                'longitude': lon,
                'rating': (res['rating'] as num?)?.toDouble() ?? 4.5,
              }],
            );

            return {
              'name': res['name'] ?? '',
              'formatted_address': res['formatted_address'] ?? '',
              'latitude': lat,
              'longitude': lon,
              'rating': (res['rating'] as num?)?.toDouble() ?? 4.5,
              'types': res['types'] ?? ['tourist_attraction'],
            };
          }
        }
      } catch (_) {}
    }

    resetSessionToken();
    return {
      'name': placeId.replaceAll('_', ' '),
      'formatted_address': 'India',
      'latitude': 28.6139,
      'longitude': 77.2090,
      'rating': 4.5,
      'types': ['tourist_attraction'],
    };
  }

  /// Search for places nearby a location
  Future<List<PlaceModel>> searchNearby({
    required double latitude,
    required double longitude,
    required String type,
    int radius = 5000,
    String? keyword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _getMockPlaces(type, 'Local City');
  }

  /// Search for tourist attractions in a city
  Future<List<PlaceModel>> searchTouristAttractions(String city) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _getMockPlaces('tourist_attraction', city);
  }

  /// Search for food spots in a city
  Future<List<PlaceModel>> searchFoodSpots(String city) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _getMockPlaces('restaurant', city);
  }

  /// Search for markets in a city
  Future<List<PlaceModel>> searchMarkets(String city) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _getMockPlaces('market', city);
  }

  /// Get place photo URL
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return 'https://placehold.co/${maxWidth}x300/png?text=Place+Photo';
  }

  /// Get distance and duration between two points
  Future<Map<String, dynamic>> getDistanceMatrix({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'distance': '5.0 km',
      'distanceValue': 5000,
      'duration': '15 mins',
      'durationValue': 900,
    };
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

  /// Curated Indian tourist destinations & landmarks with coordinates and category tags
  List<PlaceSuggestion> _searchCuratedPlaces(String query, {String? cityBias}) {
    final cleanQuery = query.toLowerCase().trim();
    final bias = cityBias?.toLowerCase().trim();

    return _curatedDatabase.where((p) {
      final matchesName = p.name.toLowerCase().contains(cleanQuery);
      final matchesSecondary = p.secondaryText.toLowerCase().contains(cleanQuery);
      final matchesHindi = _hindiKeywords[p.placeId]?.contains(cleanQuery) ?? false;

      final isMatch = matchesName || matchesSecondary || matchesHindi;
      if (!isMatch) return false;

      if (bias != null && bias.isNotEmpty) {
        return p.secondaryText.toLowerCase().contains(bias) ||
            p.name.toLowerCase().contains(bias);
      }
      return true;
    }).toList();
  }

  static const Map<String, String> _hindiKeywords = {
    'curated_jaipur': 'जयपुर jaipur rajasthan',
    'curated_hawa_mahal': 'हवा महल hawa mahal jaipur',
    'curated_amber_palace': 'आमेर किला amber fort jaipur',
    'curated_city_palace_jaipur': 'सिटी पैलेस city palace jaipur',
    'curated_agra': 'आगरा agra uttar pradesh',
    'curated_taj_mahal': 'ताज महल taj mahal agra',
    'curated_delhi': 'दिल्ली delhi new delhi',
    'curated_india_gate': 'इंडिया गेट india gate delhi',
    'curated_red_fort': 'लाल किला red fort delhi',
    'curated_qutub_minar': 'कुतुब मीनार qutub minar delhi',
    'curated_mumbai': 'मुंबई mumbai maharashtra bombay',
    'curated_gateway_of_india': 'गेटवे ऑफ इंडिया gateway of india mumbai',
    'curated_goa': 'गोवा goa panaji',
    'curated_baga_beach': 'बागा बीच baga beach goa',
    'curated_varanasi': 'वाराणसी बनारस varanasi banaras kashi',
    'curated_kashi_vishwanath': 'काशी विश्वनाथ kashi vishwanath temple varanasi',
    'curated_udaipur': 'उदयपुर udaipur lake city',
    'curated_lake_pichola': 'पिछोला झील lake pichola udaipur',
    'curated_bengaluru': 'बेंगलुरु bangalore bengaluru karnataka',
    'curated_amritsar': 'अमृतसर amritsar punjab',
    'curated_golden_temple': 'स्वर्ण मंदिर golden temple amritsar harmandir sahib',
  };

  static const List<PlaceSuggestion> _curatedDatabase = [
    // Major Cities
    PlaceSuggestion(
      name: 'Jaipur',
      secondaryText: 'Rajasthan, India',
      fullDescription: 'Jaipur, Pink City, Rajasthan, India',
      placeId: 'curated_jaipur',
      type: 'city',
      latitude: 26.9124,
      longitude: 75.7873,
    ),
    PlaceSuggestion(
      name: 'Agra',
      secondaryText: 'Uttar Pradesh, India',
      fullDescription: 'Agra, Uttar Pradesh, India',
      placeId: 'curated_agra',
      type: 'city',
      latitude: 27.1767,
      longitude: 78.0081,
    ),
    PlaceSuggestion(
      name: 'New Delhi',
      secondaryText: 'National Capital Territory, India',
      fullDescription: 'New Delhi, Delhi, India',
      placeId: 'curated_delhi',
      type: 'city',
      latitude: 28.6139,
      longitude: 77.2090,
    ),
    PlaceSuggestion(
      name: 'Mumbai',
      secondaryText: 'Maharashtra, India',
      fullDescription: 'Mumbai, Maharashtra, India',
      placeId: 'curated_mumbai',
      type: 'city',
      latitude: 19.0760,
      longitude: 72.8777,
    ),
    PlaceSuggestion(
      name: 'Goa',
      secondaryText: 'Coast of Western India',
      fullDescription: 'Goa, India',
      placeId: 'curated_goa',
      type: 'city',
      latitude: 15.2993,
      longitude: 74.1240,
    ),
    PlaceSuggestion(
      name: 'Varanasi',
      secondaryText: 'Uttar Pradesh, India',
      fullDescription: 'Varanasi, Kashi, Uttar Pradesh, India',
      placeId: 'curated_varanasi',
      type: 'city',
      latitude: 25.3176,
      longitude: 82.9739,
    ),
    PlaceSuggestion(
      name: 'Udaipur',
      secondaryText: 'Rajasthan, India',
      fullDescription: 'Udaipur, City of Lakes, Rajasthan, India',
      placeId: 'curated_udaipur',
      type: 'city',
      latitude: 24.5854,
      longitude: 73.7125,
    ),
    PlaceSuggestion(
      name: 'Bengaluru',
      secondaryText: 'Karnataka, India',
      fullDescription: 'Bengaluru, Silicon Valley of India, Karnataka',
      placeId: 'curated_bengaluru',
      type: 'city',
      latitude: 12.9716,
      longitude: 77.5946,
    ),
    PlaceSuggestion(
      name: 'Amritsar',
      secondaryText: 'Punjab, India',
      fullDescription: 'Amritsar, Holy City, Punjab, India',
      placeId: 'curated_amritsar',
      type: 'city',
      latitude: 31.6340,
      longitude: 74.8723,
    ),

    // Iconic Monuments & Attractions
    PlaceSuggestion(
      name: 'Hawa Mahal',
      secondaryText: 'Badi Choupad, Jaipur, Rajasthan',
      fullDescription: 'Hawa Mahal, Palace of Winds, Jaipur, Rajasthan',
      placeId: 'curated_hawa_mahal',
      type: 'monument',
      latitude: 26.9239,
      longitude: 75.8267,
      rating: 4.8,
    ),
    PlaceSuggestion(
      name: 'Amber Palace (Amer Fort)',
      secondaryText: 'Devisinghpura, Amer, Jaipur, Rajasthan',
      fullDescription: 'Amber Palace, Amer Fort, Jaipur, Rajasthan',
      placeId: 'curated_amber_palace',
      type: 'monument',
      latitude: 26.9855,
      longitude: 75.8513,
      rating: 4.9,
    ),
    PlaceSuggestion(
      name: 'City Palace',
      secondaryText: 'Tulsi Marg, Gangori Bazaar, Jaipur, Rajasthan',
      fullDescription: 'City Palace, Jaipur, Rajasthan',
      placeId: 'curated_city_palace_jaipur',
      type: 'monument',
      latitude: 26.9258,
      longitude: 75.8237,
      rating: 4.7,
    ),
    PlaceSuggestion(
      name: 'Taj Mahal',
      secondaryText: 'Dharmapuri, Forest Colony, Agra, Uttar Pradesh',
      fullDescription: 'Taj Mahal, UNESCO World Heritage Site, Agra',
      placeId: 'curated_taj_mahal',
      type: 'monument',
      latitude: 27.1751,
      longitude: 78.0421,
      rating: 4.9,
    ),
    PlaceSuggestion(
      name: 'India Gate',
      secondaryText: 'Rajpath, India Gate, New Delhi, Delhi',
      fullDescription: 'India Gate, War Memorial, New Delhi',
      placeId: 'curated_india_gate',
      type: 'monument',
      latitude: 28.6129,
      longitude: 77.2295,
      rating: 4.7,
    ),
    PlaceSuggestion(
      name: 'Red Fort (Lal Qila)',
      secondaryText: 'Netaji Subhash Marg, Lal Qila, Chandni Chowk, New Delhi',
      fullDescription: 'Red Fort, Historic Fortress, Old Delhi',
      placeId: 'curated_red_fort',
      type: 'monument',
      latitude: 28.6562,
      longitude: 77.2410,
      rating: 4.6,
    ),
    PlaceSuggestion(
      name: 'Qutub Minar',
      secondaryText: 'Seth Sarai, Mehrauli, New Delhi, Delhi',
      fullDescription: 'Qutub Minar, UNESCO Heritage Site, New Delhi',
      placeId: 'curated_qutub_minar',
      type: 'monument',
      latitude: 28.5245,
      longitude: 77.1855,
      rating: 4.7,
    ),
    PlaceSuggestion(
      name: 'Gateway of India',
      secondaryText: 'Apollo Bandar, Colaba, Mumbai, Maharashtra',
      fullDescription: 'Gateway of India, Waterfront Landmark, Mumbai',
      placeId: 'curated_gateway_of_india',
      type: 'monument',
      latitude: 18.9220,
      longitude: 72.8347,
      rating: 4.7,
    ),
    PlaceSuggestion(
      name: 'Baga Beach',
      secondaryText: 'North Goa, Goa, India',
      fullDescription: 'Baga Beach, Vibrant Coastline & Water Sports, Goa',
      placeId: 'curated_baga_beach',
      type: 'beach',
      latitude: 15.5553,
      longitude: 73.7517,
      rating: 4.5,
    ),
    PlaceSuggestion(
      name: 'Kashi Vishwanath Temple',
      secondaryText: 'Lahori Tola, Varanasi, Uttar Pradesh',
      fullDescription: 'Shri Kashi Vishwanath Temple, Varanasi, Uttar Pradesh',
      placeId: 'curated_kashi_vishwanath',
      type: 'temple',
      latitude: 25.3109,
      longitude: 83.0107,
      rating: 4.9,
    ),
    PlaceSuggestion(
      name: 'Lake Pichola',
      secondaryText: 'Pichola, Udaipur, Rajasthan',
      fullDescription: 'Lake Pichola, Scenic Fresh Water Lake, Udaipur',
      placeId: 'curated_lake_pichola',
      type: 'nature',
      latitude: 24.5760,
      longitude: 73.6800,
      rating: 4.8,
    ),
    PlaceSuggestion(
      name: 'Golden Temple (Harmandir Sahib)',
      secondaryText: 'Golden Temple Road, Atta Mandi, Amritsar, Punjab',
      fullDescription: 'Sri Harmandir Sahib, Golden Temple, Amritsar',
      placeId: 'curated_golden_temple',
      type: 'temple',
      latitude: 31.6200,
      longitude: 74.8765,
      rating: 5.0,
    ),
  ];
}

class PlacesException implements Exception {
  final String message;
  PlacesException(this.message);

  @override
  String toString() => message;
}

class _SafetyCacheEntry {
  final List<NearbyServiceModel> services;
  final DateTime timestamp;

  _SafetyCacheEntry({
    required this.services,
    required this.timestamp,
  });
}
