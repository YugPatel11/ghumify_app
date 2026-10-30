import '../constants/meal_config.dart';

/// Represents a single recommended restaurant for lunch or dinner
class MealSuggestionModel {
  final String id;
  final String name;
  final String mealType; // 'lunch' or 'dinner'
  final String dietaryType; // 'veg', 'veg_egg', 'jain', 'non_veg', 'all'
  final String dietaryBadge; // 'Pure Veg', 'Jain-friendly', 'Has Veg Options', 'Non-Veg'
  final String cuisine;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final int? walkingMinutes;
  final int? drivingMinutes;
  final double? rating;
  final int? reviewCount;
  final String? priceLevel; // '₹', '₹₹', '₹₹₹', or null
  final String? openingHours; // raw opening hours text if present
  final String openingStatus; // 'Open now', 'Closed', 'Opening hours not available', etc.
  final String? phone;
  final String? address;
  final String suggestedReason;
  final bool isKidFriendly;
  final double score;
  final String? osmId;
  final DateTime fetchedAt;

  MealSuggestionModel({
    required this.id,
    required this.name,
    required this.mealType,
    required this.dietaryType,
    required this.dietaryBadge,
    this.cuisine = 'Local Dining',
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.walkingMinutes,
    this.drivingMinutes,
    this.rating,
    this.reviewCount,
    this.priceLevel,
    this.openingHours,
    this.openingStatus = 'Opening hours not available',
    this.phone,
    this.address,
    required this.suggestedReason,
    this.isKidFriendly = false,
    this.score = 0.0,
    this.osmId,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  /// Official Google Maps search URL (requires no API key)
  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  /// Official Google Maps directions URL (requires no API key)
  String get directionsUrl =>
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

  /// Clean display distance (e.g., "450 m" or "1.8 km")
  String get displayDistance {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }
    final km = (distanceMeters / 1000).toStringAsFixed(1);
    return '$km km';
  }

  /// Clean display travel estimate
  String get displayTravelTime {
    if (walkingMinutes != null && walkingMinutes! <= 25) {
      return '$walkingMinutes min walk';
    } else if (drivingMinutes != null) {
      return '$drivingMinutes min drive';
    }
    final roughWalk = (distanceMeters / 80).round().clamp(1, 120);
    if (roughWalk <= 20) {
      return '$roughWalk min walk';
    }
    final roughDrive = (distanceMeters / 400).round().clamp(2, 60);
    return '$roughDrive min drive';
  }

  factory MealSuggestionModel.fromMap(Map<String, dynamic> map) {
    return MealSuggestionModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      mealType: map['mealType'] ?? MealConfig.lunch,
      dietaryType: map['dietaryType'] ?? 'all',
      dietaryBadge: map['dietaryBadge'] ?? 'Restaurant',
      cuisine: map['cuisine'] ?? 'Local Dining',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (map['distanceMeters'] as num?)?.toInt() ?? 0,
      walkingMinutes: (map['walkingMinutes'] as num?)?.toInt(),
      drivingMinutes: (map['drivingMinutes'] as num?)?.toInt(),
      rating: (map['rating'] as num?)?.toDouble(),
      reviewCount: (map['reviewCount'] as num?)?.toInt(),
      priceLevel: map['priceLevel'],
      openingHours: map['openingHours'],
      openingStatus: map['openingStatus'] ?? 'Opening hours not available',
      phone: map['phone'],
      address: map['address'],
      suggestedReason: map['suggestedReason'] ?? '',
      isKidFriendly: map['isKidFriendly'] == true,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      osmId: map['osmId'],
      fetchedAt: map['fetchedAt'] != null
          ? DateTime.tryParse(map['fetchedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mealType': mealType,
      'dietaryType': dietaryType,
      'dietaryBadge': dietaryBadge,
      'cuisine': cuisine,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      if (walkingMinutes != null) 'walkingMinutes': walkingMinutes,
      if (drivingMinutes != null) 'drivingMinutes': drivingMinutes,
      if (rating != null) 'rating': rating,
      if (reviewCount != null) 'reviewCount': reviewCount,
      if (priceLevel != null) 'priceLevel': priceLevel,
      if (openingHours != null) 'openingHours': openingHours,
      'openingStatus': openingStatus,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      'suggestedReason': suggestedReason,
      'isKidFriendly': isKidFriendly,
      'score': score,
      if (osmId != null) 'osmId': osmId,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  MealSuggestionModel copyWith({
    String? id,
    String? name,
    String? mealType,
    String? dietaryType,
    String? dietaryBadge,
    String? cuisine,
    double? latitude,
    double? longitude,
    int? distanceMeters,
    int? walkingMinutes,
    int? drivingMinutes,
    double? rating,
    int? reviewCount,
    String? priceLevel,
    String? openingHours,
    String? openingStatus,
    String? phone,
    String? address,
    String? suggestedReason,
    bool? isKidFriendly,
    double? score,
    String? osmId,
    DateTime? fetchedAt,
  }) {
    return MealSuggestionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      dietaryType: dietaryType ?? this.dietaryType,
      dietaryBadge: dietaryBadge ?? this.dietaryBadge,
      cuisine: cuisine ?? this.cuisine,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      drivingMinutes: drivingMinutes ?? this.drivingMinutes,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      priceLevel: priceLevel ?? this.priceLevel,
      openingHours: openingHours ?? this.openingHours,
      openingStatus: openingStatus ?? this.openingStatus,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      suggestedReason: suggestedReason ?? this.suggestedReason,
      isKidFriendly: isKidFriendly ?? this.isKidFriendly,
      score: score ?? this.score,
      osmId: osmId ?? this.osmId,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

/// Container for both lunch and dinner suggestions on an itinerary day
class DayMealSuggestions {
  final List<MealSuggestionModel> lunchSuggestions;
  final List<MealSuggestionModel> dinnerSuggestions;
  final String? lunchAnchorName;
  final String? dinnerAnchorName;
  final DateTime lastUpdated;

  DayMealSuggestions({
    this.lunchSuggestions = const [],
    this.dinnerSuggestions = const [],
    this.lunchAnchorName,
    this.dinnerAnchorName,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  bool get isEmpty => lunchSuggestions.isEmpty && dinnerSuggestions.isEmpty;
  bool get isNotEmpty => !isEmpty;

  factory DayMealSuggestions.fromMap(Map<String, dynamic> map) {
    return DayMealSuggestions(
      lunchSuggestions: (map['lunchSuggestions'] as List? ?? [])
          .map((item) => MealSuggestionModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      dinnerSuggestions: (map['dinnerSuggestions'] as List? ?? [])
          .map((item) => MealSuggestionModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      lunchAnchorName: map['lunchAnchorName'],
      dinnerAnchorName: map['dinnerAnchorName'],
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lunchSuggestions': lunchSuggestions.map((s) => s.toMap()).toList(),
      'dinnerSuggestions': dinnerSuggestions.map((s) => s.toMap()).toList(),
      if (lunchAnchorName != null) 'lunchAnchorName': lunchAnchorName,
      if (dinnerAnchorName != null) 'dinnerAnchorName': dinnerAnchorName,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
