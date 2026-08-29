import 'package:cloud_firestore/cloud_firestore.dart';

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
    };
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
  final DateTime createdAt;

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
    DateTime? createdAt,
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
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'createdAt': createdAt.toIso8601String(),
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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ItineraryModel copyWith({
    List<ItineraryStop>? stops,
    String? weatherSummary,
    List<String>? whatToCarry,
    String? aiSummary,
    bool? isSaved,
    int? dayNumber,
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
      createdAt: createdAt,
    );
  }
}
