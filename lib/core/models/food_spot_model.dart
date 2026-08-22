import 'package:cloud_firestore/cloud_firestore.dart';

class FoodSpotModel {
  final String id;
  final String name;
  final String city;
  final String specialty; // e.g. "Poha Jalebi", "Bhutte ka Kees"
  final String description;
  final double latitude;
  final double longitude;
  final String? address;
  final List<String> photoUrls;
  final String? thumbnailUrl;
  final double? rating;
  final int? reviewCount;
  final String? priceRange; // "₹", "₹₹", "₹₹₹"
  final String? openingHours;
  final List<String> tags; // e.g. ["street_food", "vegetarian", "famous"]
  final bool isFamous;
  final String? googlePlaceId;
  final DateTime createdAt;

  FoodSpotModel({
    required this.id,
    required this.name,
    required this.city,
    required this.specialty,
    this.description = '',
    required this.latitude,
    required this.longitude,
    this.address,
    this.photoUrls = const [],
    this.thumbnailUrl,
    this.rating,
    this.reviewCount,
    this.priceRange,
    this.openingHours,
    this.tags = const [],
    this.isFamous = false,
    this.googlePlaceId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FoodSpotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodSpotModel(
      id: doc.id,
      name: data['name'] ?? '',
      city: data['city'] ?? '',
      specialty: data['specialty'] ?? '',
      description: data['description'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      address: data['address'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      thumbnailUrl: data['thumbnailUrl'],
      rating: data['rating']?.toDouble(),
      reviewCount: data['reviewCount'],
      priceRange: data['priceRange'],
      openingHours: data['openingHours'],
      tags: List<String>.from(data['tags'] ?? []),
      isFamous: data['isFamous'] ?? false,
      googlePlaceId: data['googlePlaceId'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'city': city,
      'specialty': specialty,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'photoUrls': photoUrls,
      'thumbnailUrl': thumbnailUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'priceRange': priceRange,
      'openingHours': openingHours,
      'tags': tags,
      'isFamous': isFamous,
      'googlePlaceId': googlePlaceId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
