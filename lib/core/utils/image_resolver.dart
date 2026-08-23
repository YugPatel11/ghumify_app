import 'package:flutter/material.dart';

/// A utility to intelligently resolve destination-specific high-quality imagery.
/// It provides beautiful landmarks or representative images based on the destination name.
class ImageResolver {
  static const String _fallbackImage =
      'https://images.unsplash.com/photo-1506929562872-bb421503ef21?q=80&w=2868&auto=format&fit=crop'; // Beautiful generic travel landscape

  static const Map<String, List<String>> _destinationImages = {
    'jaipur': [
      'https://images.unsplash.com/photo-1599661046289-e31897846140?q=80&w=2827&auto=format&fit=crop', // Hawa Mahal
      'https://images.unsplash.com/photo-1571536802807-30451e3955d8?q=80&w=2787&auto=format&fit=crop', // Amer Fort
      'https://images.unsplash.com/photo-1599827552599-2f3f334f6bb2?q=80&w=2803&auto=format&fit=crop', // City Palace
    ],
    'agra': [
      'https://images.unsplash.com/photo-1564507592208-528711542977?q=80&w=2800&auto=format&fit=crop', // Taj Mahal
      'https://images.unsplash.com/photo-1585506942812-e72b29cef752?q=80&w=2728&auto=format&fit=crop', // Agra Fort
    ],
    'paris': [
      'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?q=80&w=2920&auto=format&fit=crop', // Eiffel Tower
      'https://images.unsplash.com/photo-1502602898657-3e907fa3a286?q=80&w=2942&auto=format&fit=crop', // Louvre
    ],
    'dubai': [
      'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?q=80&w=2940&auto=format&fit=crop', // Burj Khalifa
      'https://images.unsplash.com/photo-1518684079-3c830dcef090?q=80&w=2787&auto=format&fit=crop', // Desert
    ],
    'indore': [
      'https://images.unsplash.com/photo-1623833917406-fcbb3d37ec00?q=80&w=2920&auto=format&fit=crop', // Rajwada Palace (Placeholder using general Indian palace)
    ],
    'delhi': [
      'https://images.unsplash.com/photo-1587474260584-136574528ed5?q=80&w=2940&auto=format&fit=crop', // India Gate
      'https://images.unsplash.com/photo-1565017042079-0db79fc40d34?q=80&w=2787&auto=format&fit=crop', // Red Fort
    ],
    'mumbai': [
      'https://images.unsplash.com/photo-1529253355930-ddbe423a2ac7?q=80&w=2865&auto=format&fit=crop', // Gateway of India
      'https://images.unsplash.com/photo-1570168007204-dfb528c6858f?q=80&w=2805&auto=format&fit=crop', // Marine Drive
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
      return 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?q=80&w=2940&auto=format&fit=crop';
    }
    return _fallbackImage;
  }
}
