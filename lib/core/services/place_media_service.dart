import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place_media_model.dart';

/// Service to fetch media for a specific place dynamically.
/// Uses the free Wikimedia Commons API.
class PlaceMediaService {
  static const String _wikimediaApiUrl = 'https://commons.wikimedia.org/w/api.php';

  /// Fetches media (images and an optional video intent URL) for a given place.
  /// [placeName] e.g., 'Hawa Mahal', 'City Palace Udaipur'
  Future<PlaceMediaModel> fetchMediaForPlace(String placeName, {String? city}) async {
    try {
      final query = city != null && !placeName.toLowerCase().contains(city.toLowerCase())
          ? '$placeName $city'
          : placeName;

      // Ensure we don't query empty strings
      if (query.trim().isEmpty) return PlaceMediaModel.empty(placeName);

      // Wikimedia API parameters to search for images
      final Uri url = Uri.parse(_wikimediaApiUrl).replace(queryParameters: {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': '$query filetype:bitmap',
        'gsrnamespace': '6', // File namespace
        'gsrlimit': '5',     // Fetch up to 5 images
        'prop': 'imageinfo',
        'iiprop': 'url',
        'format': 'json',
      });

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        List<String> images = [];

        if (pages != null) {
          pages.forEach((key, value) {
            final imageInfo = value['imageinfo'] as List<dynamic>?;
            if (imageInfo != null && imageInfo.isNotEmpty) {
              final url = imageInfo[0]['url'] as String?;
              // Filter out icons, logos, and tiny images by checking extensions
              if (url != null &&
                  (url.toLowerCase().endsWith('.jpg') || 
                   url.toLowerCase().endsWith('.jpeg') || 
                   url.toLowerCase().endsWith('.png'))) {
                images.add(url);
              }
            }
          });
        }

        // We use an intent URL for videos as they are robust and high quality
        // without requiring an embedded player or API key for YouTube Data API.
        final videoUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$query tour')}';

        return PlaceMediaModel(
          placeName: placeName,
          images: images,
          videoUrl: images.isNotEmpty ? videoUrl : null, // Only show video if it's a valid place with images
          source: 'wikimedia',
        );
      }
    } catch (e) {
      // Return empty gracefully on network or parsing error
      print('Error fetching media for $placeName: $e');
    }

    return PlaceMediaModel.empty(placeName);
  }
}
