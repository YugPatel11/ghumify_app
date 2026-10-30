import 'transport_option_model.dart';

/// Represents an inter-city travel connection connecting two consecutive cities.
class TravelLegModel {
  final String id;
  final String fromCity;
  final String toCity;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final double distanceKm;
  final List<TransportOptionModel> availableOptions;
  final TransportOptionModel selectedOption;
  final DateTime? travelDate;
  final String departureTime;
  final String arrivalTime;
  final bool isReturnLeg;

  const TravelLegModel({
    required this.id,
    required this.fromCity,
    required this.toCity,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.distanceKm,
    required this.availableOptions,
    required this.selectedOption,
    this.travelDate,
    this.departureTime = '08:30 AM',
    this.arrivalTime = '01:00 PM',
    this.isReturnLeg = false,
  });

  TravelLegModel copyWith({
    String? id,
    String? fromCity,
    String? toCity,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    double? distanceKm,
    List<TransportOptionModel>? availableOptions,
    TransportOptionModel? selectedOption,
    DateTime? travelDate,
    String? departureTime,
    String? arrivalTime,
    bool? isReturnLeg,
  }) {
    return TravelLegModel(
      id: id ?? this.id,
      fromCity: fromCity ?? this.fromCity,
      toCity: toCity ?? this.toCity,
      fromLat: fromLat ?? this.fromLat,
      fromLng: fromLng ?? this.fromLng,
      toLat: toLat ?? this.toLat,
      toLng: toLng ?? this.toLng,
      distanceKm: distanceKm ?? this.distanceKm,
      availableOptions: availableOptions ?? this.availableOptions,
      selectedOption: selectedOption ?? this.selectedOption,
      travelDate: travelDate ?? this.travelDate,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      isReturnLeg: isReturnLeg ?? this.isReturnLeg,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromCity': fromCity,
      'toCity': toCity,
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toLat': toLat,
      'toLng': toLng,
      'distanceKm': distanceKm,
      'availableOptions': availableOptions.map((o) => o.toMap()).toList(),
      'selectedOption': selectedOption.toMap(),
      if (travelDate != null) 'travelDate': travelDate!.toIso8601String(),
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'isReturnLeg': isReturnLeg,
    };
  }

  factory TravelLegModel.fromMap(Map<String, dynamic> data) {
    final rawOptions = (data['availableOptions'] as List? ?? [])
        .map((o) => TransportOptionModel.fromMap(Map<String, dynamic>.from(o as Map)))
        .toList();

    TransportOptionModel selected;
    if (data['selectedOption'] != null) {
      selected = TransportOptionModel.fromMap(
        Map<String, dynamic>.from(data['selectedOption'] as Map),
      );
    } else if (rawOptions.isNotEmpty) {
      selected = rawOptions.firstWhere(
        (o) => o.isRecommended,
        orElse: () => rawOptions.first,
      );
    } else {
      selected = TransportOptionModel(
        id: 'opt_default',
        mode: 'train',
        modeName: 'Express Train',
        durationMinutes: 180,
        estimatedCostPerPerson: 450,
        estimatedTotalCost: 450,
        distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 250.0,
        lastUpdated: DateTime.now(),
      );
    }

    return TravelLegModel(
      id: data['id'] ?? 'leg_${DateTime.now().millisecondsSinceEpoch}',
      fromCity: data['fromCity'] ?? '',
      toCity: data['toCity'] ?? '',
      fromLat: (data['fromLat'] as num?)?.toDouble() ?? 28.6139,
      fromLng: (data['fromLng'] as num?)?.toDouble() ?? 77.2090,
      toLat: (data['toLat'] as num?)?.toDouble() ?? 26.9124,
      toLng: (data['toLng'] as num?)?.toDouble() ?? 75.7873,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 250.0,
      availableOptions: rawOptions.isNotEmpty ? rawOptions : [selected],
      selectedOption: selected,
      travelDate: data['travelDate'] != null
          ? DateTime.tryParse(data['travelDate'].toString())
          : null,
      departureTime: data['departureTime'] ?? '08:30 AM',
      arrivalTime: data['arrivalTime'] ?? '01:00 PM',
      isReturnLeg: data['isReturnLeg'] as bool? ?? false,
    );
  }
}
