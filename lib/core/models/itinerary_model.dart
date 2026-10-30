import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_suggestion_model.dart';
import 'nearby_service_model.dart';
import 'travelers_model.dart';

/// Represents a single stop in the itinerary
class ItineraryStop {
  final String name;
  final String type; // "place", "food", "market", "travel", "break"
  final String? placeId;
  final String startTime; // "10:00"
  final String endTime; // "11:30"
  final int durationMinutes;
  final double? latitude;
  final double? longitude;
  final String description;
  final String? photoUrl;
  final String? travelMode; // from previous stop
  final int? travelMinutes; // from previous stop
  final List<String> tips; // e.g. "Don't miss the Maha Aarti at 7 PM"
  final int? estimatedCost; // newly added
  final String? dietaryType; // "veg", "veg_egg", "jain", "non_veg"
  final bool isKidFriendly;
  final String? ageRangeRecommendation; // e.g. "All ages", "Ages 3+", "Toddlers"
  final String? strollerAccess; // "yes", "no", "partial"
  final String? childTicketInfo; // e.g. "Free under 5", "Please check on arrival"

  final String? shortLabel; // 60-80 chars for collapsed view
  final String? briefDescription; // 200-300 chars for expanded view
  final String? openingHours; // e.g. "09:00 - 18:00"
  final String? ticketPrice; // e.g. "₹50 per person" or "Free entry"
  final String? bestTimeToVisit; // e.g. "Morning or Sunset"
  final bool isAnchored; // meal stops, legs, meeting points, pinned
  final bool isPinned; // explicitly pinned by user
  final List<String> galleryPhotos; // additional photos for expanded gallery
  final double? distanceFromPrevKm; // straight-line / route distance from prev stop
  final String? travelTimeFromPrev; // e.g. "6 min drive"

  ItineraryStop({
    required this.name,
    required this.type,
    this.placeId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.latitude,
    this.longitude,
    this.description = '',
    this.photoUrl,
    this.travelMode,
    this.travelMinutes,
    this.tips = const [],
    this.estimatedCost,
    this.dietaryType,
    this.isKidFriendly = false,
    this.ageRangeRecommendation,
    this.strollerAccess,
    this.childTicketInfo,
    this.shortLabel,
    this.briefDescription,
    this.openingHours,
    this.ticketPrice,
    this.bestTimeToVisit,
    this.isAnchored = false,
    this.isPinned = false,
    this.galleryPhotos = const [],
    this.distanceFromPrevKm,
    this.travelTimeFromPrev,
  });

  /// Short label (60-80 chars) for collapsed view with graceful fallback
  String get displayShortLabel {
    if (shortLabel != null && shortLabel!.trim().isNotEmpty) {
      return shortLabel!.trim();
    }
    if (description.isNotEmpty) {
      final trimmed = description.trim();
      if (trimmed.length <= 80) return trimmed;
      final spaceIdx = trimmed.lastIndexOf(' ', 77);
      return spaceIdx > 20 ? '${trimmed.substring(0, spaceIdx)}...' : '${trimmed.substring(0, 77)}...';
    }
    return name;
  }

  /// Brief description (200-300 chars) for expanded view with graceful fallback
  String get displayBriefDescription {
    if (briefDescription != null && briefDescription!.trim().isNotEmpty) {
      return briefDescription!.trim();
    }
    if (description.isNotEmpty) {
      final trimmed = description.trim();
      if (trimmed.length <= 300) return trimmed;
      final spaceIdx = trimmed.lastIndexOf(' ', 297);
      return spaceIdx > 100 ? '${trimmed.substring(0, spaceIdx)}...' : '${trimmed.substring(0, 297)}...';
    }
    return '';
  }

