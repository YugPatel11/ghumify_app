import 'package:flutter/material.dart';

/// A utility to intelligently resolve destination-specific high-quality imagery.
/// It provides beautiful landmarks or representative images based on the destination name.
class ImageResolver {
  static const String _fallbackImage =
      'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Taj_Mahal_%28Edited%29.jpeg/1280px-Taj_Mahal_%28Edited%29.jpeg';

  static const Map<String, List<String>> _destinationImages = {
    'jaipur': [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Hawa_Mahal_2011.jpg/1280px-Hawa_Mahal_2011.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/Amber_Fort_and_Maota_Lake.jpg/1280px-Amber_Fort_and_Maota_Lake.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/City_Palace_Jaipur_2014.jpg/1280px-City_Palace_Jaipur_2014.jpg',
    ],
    'agra': [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Taj_Mahal_%28Edited%29.jpeg/1280px-Taj_Mahal_%28Edited%29.jpeg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Agra_Fort_Delhi_Gate.jpg/1280px-Agra_Fort_Delhi_Gate.jpg',
    ],
    'paris': [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/Tour_Eiffel_Wikimedia_Commons.jpg/1280px-Tour_Eiffel_Wikimedia_Commons.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/Louvre_Museum_Wikimedia_Commons.jpg/1280px-Louvre_Museum_Wikimedia_Commons.jpg',
    ],
    'dubai': [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Burj_Khalifa_and_Dubai_skyline.jpg/1280px-Burj_Khalifa_and_Dubai_skyline.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/Dubai_Desert_Safari.jpg/1280px-Dubai_Desert_Safari.jpg',
    ],
    'indore': [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/Rajwada_Palace%2C_Indore.jpg/1280px-Rajwada_Palace%2C_Indore.jpg',
    ],
    'delhi': [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/India_Gate_in_New_Delhi_03-2016.jpg/1280px-India_Gate_in_New_Delhi_03-2016.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Red_Fort_New_Delhi.jpg/1280px-Red_Fort_New_Delhi.jpg',
    ],
    'mumbai': [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Gateway_of_India_2021.jpg/1280px-Gateway_of_India_2021.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ae/Marine_Drive_Mumbai_from_Malabar_Hill.jpg/1280px-Marine_Drive_Mumbai_from_Malabar_Hill.jpg',
    ]
  };

  /// Get the primary hero image for a destination
  static String getHeroImage(String destination) {
    final key = destination.toLowerCase().trim();
    if (_destinationImages.containsKey(key) && _destinationImages[key]!.isNotEmpty) {
      return _destinationImages[key]!.first;
    }
    
    // Look for partial matches
    for (final mapKey in _destinationImages.keys) {
      if (key.contains(mapKey)) {
        return _destinationImages[mapKey]!.first;
      }
    }
    
    return _fallbackImage;
  }

  /// Get an alternative/secondary image for variety
  static String getSecondaryImage(String destination, {int index = 1}) {
    final key = destination.toLowerCase().trim();
    if (_destinationImages.containsKey(key)) {
      final list = _destinationImages[key]!;
      if (list.length > index) {
        return list[index];
      } else if (list.isNotEmpty) {
        return list[0]; // Fallback to first if index not found
      }
    }
    // Fallback to different generic travel images if possible
    if (index == 1) {
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Golden_Temple_India.jpg/1280px-Golden_Temple_India.jpg';
    }
    return _fallbackImage;
  }
}

