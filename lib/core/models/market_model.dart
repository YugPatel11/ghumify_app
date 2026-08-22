import 'package:cloud_firestore/cloud_firestore.dart';

class MarketModel {
  final String id;
  final String name;
  final String city;
  final String description;
  final String? specialty; // e.g. "Traditional textiles", "Spices", "Street food"
  final double latitude;
  final double longitude;
  final String? address;
  final List<String> photoUrls;
  final String? thumbnailUrl;
  final String? openingHours;
  final String? bestTimeToVisit;
  final double? rating;
  final List<String> tags;
  final String? googlePlaceId;
  final DateTime createdAt;

  MarketModel({
    required this.id,
    required this.name,
    required this.city,
    this.description = '',
    this.specialty,
    required this.latitude,
    required this.longitude,
    this.address,
    this.photoUrls = const [],
    this.thumbnailUrl,
    this.openingHours,
    this.bestTimeToVisit,
    this.rating,
    this.tags = const [],
    this.googlePlaceId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MarketModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketModel(
      id: doc.id,
      name: data['name'] ?? '',
      city: data['city'] ?? '',
      description: data['description'] ?? '',
      specialty: data['specialty'],
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      address: data['address'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      thumbnailUrl: data['thumbnailUrl'],
      openingHours: data['openingHours'],
      bestTimeToVisit: data['bestTimeToVisit'],
      rating: data['rating']?.toDouble(),
      tags: List<String>.from(data['tags'] ?? []),
      googlePlaceId: data['googlePlaceId'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'city': city,
      'description': description,
      'specialty': specialty,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'photoUrls': photoUrls,
      'thumbnailUrl': thumbnailUrl,
      'openingHours': openingHours,
      'bestTimeToVisit': bestTimeToVisit,
      'rating': rating,
      'tags': tags,
      'googlePlaceId': googlePlaceId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