  factory ItineraryStop.fromMap(Map<String, dynamic> data) {
    return ItineraryStop(
      name: data['name'] ?? '',
      type: data['type'] ?? 'place',
      placeId: data['placeId'],
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      durationMinutes: data['durationMinutes'] ?? 0,
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      description: data['description'] ?? '',
      photoUrl: data['photoUrl'],
      travelMode: data['travelMode'],
      travelMinutes: data['travelMinutes'],
      tips: List<String>.from(data['tips'] ?? []),
      estimatedCost: data['estimatedCost'],
      dietaryType: data['dietaryType'],
      isKidFriendly: data['isKidFriendly'] == true,
      ageRangeRecommendation: data['ageRangeRecommendation'],
      strollerAccess: data['strollerAccess'],
      childTicketInfo: data['childTicketInfo'],
      shortLabel: data['shortLabel'] ?? data['short'],
      briefDescription: data['briefDescription'] ?? data['brief'],
      openingHours: data['openingHours'],
      ticketPrice: data['ticketPrice'],
      bestTimeToVisit: data['bestTimeToVisit'],
      isAnchored: data['isAnchored'] == true,
      isPinned: data['isPinned'] == true,
      galleryPhotos: List<String>.from(data['galleryPhotos'] ?? []),
      distanceFromPrevKm: (data['distanceFromPrevKm'] as num?)?.toDouble(),
      travelTimeFromPrev: data['travelTimeFromPrev'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'placeId': placeId,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'photoUrl': photoUrl,
      'travelMode': travelMode,
      'travelMinutes': travelMinutes,
      'tips': tips,
      'estimatedCost': estimatedCost,
      'dietaryType': dietaryType,
      'isKidFriendly': isKidFriendly,
      'ageRangeRecommendation': ageRangeRecommendation,
      'strollerAccess': strollerAccess,
      'childTicketInfo': childTicketInfo,
      'shortLabel': shortLabel,
      'briefDescription': briefDescription,
      'openingHours': openingHours,
      'ticketPrice': ticketPrice,
      'bestTimeToVisit': bestTimeToVisit,
      'isAnchored': isAnchored,
      'isPinned': isPinned,
      'galleryPhotos': galleryPhotos,
      'distanceFromPrevKm': distanceFromPrevKm,
      'travelTimeFromPrev': travelTimeFromPrev,
    };
  }

  ItineraryStop copyWith({
    String? name,
    String? type,
    String? placeId,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    double? latitude,
    double? longitude,
    String? description,
    String? photoUrl,
    String? travelMode,
    int? travelMinutes,
    List<String>? tips,
    int? estimatedCost,
    String? dietaryType,
    bool? isKidFriendly,
    String? ageRangeRecommendation,
    String? strollerAccess,
    String? childTicketInfo,
    String? shortLabel,
    String? briefDescription,
    String? openingHours,
    String? ticketPrice,
    String? bestTimeToVisit,
    bool? isAnchored,
    bool? isPinned,
    List<String>? galleryPhotos,
    double? distanceFromPrevKm,
    String? travelTimeFromPrev,
  }) {
    return ItineraryStop(
      name: name ?? this.name,
      type: type ?? this.type,
      placeId: placeId ?? this.placeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      travelMode: travelMode ?? this.travelMode,
      travelMinutes: travelMinutes ?? this.travelMinutes,
      tips: tips ?? this.tips,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      dietaryType: dietaryType ?? this.dietaryType,
      isKidFriendly: isKidFriendly ?? this.isKidFriendly,
      ageRangeRecommendation: ageRangeRecommendation ?? this.ageRangeRecommendation,
      strollerAccess: strollerAccess ?? this.strollerAccess,
      childTicketInfo: childTicketInfo ?? this.childTicketInfo,
      shortLabel: shortLabel ?? this.shortLabel,
      briefDescription: briefDescription ?? this.briefDescription,
      openingHours: openingHours ?? this.openingHours,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      bestTimeToVisit: bestTimeToVisit ?? this.bestTimeToVisit,
      isAnchored: isAnchored ?? this.isAnchored,
      isPinned: isPinned ?? this.isPinned,
      galleryPhotos: galleryPhotos ?? this.galleryPhotos,
      distanceFromPrevKm: distanceFromPrevKm ?? this.distanceFromPrevKm,
      travelTimeFromPrev: travelTimeFromPrev ?? this.travelTimeFromPrev,
    );
  }
}

/// Represents a complete generated itinerary
class ItineraryModel {
  final String id;
  final String userId;
  final String city;
  final String date; // "2026-08-22"
  final String startTime; // "10:00"
  final String endTime; // "18:00"
  final int totalDurationMinutes;
  final List<String> interests;
  final String travelMode;
  final String pace; // relaxed, moderate, fast
  final List<ItineraryStop> stops;
  final String? weatherSummary;
  final List<String> whatToCarry;
  final String? aiSummary; // AI-generated overview
  final bool isSaved;
  final int dayNumber; // Day number in multi-day trip (1-indexed, defaults to 1)
  final String foodPreference;
  final List<NearbyServiceModel> nearbySafetyServices;
  final DateTime createdAt;
  
  // Age & Budget fields
  final int? age;
  final int? travelers;
  final int? budget;
  final String currency;
  final int? estimatedTotalCost;
  final int? remainingBudget;
  final Map<String, dynamic>? expenseSummary;

