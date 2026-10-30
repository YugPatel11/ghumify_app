import 'package:cloud_firestore/cloud_firestore.dart';
import 'nearby_service_model.dart';

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
  });

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
  
  // New Age & Budget fields
  final int? age;
  final int? travelers;
  final int? budget;
  final String currency;
  final int? estimatedTotalCost;
  final int? remainingBudget;
  final Map<String, dynamic>? expenseSummary;

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
    DateTime? createdAt,
    this.age,
    this.travelers,
    this.budget,
    this.currency = 'INR',
    this.estimatedTotalCost,
    this.remainingBudget,
    this.expenseSummary,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ItineraryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItineraryModel(
      id: doc.id,
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      age: data['age'],
      travelers: data['travelers'],
      budget: data['budget'],
      currency: data['currency'] ?? 'INR',
      estimatedTotalCost: data['estimatedTotalCost'],
      remainingBudget: data['remainingBudget'],
      expenseSummary: data['expenseSummary'] as Map<String, dynamic>?,
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
      'travelers': travelers,
      'budget': budget,
      'currency': currency,
      'estimatedTotalCost': estimatedTotalCost,
      'remainingBudget': remainingBudget,
      'expenseSummary': expenseSummary,
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
      'travelers': travelers,
      'budget': budget,
      'currency': currency,
      'estimatedTotalCost': estimatedTotalCost,
      'remainingBudget': remainingBudget,
      'expenseSummary': expenseSummary,
    };
  }

  ItineraryModel copyWith({
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
  }) {
    return ItineraryModel(
      id: id,
      userId: userId,
      city: city,
      date: date,
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
    );
  }
}
