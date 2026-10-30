import 'package:cloud_firestore/cloud_firestore.dart' as import_firestore;
import 'itinerary_model.dart';
import 'nearby_service_model.dart';
import 'travelers_model.dart';

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

  // Age & Budget fields
  final int? age;
  final int? travelers;
  final int? budget;
  final String currency;
  final int? estimatedTotalCost;
  final int? remainingBudget;
  final Map<String, dynamic>? overallExpenseSummary;
  final String foodPreference;
  final List<NearbyServiceModel> nearbySafetyServices;

  // Travelers Feature fields (clean, DPDP privacy compliant)
  final int adultsCount;
  final int minorsCount;
  final List<String> minorAgeBands;
  final String? travelersSummary;
  final bool? avoidCrowds;
  final String? crowdModelVersion;

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
    this.nearbySafetyServices = const [],
    DateTime? createdAt,
    this.age,
    this.travelers,
    this.budget,
    this.currency = 'INR',
    this.estimatedTotalCost,
    this.remainingBudget,
    this.overallExpenseSummary,
    this.foodPreference = 'all',
    this.adultsCount = 1,
    this.minorsCount = 0,
    this.minorAgeBands = const [],
    this.travelersSummary,
    this.avoidCrowds,
    this.crowdModelVersion,
  }) : createdAt = createdAt ?? DateTime.now();

  TravelersModel get travelersModel => TravelersModel(
        adults: adultsCount,
        minors: minorsCount,
        minorAgeBands: minorAgeBands,
      );

  bool get isFamilyFriendly => minorsCount > 0;

  String get displayTravelersSummary =>
      travelersSummary ?? travelersModel.summary;

  factory MultiDayItineraryModel.fromMap(Map<String, dynamic> data) {
    final parsedTravelers = (data['travelers'] as num?)?.toInt();
    final parsedAdults = (data['adultsCount'] as num?)?.toInt() ??
        (data['adults'] as num?)?.toInt() ??
        parsedTravelers ??
        1;
    final parsedMinors = (data['minorsCount'] as num?)?.toInt() ??
        (data['minors'] as num?)?.toInt() ??
        0;
    final parsedBands = List<String>.from(data['minorAgeBands'] ?? []);

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
        return ItineraryModel.fromMap(dayData);
      }).toList(),
      overallSummary: data['overallSummary'],
      weatherSummary: data['weatherSummary'],
      whatToCarry: List<String>.from(data['whatToCarry'] ?? []),
      isSaved: data['isSaved'] ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      age: data['age'],
      travelers: parsedTravelers ?? (parsedAdults + parsedMinors),
      budget: data['budget'],
      currency: data['currency'] ?? 'INR',
      estimatedTotalCost: data['estimatedTotalCost'],
      remainingBudget: data['remainingBudget'],
      overallExpenseSummary: data['overallExpenseSummary'] as Map<String, dynamic>?,
      foodPreference: data['foodPreference'] ?? 'all',
      nearbySafetyServices: (data['nearbySafetyServices'] as List? ?? [])
          .map((s) => NearbyServiceModel.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      adultsCount: parsedAdults,
      minorsCount: parsedMinors,
      minorAgeBands: parsedBands,
      travelersSummary: data['travelersSummary'] ?? data['travelerSummary'],
      avoidCrowds: data['avoidCrowds'] as bool?,
      crowdModelVersion: data['crowdModelVersion'] as String?,
    );
  }

  factory MultiDayItineraryModel.fromFirestore(import_firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final parsedTravelers = (data['travelers'] as num?)?.toInt();
    final parsedAdults = (data['adultsCount'] as num?)?.toInt() ??
        (data['adults'] as num?)?.toInt() ??
        parsedTravelers ??
        1;
    final parsedMinors = (data['minorsCount'] as num?)?.toInt() ??
        (data['minors'] as num?)?.toInt() ??
        0;
    final parsedBands = List<String>.from(data['minorAgeBands'] ?? []);

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
        return ItineraryModel.fromMap(dayData);
      }).toList(),
      overallSummary: data['overallSummary'],
      weatherSummary: data['weatherSummary'],
      whatToCarry: List<String>.from(data['whatToCarry'] ?? []),
      isSaved: data['isSaved'] ?? false,
      createdAt: (data['createdAt'] as import_firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      age: data['age'],
      travelers: parsedTravelers ?? (parsedAdults + parsedMinors),
      budget: data['budget'],
      currency: data['currency'] ?? 'INR',
      estimatedTotalCost: data['estimatedTotalCost'],
      remainingBudget: data['remainingBudget'],
      overallExpenseSummary: data['overallExpenseSummary'] as Map<String, dynamic>?,
      foodPreference: data['foodPreference'] ?? 'all',
      nearbySafetyServices: (data['nearbySafetyServices'] as List? ?? [])
          .map((s) => NearbyServiceModel.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      adultsCount: parsedAdults,
      minorsCount: parsedMinors,
      minorAgeBands: parsedBands,
      travelersSummary: data['travelersSummary'] ?? data['travelerSummary'],
      avoidCrowds: data['avoidCrowds'] as bool?,
      crowdModelVersion: data['crowdModelVersion'] as String?,
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
      'age': age,
      'travelers': travelers ?? (adultsCount + minorsCount),
      'budget': budget,
      'currency': currency,
      'estimatedTotalCost': estimatedTotalCost,
      'remainingBudget': remainingBudget,
      'overallExpenseSummary': overallExpenseSummary,
      'foodPreference': foodPreference,
      'nearbySafetyServices': nearbySafetyServices.map((s) => s.toMap()).toList(),
      'adultsCount': adultsCount,
      'minorsCount': minorsCount,
      'minorAgeBands': minorAgeBands,
      'travelersSummary': displayTravelersSummary,
      'isFamilyFriendly': isFamilyFriendly,
      if (avoidCrowds != null) 'avoidCrowds': avoidCrowds,
      if (crowdModelVersion != null) 'crowdModelVersion': crowdModelVersion,
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
      'age': age,
      'travelers': travelers ?? (adultsCount + minorsCount),
      'budget': budget,
      'currency': currency,
      'estimatedTotalCost': estimatedTotalCost,
      'remainingBudget': remainingBudget,
      'overallExpenseSummary': overallExpenseSummary,
      'foodPreference': foodPreference,
      'nearbySafetyServices': nearbySafetyServices.map((s) => s.toMap()).toList(),
      'adultsCount': adultsCount,
      'minorsCount': minorsCount,
      'minorAgeBands': minorAgeBands,
      'travelersSummary': displayTravelersSummary,
      'isFamilyFriendly': isFamilyFriendly,
      if (avoidCrowds != null) 'avoidCrowds': avoidCrowds,
      if (crowdModelVersion != null) 'crowdModelVersion': crowdModelVersion,
    };
  }

  MultiDayItineraryModel copyWith({
    List<ItineraryModel>? days,
    String? overallSummary,
    String? weatherSummary,
    List<String>? whatToCarry,
    bool? isSaved,
    int? estimatedTotalCost,
    int? remainingBudget,
    Map<String, dynamic>? overallExpenseSummary,
    String? foodPreference,
    List<NearbyServiceModel>? nearbySafetyServices,
    int? adultsCount,
    int? minorsCount,
    List<String>? minorAgeBands,
    String? travelersSummary,
    bool? avoidCrowds,
    String? crowdModelVersion,
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
      age: age,
      travelers: travelers,
      budget: budget,
      currency: currency,
      estimatedTotalCost: estimatedTotalCost ?? this.estimatedTotalCost,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      overallExpenseSummary: overallExpenseSummary ?? this.overallExpenseSummary,
      foodPreference: foodPreference ?? this.foodPreference,
      nearbySafetyServices: nearbySafetyServices ?? this.nearbySafetyServices,
      adultsCount: adultsCount ?? this.adultsCount,
      minorsCount: minorsCount ?? this.minorsCount,
      minorAgeBands: minorAgeBands ?? this.minorAgeBands,
      travelersSummary: travelersSummary ?? this.travelersSummary,
      avoidCrowds: avoidCrowds ?? this.avoidCrowds,
      crowdModelVersion: crowdModelVersion ?? this.crowdModelVersion,
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
