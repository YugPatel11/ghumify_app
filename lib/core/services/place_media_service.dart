import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place_media_model.dart';

/// Service to fetch media for a specific place dynamically.
/// Uses the free Wikimedia Commons API.
class PlaceMediaService {
  static const String _wikimediaApiUrl = 'https://commons.wikimedia.org/w/api.php';
  static final Map<String, PlaceMediaModel> _cache = {};

  /// Fetches media (images and an optional video intent URL) for a given place.
  /// [placeName] e.g., 'Hawa Mahal', 'City Palace Udaipur'
  Future<PlaceMediaModel> fetchMediaForPlace(String placeName, {String? city}) async {
    final cacheKey = '${placeName.toLowerCase().trim()}_${city?.toLowerCase().trim() ?? ''}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Clean prefix artifacts like 'Visit ', 'Explore ', 'Breakfast at ', 'Stop 1: '
    String cleanName = placeName
        .replaceAll(
            RegExp(r'^(visit|explore|tour|breakfast at|lunch at|dinner at|stop\s*\d+:?)\s+',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s*\([^)]*\)$'), '')
        .trim();
    if (cleanName.isEmpty) cleanName = placeName.trim();

    try {
      // Primary query with city
      final query = city != null && !cleanName.toLowerCase().contains(city.toLowerCase())
          ? '$cleanName $city'
          : cleanName;

      List<String> images = await _searchWikimedia(query);

      // Fallback 1: try just the cleaned place name without city
      if (images.isEmpty && city != null) {
        images = await _searchWikimedia(cleanName);
      }

      final videoUrl =
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$query tour')}';

      final model = PlaceMediaModel(
        placeName: placeName,
        images: images,
        videoUrl: images.isNotEmpty ? videoUrl : null,
        source: 'wikimedia',
      );

      _cache[cacheKey] = model;
      return model;
    } catch (_) {
      // Return empty gracefully on network or parsing error
    }

    return PlaceMediaModel.empty(placeName);
  }

  Future<List<String>> _searchWikimedia(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return [];

    try {
      final Uri url = Uri.parse(_wikimediaApiUrl).replace(queryParameters: {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': '$searchTerm filetype:bitmap',
        'gsrnamespace': '6',
        'gsrlimit': '6',
        'prop': 'imageinfo',
        'iiprop': 'url',
        'format': 'json',
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': 'GhumifyApp/1.0 (contact@ghumify.com)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        final List<String> images = [];
        if (pages != null) {
          pages.forEach((key, value) {
            final imageInfo = value['imageinfo'] as List<dynamic>?;
            if (imageInfo != null && imageInfo.isNotEmpty) {
              final urlStr = imageInfo[0]['url'] as String?;
              if (urlStr != null) {
                final path = Uri.parse(urlStr).path.toLowerCase();
                if (path.endsWith('.jpg') ||
                    path.endsWith('.jpeg') ||
                    path.endsWith('.png') ||
                    path.endsWith('.webp')) {
                  images.add(urlStr);
                }
              }
            }
          });
        }
        return images;
      }
    } catch (_) {}

    return [];
  }
}