  // Travelers Feature fields (clean, DPDP privacy compliant)
  final int adultsCount;
  final int minorsCount;
  final List<String> minorAgeBands;
  final String? travelersSummary;
  // Meal Suggestions field
  final DayMealSuggestions? mealSuggestions;
  // Nearest-First route info
  final String? routeStartPointInfo; // e.g. "Route starts from your current location"
  final bool isManuallyOrdered;

  ItineraryModel({
    required this.id,
    required this.userId,
    required this.city,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalDurationMinutes,
    this.interests = const [],
    this.travelMode = 'driving',
    this.pace = 'moderate',
    this.stops = const [],
    this.weatherSummary,
    this.whatToCarry = const [],
    this.aiSummary,
    this.isSaved = false,
    this.dayNumber = 1,
    this.foodPreference = 'all',
    this.nearbySafetyServices = const [],
    this.mealSuggestions,
    DateTime? createdAt,
    this.age,
    this.travelers,
    this.budget,
    this.currency = 'INR',
    this.estimatedTotalCost,
    this.remainingBudget,
    this.expenseSummary,
    this.adultsCount = 1,
    this.minorsCount = 0,
    this.minorAgeBands = const [],
    this.travelersSummary,
    this.routeStartPointInfo,
    this.isManuallyOrdered = false,
  }) : createdAt = createdAt ?? DateTime.now();

  TravelersModel get travelersModel => TravelersModel(
        adults: adultsCount,
        minors: minorsCount,
        minorAgeBands: minorAgeBands,
      );

  bool get isFamilyFriendly => minorsCount > 0;

  bool get hasMealSuggestions =>
      mealSuggestions != null && mealSuggestions!.isNotEmpty;

  String get displayTravelersSummary =>
      travelersSummary ?? travelersModel.summary;

  factory ItineraryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItineraryModel.fromMap(data, docId: doc.id);
  }

