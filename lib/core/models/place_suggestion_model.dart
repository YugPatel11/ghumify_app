import 'package:flutter/material.dart';

/// Represents a place or city suggestion for autocomplete in the itinerary flow.
class PlaceSuggestion {
  final String name;
  final String secondaryText;
  final String fullDescription;
  final String placeId;
  final String type; // 'city', 'monument', 'temple', 'nature', 'beach', 'market', 'food', 'poi'
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? rating;
  final String? photoUrl;

  const PlaceSuggestion({
    required this.name,
    required this.secondaryText,
    required this.fullDescription,
    required this.placeId,
    this.type = 'poi',
    this.latitude,
    this.longitude,
    this.address,
    this.rating,
    this.photoUrl,
  });

  factory PlaceSuggestion.fromGoogleJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    final primary = structured['main_text'] as String? ?? json['description'] ?? '';
    final secondary = structured['secondary_text'] as String? ?? 'India';
    final types = (json['types'] as List?)?.map((e) => e.toString()).toList() ?? [];

    String category = 'poi';
    if (types.contains('locality') || types.contains('administrative_area_level_2')) {
      category = 'city';
    } else if (types.contains('hindu_temple') || types.contains('place_of_worship')) {
      category = 'temple';
    } else if (types.contains('tourist_attraction') || types.contains('museum')) {
      category = 'monument';
    } else if (types.contains('park') || types.contains('natural_feature')) {
      category = 'nature';
    } else if (types.contains('shopping_mall') || types.contains('market')) {
      category = 'market';
    } else if (types.contains('restaurant') || types.contains('food')) {
      category = 'food';
    }

    return PlaceSuggestion(
      name: primary,
      secondaryText: secondary,
      fullDescription: json['description'] ?? '$primary, $secondary',
      placeId: json['place_id'] ?? '',
      type: category,
    );
  }

  factory PlaceSuggestion.fromNominatimJson(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String? ?? '';
    final parts = displayName.split(',').map((e) => e.trim()).toList();
    final name = parts.isNotEmpty ? parts.first : displayName;
    final secondary = parts.length > 1 ? parts.sublist(1).take(3).join(', ') : 'India';

    final osmType = (json['type'] as String? ?? '').toLowerCase();
    final osmClass = (json['class'] as String? ?? '').toLowerCase();

    String category = 'poi';
    if (osmType == 'city' || osmType == 'administrative' || osmClass == 'place') {
      category = 'city';
    } else if (osmType == 'temple' || osmType == 'place_of_worship' || osmClass == 'amenity') {
      category = 'temple';
    } else if (osmType == 'monument' || osmType == 'historic' || osmClass == 'tourism') {
      category = 'monument';
    } else if (osmType == 'beach' || osmType == 'nature' || osmClass == 'natural') {
      category = 'nature';
    } else if (osmType == 'marketplace' || osmType == 'shop' || osmClass == 'shop') {
      category = 'market';
    } else if (osmType == 'restaurant' || osmType == 'cafe') {
      category = 'food';
    }

    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lon = double.tryParse(json['lon']?.toString() ?? '');

    return PlaceSuggestion(
      name: name,
      secondaryText: secondary,
      fullDescription: displayName,
      placeId: 'osm_${json['osm_id'] ?? DateTime.now().millisecondsSinceEpoch}',
      type: category,
      latitude: lat,
      longitude: lon,
      address: displayName,
    );
  }

  IconData get iconData {
    switch (type.toLowerCase()) {
      case 'city':
        return Icons.location_city_rounded;
      case 'monument':
        return Icons.account_balance_rounded;
      case 'temple':
        return Icons.temple_hindu_rounded;
      case 'nature':
      case 'beach':
        return Icons.park_rounded;
      case 'market':
        return Icons.shopping_bag_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  String get typeLabel {
    switch (type.toLowerCase()) {
      case 'city':
        return 'City / Destination';
      case 'monument':
        return 'Heritage & Landmark';
      case 'temple':
        return 'Temple & Spiritual';
      case 'nature':
        return 'Nature & Scenic';
      case 'beach':
        return 'Beach & Coast';
      case 'market':
        return 'Market & Bazaars';
      case 'food':
        return 'Food & Dining';
      default:
        return 'Point of Interest';
    }
  }
}
