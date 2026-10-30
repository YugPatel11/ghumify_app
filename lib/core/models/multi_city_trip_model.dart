import 'city_stay_model.dart';
import 'itinerary_model.dart';
import 'travel_leg_model.dart';
import 'travelers_model.dart';

/// Represents a complete multi-city itinerary journey covering multiple destinations
class MultiCityTripModel {
  final String id;
  final String userId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final List<CityStayModel> cities;
  final List<TravelLegModel> legs;
  final bool isRoundTrip;
  final List<ItineraryModel> days; // All days in sequence across all cities
  final TravelersModel travelers;
  final String foodPreference;
  final int estimatedTravelCost;
  final DateTime createdAt;
  final DateTime updatedAt;

  MultiCityTripModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.cities,
    required this.legs,
    this.isRoundTrip = false,
    this.days = const [],
    this.travelers = const TravelersModel(),
    this.foodPreference = 'all',
    int? estimatedTravelCost,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : estimatedTravelCost = estimatedTravelCost ??
            legs.fold<int>(0, (sum, l) => sum + l.selectedOption.estimatedTotalCost),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Total inter-city distance across all legs
  double get totalDistanceKm =>
      legs.fold<double>(0.0, (sum, leg) => sum + leg.distanceKm);

  /// String summary of the route (e.g. "Delhi → Agra → Jaipur")
  String get routeSummary =>
      cities.map((c) => c.name).join(' → ') + (isRoundTrip && cities.isNotEmpty ? ' → ${cities.first.name}' : '');

  bool get isFamilyFriendly => travelers.hasMinors;

  MultiCityTripModel copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    List<CityStayModel>? cities,
    List<TravelLegModel>? legs,
    bool? isRoundTrip,
    List<ItineraryModel>? days,
    TravelersModel? travelers,
    String? foodPreference,
    int? estimatedTravelCost,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MultiCityTripModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      cities: cities ?? this.cities,
      legs: legs ?? this.legs,
      isRoundTrip: isRoundTrip ?? this.isRoundTrip,
      days: days ?? this.days,
      travelers: travelers ?? this.travelers,
      foodPreference: foodPreference ?? this.foodPreference,
      estimatedTravelCost: estimatedTravelCost ?? this.estimatedTravelCost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalDays': totalDays,
      'cities': cities.map((c) => c.toMap()).toList(),
      'legs': legs.map((l) => l.toMap()).toList(),
      'isRoundTrip': isRoundTrip,
      'days': days.map((d) => d.toMap()).toList(),
      'travelers': travelers.toMap(),
      'foodPreference': foodPreference,
      'estimatedTravelCost': estimatedTravelCost,
      'totalDistanceKm': totalDistanceKm,
      'routeSummary': routeSummary,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tripType': 'multi_city',
    };
  }

  factory MultiCityTripModel.fromMap(Map<String, dynamic> data) {
    final rawCities = (data['cities'] as List? ?? [])
        .map((c) => CityStayModel.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList();

    final rawLegs = (data['legs'] as List? ?? [])
        .map((l) => TravelLegModel.fromMap(Map<String, dynamic>.from(l as Map)))
        .toList();

    final rawDays = (data['days'] as List? ?? [])
        .map((d) => ItineraryModel.fromMap(Map<String, dynamic>.from(d as Map)))
        .toList();

    final travelersData = data['travelers'] is Map<String, dynamic>
        ? TravelersModel.fromMap(data['travelers'] as Map<String, dynamic>)
        : TravelersModel(
            adults: (data['adultsCount'] as num?)?.toInt() ?? 1,
            minors: (data['minorsCount'] as num?)?.toInt() ?? 0,
          );

    return MultiCityTripModel(
      id: data['id'] ?? 'trip_${DateTime.now().millisecondsSinceEpoch}',
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'Multi-City Trip',
      startDate: data['startDate'] != null
          ? DateTime.tryParse(data['startDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? DateTime.tryParse(data['endDate'].toString()) ?? DateTime.now().add(const Duration(days: 3))
          : DateTime.now().add(const Duration(days: 3)),
      totalDays: (data['totalDays'] as num?)?.toInt() ?? (rawCities.fold<int>(0, (s, c) => s + c.stayDays)),
      cities: rawCities,
      legs: rawLegs,
      isRoundTrip: data['isRoundTrip'] as bool? ?? false,
      days: rawDays,
      travelers: travelersData,
      foodPreference: data['foodPreference'] ?? 'all',
      estimatedTravelCost: (data['estimatedTravelCost'] as num?)?.toInt(),
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