  factory ItineraryModel.fromMap(Map<String, dynamic> data, {String docId = ''}) {
    final parsedTravelers = (data['travelers'] as num?)?.toInt();
    final parsedAdults = (data['adultsCount'] as num?)?.toInt() ??
        (data['adults'] as num?)?.toInt() ??
        parsedTravelers ??
        1;
    final parsedMinors = (data['minorsCount'] as num?)?.toInt() ??
        (data['minors'] as num?)?.toInt() ??
        0;
    final parsedBands = List<String>.from(data['minorAgeBands'] ?? []);

    return ItineraryModel(
      id: docId.isNotEmpty ? docId : (data['id'] ?? ''),
      userId: data['userId'] ?? '',
      city: data['city'] ?? '',
      date: data['date'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      totalDurationMinutes: data['totalDurationMinutes'] ?? 0,
      interests: List<String>.from(data['interests'] ?? []),
      travelMode: data['travelMode'] ?? 'driving',
      pace: data['pace'] ?? 'moderate',
      stops: (data['stops'] as List? ?? [])
          .map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>))
          .toList(),
      weatherSummary: data['weatherSummary'],
      whatToCarry: List<String>.from(data['whatToCarry'] ?? []),
      aiSummary: data['aiSummary'],
      isSaved: data['isSaved'] ?? false,
      dayNumber: data['dayNumber'] ?? 1,
      foodPreference: data['foodPreference'] ?? 'all',
      nearbySafetyServices: (data['nearbySafetyServices'] as List? ?? [])
          .map((s) => NearbyServiceModel.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] != null
              ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      age: data['age'],
      travelers: parsedTravelers ?? (parsedAdults + parsedMinors),
      budget: data['budget'] is int
          ? data['budget']
          : int.tryParse(data['budget']?.toString() ?? ''),
      currency: data['currency'] ?? 'INR',
      estimatedTotalCost: data['estimatedTotalCost'],
      remainingBudget: data['remainingBudget'],
      expenseSummary: data['expenseSummary'] as Map<String, dynamic>?,
      adultsCount: parsedAdults,
      minorsCount: parsedMinors,
      minorAgeBands: parsedBands,
      travelersSummary: data['travelersSummary'] ?? data['travelerSummary'],
      mealSuggestions: data['mealSuggestions'] != null
          ? DayMealSuggestions.fromMap(Map<String, dynamic>.from(data['mealSuggestions'] as Map))
          : null,
      routeStartPointInfo: data['routeStartPointInfo'],
      isManuallyOrdered: data['isManuallyOrdered'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'city': city,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'totalDurationMinutes': totalDurationMinutes,
      'interests': interests,
      'travelMode': travelMode,
      'pace': pace,
      'stops': stops.map((s) => s.toMap()).toList(),
      'weatherSummary': weatherSummary,
      'whatToCarry': whatToCarry,
      'aiSummary': aiSummary,
      'isSaved': isSaved,
      'dayNumber': dayNumber,
      'foodPreference': foodPreference,
      'nearbySafetyServices': nearbySafetyServices.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'age': age,
      'travelers': travelers ?? (adultsCount + minorsCount),
      'budget': budget,
      'currency': currency,
      'estimatedTotalCost': estimatedTotalCost,
      'remainingBudget': remainingBudget,
      'expenseSummary': expenseSummary,
      'adultsCount': adultsCount,
      'minorsCount': minorsCount,
      'minorAgeBands': minorAgeBands,
      'travelersSummary': displayTravelersSummary,
      'isFamilyFriendly': isFamilyFriendly,
      if (mealSuggestions != null) 'mealSuggestions': mealSuggestions!.toMap(),
      if (routeStartPointInfo != null) 'routeStartPointInfo': routeStartPointInfo,
      'isManuallyOrdered': isManuallyOrdered,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'city': city,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'totalDurationMinutes': totalDurationMinutes,
      'interests': interests,
      'travelMode': travelMode,
      'pace': pace,
      'stops': stops.map((s) => s.toMap()).toList(),
      'weatherSummary': weatherSummary,
      'whatToCarry': whatToCarry,
      'aiSummary': aiSummary,
      'isSaved': isSaved,
      'dayNumber': dayNumber,
      'foodPreference': foodPreference,
      'nearbySafetyServices': nearbySafetyServices.map((s) => s.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'age': age,
      'travelers': travelers ?? (adultsCount + minorsCount),
      'budget': budget,
      'currency': currency,
      'estimatedTotalCost': estimatedTotalCost,
      'remainingBudget': remainingBudget,
      'expenseSummary': expenseSummary,
      'adultsCount': adultsCount,
      'minorsCount': minorsCount,
      'minorAgeBands': minorAgeBands,
      'travelersSummary': displayTravelersSummary,
      'isFamilyFriendly': isFamilyFriendly,
      if (mealSuggestions != null) 'mealSuggestions': mealSuggestions!.toMap(),
      if (routeStartPointInfo != null) 'routeStartPointInfo': routeStartPointInfo,
      'isManuallyOrdered': isManuallyOrdered,
    };
  }

  ItineraryModel copyWith({
    String? id,
    String? city,
    String? date,
    List<ItineraryStop>? stops,
    String? weatherSummary,
    List<String>? whatToCarry,
    String? aiSummary,
    bool? isSaved,
    int? dayNumber,
    String? foodPreference,
    List<NearbyServiceModel>? nearbySafetyServices,
    int? estimatedTotalCost,
    int? remainingBudget,
    Map<String, dynamic>? expenseSummary,
    int? adultsCount,
    int? minorsCount,
    List<String>? minorAgeBands,
    String? travelersSummary,
    DayMealSuggestions? mealSuggestions,
    String? routeStartPointInfo,
    bool? isManuallyOrdered,
  }) {
    return ItineraryModel(
      id: id ?? this.id,
      userId: userId,
      city: city ?? this.city,
      date: date ?? this.date,
      startTime: startTime,
      endTime: endTime,
      totalDurationMinutes: totalDurationMinutes,
      interests: interests,
      travelMode: travelMode,
      pace: pace,
      stops: stops ?? this.stops,
      weatherSummary: weatherSummary ?? this.weatherSummary,
      whatToCarry: whatToCarry ?? this.whatToCarry,
      aiSummary: aiSummary ?? this.aiSummary,
      isSaved: isSaved ?? this.isSaved,
      dayNumber: dayNumber ?? this.dayNumber,
      foodPreference: foodPreference ?? this.foodPreference,
      nearbySafetyServices: nearbySafetyServices ?? this.nearbySafetyServices,
      createdAt: createdAt,
      age: age,
      travelers: travelers,
      budget: budget,
      currency: currency,
      estimatedTotalCost: estimatedTotalCost ?? this.estimatedTotalCost,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      expenseSummary: expenseSummary ?? this.expenseSummary,
      adultsCount: adultsCount ?? this.adultsCount,
      minorsCount: minorsCount ?? this.minorsCount,
      minorAgeBands: minorAgeBands ?? this.minorAgeBands,
      travelersSummary: travelersSummary ?? this.travelersSummary,
      mealSuggestions: mealSuggestions ?? this.mealSuggestions,
      routeStartPointInfo: routeStartPointInfo ?? this.routeStartPointInfo,
      isManuallyOrdered: isManuallyOrdered ?? this.isManuallyOrdered,
    );
  }
}
