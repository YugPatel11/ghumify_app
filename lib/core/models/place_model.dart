import 'package:cloud_firestore/cloud_firestore.dart';

class PlaceModel {
  final String id;
  final String name;
  final String city;
  final String state;
  final String category; // heritage, temples, nature, food, markets, culture, adventure, hidden_gems
  final String description;
  final String history;
  final double latitude;
  final double longitude;
  final String? address;
  final Map<String, String> openingHours; // e.g. {"mon": "9:00-17:00", "tue": "9:00-17:00"}
  final List<String> photoUrls;
  final String? thumbnailUrl;
  final double avgVisitDurationMinutes;
  final double? rating;
  final int? reviewCount;
  final double? entryFee;
  final List<String> tags; // e.g. ["family_friendly", "photography", "wheelchair_accessible"]
  final List<String> nearbyPlaceIds;
  final String? googlePlaceId;
  final bool isHiddenGem;
  final String? specialNote; // e.g. "Best visited during sunset"
  final DateTime createdAt;

  PlaceModel({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.category,
    required this.description,
    this.history = '',
    required this.latitude,
    required this.longitude,
    this.address,
    this.openingHours = const {},
    this.photoUrls = const [],
    this.thumbnailUrl,
    this.avgVisitDurationMinutes = 60,
    this.rating,
    this.reviewCount,
    this.entryFee,
    this.tags = const [],
    this.nearbyPlaceIds = const [],
    this.googlePlaceId,
    this.isHiddenGem = false,
    this.specialNote,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PlaceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlaceModel(
      id: doc.id,
      name: data['name'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      history: data['history'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      address: data['address'],
      openingHours: Map<String, String>.from(data['openingHours'] ?? {}),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      thumbnailUrl: data['thumbnailUrl'],
      avgVisitDurationMinutes:
          (data['avgVisitDurationMinutes'] ?? 60).toDouble(),
      rating: data['rating']?.toDouble(),
      reviewCount: data['reviewCount'],
      entryFee: data['entryFee']?.toDouble(),
      tags: List<String>.from(data['tags'] ?? []),
      nearbyPlaceIds: List<String>.from(data['nearbyPlaceIds'] ?? []),
      googlePlaceId: data['googlePlaceId'],
      isHiddenGem: data['isHiddenGem'] ?? false,
      specialNote: data['specialNote'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'city': city,
      'state': state,
      'category': category,
      'description': description,
      'history': history,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'openingHours': openingHours,
      'photoUrls': photoUrls,
      'thumbnailUrl': thumbnailUrl,
      'avgVisitDurationMinutes': avgVisitDurationMinutes,
      'rating': rating,
      'reviewCount': reviewCount,
      'entryFee': entryFee,
      'tags': tags,
      'nearbyPlaceIds': nearbyPlaceIds,
      'googlePlaceId': googlePlaceId,
      'isHiddenGem': isHiddenGem,
      'specialNote': specialNote,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Creates a PlaceModel from Google Places API response
  factory PlaceModel.fromGooglePlaces(Map<String, dynamic> data, String city) {
    final location = data['geometry']?['location'] ?? {};
    final photos = data['photos'] as List? ?? [];
    
    return PlaceModel(
      id: data['place_id'] ?? '',
      name: data['name'] ?? '',
      city: city,
      state: '',
      category: _mapGoogleTypeToCategory(data['types'] as List? ?? []),
      description: data['vicinity'] ?? data['formatted_address'] ?? '',
      latitude: (location['lat'] ?? 0).toDouble(),
      longitude: (location['lng'] ?? 0).toDouble(),
      address: data['formatted_address'] ?? data['vicinity'] ?? '',
      rating: data['rating']?.toDouble(),
      reviewCount: data['user_ratings_total'],
      googlePlaceId: data['place_id'],
      photoUrls: photos
          .take(5)
          .map((p) => p['photo_reference']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  static String _mapGoogleTypeToCategory(List types) {
    final typeSet = types.map((t) => t.toString()).toSet();
    if (typeSet.intersection({'hindu_temple', 'temple', 'church', 'mosque', 'place_of_worship'}).isNotEmpty) {
      return 'temples';
    }
    if (typeSet.intersection({'museum', 'art_gallery'}).isNotEmpty) {
      return 'heritage';
    }
    if (typeSet.intersection({'park', 'natural_feature', 'campground'}).isNotEmpty) {
      return 'nature';
    }
    if (typeSet.intersection({'restaurant', 'food', 'cafe', 'bakery', 'meal_delivery', 'meal_takeaway'}).isNotEmpty) {
      return 'food';
    }
    if (typeSet.intersection({'shopping_mall', 'store', 'clothing_store', 'jewelry_store'}).isNotEmpty) {
      return 'markets';
    }
    if (typeSet.contains('tourist_attraction')) {
      return 'heritage';
    }
    return 'culture';
  }
}
