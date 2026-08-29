import 'package:cloud_firestore/cloud_firestore.dart' as import_firestore;
import 'itinerary_model.dart';

/// Represents a complete multi-day itinerary
class MultiDayItineraryModel {
  final String id;
  final String userId;
  final String city;
  final String startDate; // "2026-08-22"
  final String endDate; // "2026-08-25"
  final int numberOfDays;
  final String dailyStartTime; // "09:00"
  final String dailyEndTime; // "18:00"
  final List<String> interests;
  final String travelMode;
  final String pace;
  final List<ItineraryModel> days; // One ItineraryModel per day
  final String? overallSummary;
  final String? weatherSummary;
  final List<String> whatToCarry;
  final bool isSaved;
  final DateTime createdAt;

  MultiDayItineraryModel({
    required this.id,
    required this.userId,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.dailyStartTime,
    required this.dailyEndTime,
    this.interests = const [],
    this.travelMode = 'driving',
    this.pace = 'moderate',
    this.days = const [],
    this.overallSummary,
    this.weatherSummary,
    this.whatToCarry = const [],
    this.isSaved = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MultiDayItineraryModel.fromMap(Map<String, dynamic> data) {
    return MultiDayItineraryModel(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      city: data['city'] ?? '',
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      numberOfDays: data['numberOfDays'] ?? 1,
      dailyStartTime: data['dailyStartTime'] ?? '09:00',
      dailyEndTime: data['dailyEndTime'] ?? '18:00',
      interests: List<String>.from(data['interests'] ?? []),
      travelMode: data['travelMode'] ?? 'driving',
      pace: data['pace'] ?? 'moderate',
      days: (data['days'] as List? ?? []).map((d) {
        final dayData = d as Map<String, dynamic>;
        return ItineraryModel(
          id: dayData['id'] ?? '',
          userId: dayData['userId'] ?? '',
          city: dayData['city'] ?? '',
          date: dayData['date'] ?? '',
          startTime: dayData['startTime'] ?? '',
          endTime: dayData['endTime'] ?? '',
          totalDurationMinutes: dayData['totalDurationMinutes'] ?? 0,
          interests: List<String>.from(dayData['interests'] ?? []),
          travelMode: dayData['travelMode'] ?? 'driving',
          pace: dayData['pace'] ?? 'moderate',
          stops: (dayData['stops'] as List? ?? [])
              .map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>))
              .toList(),
          weatherSummary: dayData['weatherSummary'],
          whatToCarry: List<String>.from(dayData['whatToCarry'] ?? []),
          aiSummary: dayData['aiSummary'],
          dayNumber: dayData['dayNumber'] ?? 1,
        );
      }).toList(),
      overallSummary: data['overallSummary'],
      weatherSummary: data['weatherSummary'],
      whatToCarry: List<String>.from(data['whatToCarry'] ?? []),
      isSaved: data['isSaved'] ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  factory MultiDayItineraryModel.fromFirestore(import_firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MultiDayItineraryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      city: data['city'] ?? '',
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      numberOfDays: data['numberOfDays'] ?? 1,
      dailyStartTime: data['dailyStartTime'] ?? '09:00',
      dailyEndTime: data['dailyEndTime'] ?? '18:00',
      interests: List<String>.from(data['interests'] ?? []),
      travelMode: data['travelMode'] ?? 'driving',
      pace: data['pace'] ?? 'moderate',
      days: (data['days'] as List? ?? []).map((d) {
        final dayData = d as Map<String, dynamic>;
        return ItineraryModel(
          id: dayData['id'] ?? '',
          userId: dayData['userId'] ?? '',
          city: dayData['city'] ?? '',
          date: dayData['date'] ?? '',
          startTime: dayData['startTime'] ?? '',
          endTime: dayData['endTime'] ?? '',
          totalDurationMinutes: dayData['totalDurationMinutes'] ?? 0,
          interests: List<String>.from(dayData['interests'] ?? []),
          travelMode: dayData['travelMode'] ?? 'driving',
          pace: dayData['pace'] ?? 'moderate',
          stops: (dayData['stops'] as List? ?? [])
              .map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>))
              .toList(),
          weatherSummary: dayData['weatherSummary'],
          whatToCarry: List<String>.from(dayData['whatToCarry'] ?? []),
          aiSummary: dayData['aiSummary'],
          dayNumber: dayData['dayNumber'] ?? 1,
        );
      }).toList(),
      overallSummary: data['overallSummary'],
      weatherSummary: data['weatherSummary'],
      whatToCarry: List<String>.from(data['whatToCarry'] ?? []),
      isSaved: data['isSaved'] ?? false,
      createdAt: (data['createdAt'] as import_firestore.Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'city': city,
      'startDate': startDate,
      'endDate': endDate,
      'numberOfDays': numberOfDays,
      'dailyStartTime': dailyStartTime,
      'dailyEndTime': dailyEndTime,
      'interests': interests,
      'travelMode': travelMode,
      'pace': pace,
      'days': days
          .map((d) => {
                ...d.toMap(),
                'dayNumber': d.dayNumber,
              })
          .toList(),
      'overallSummary': overallSummary,
      'weatherSummary': weatherSummary,
      'whatToCarry': whatToCarry,
      'isSaved': isSaved,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'city': city,
      'startDate': startDate,
      'endDate': endDate,
      'numberOfDays': numberOfDays,
      'dailyStartTime': dailyStartTime,
      'dailyEndTime': dailyEndTime,
      'interests': interests,
      'travelMode': travelMode,
      'pace': pace,
      'days': days
          .map((d) => {
                ...d.toFirestore(),
                'dayNumber': d.dayNumber,
              })
          .toList(),
      'overallSummary': overallSummary,
      'weatherSummary': weatherSummary,
      'whatToCarry': whatToCarry,
      'isSaved': isSaved,
      'createdAt': import_firestore.Timestamp.fromDate(createdAt),
    };
  }

  MultiDayItineraryModel copyWith({
    List<ItineraryModel>? days,
    String? overallSummary,
    String? weatherSummary,
    List<String>? whatToCarry,
    bool? isSaved,
  }) {
    return MultiDayItineraryModel(
      id: id,
      userId: userId,
      city: city,
      startDate: startDate,
      endDate: endDate,
      numberOfDays: numberOfDays,
      dailyStartTime: dailyStartTime,
      dailyEndTime: dailyEndTime,
      interests: interests,
      travelMode: travelMode,
      pace: pace,
      days: days ?? this.days,
      overallSummary: overallSummary ?? this.overallSummary,
      weatherSummary: weatherSummary ?? this.weatherSummary,
      whatToCarry: whatToCarry ?? this.whatToCarry,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt,
    );
  }

  /// Get itinerary for a specific day (1-indexed)
  ItineraryModel? getDay(int dayNumber) {
    try {
      return days.firstWhere((d) => d.dayNumber == dayNumber);
    } catch (_) {
      return dayNumber <= days.length ? days[dayNumber - 1] : null;
    }
  }
}
