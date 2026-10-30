import 'package:flutter/material.dart';

/// Represents a specific transit option for an inter-city travel leg.
class TransportOptionModel {
  final String id;
  final String mode; // 'train' | 'bus' | 'flight' | 'car'
  final String modeName;
  final int durationMinutes;
  final int estimatedCostPerPerson;
  final int estimatedTotalCost;
  final double distanceKm;
  final bool isRecommended;
  final String? recommendationReason;
  final bool isOvernight;
  final String notes;
  final String comfortClass;
  final String dataSource;
  final bool isEstimate;
  final DateTime lastUpdated;
  final String? bookingUrl;
  final bool isCustomEdited;

  const TransportOptionModel({
    required this.id,
    required this.mode,
    required this.modeName,
    required this.durationMinutes,
    required this.estimatedCostPerPerson,
    required this.estimatedTotalCost,
    required this.distanceKm,
    this.isRecommended = false,
    this.recommendationReason,
    this.isOvernight = false,
    this.notes = '',
    this.comfortClass = 'Standard',
    this.dataSource = 'Indian Transit Fare Engine (2026)',
    this.isEstimate = true,
    required this.lastUpdated,
    this.bookingUrl,
    this.isCustomEdited = false,
  });

  /// Formatted duration string (e.g. "4h 30m" or "1h 15m")
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  /// Icon corresponding to the transport mode
  IconData get iconData {
    switch (mode) {
      case 'train':
        return Icons.train_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      default:
        return Icons.commute_rounded;
    }
  }

  TransportOptionModel copyWith({
    String? id,
    String? mode,
    String? modeName,
    int? durationMinutes,
    int? estimatedCostPerPerson,
    int? estimatedTotalCost,
    double? distanceKm,
    bool? isRecommended,
    String? recommendationReason,
    bool? isOvernight,
    String? notes,
    String? comfortClass,
    String? dataSource,
    bool? isEstimate,
    DateTime? lastUpdated,
    String? bookingUrl,
    bool? isCustomEdited,
  }) {
    return TransportOptionModel(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      modeName: modeName ?? this.modeName,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      estimatedCostPerPerson:
          estimatedCostPerPerson ?? this.estimatedCostPerPerson,
      estimatedTotalCost: estimatedTotalCost ?? this.estimatedTotalCost,
      distanceKm: distanceKm ?? this.distanceKm,
      isRecommended: isRecommended ?? this.isRecommended,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      isOvernight: isOvernight ?? this.isOvernight,
      notes: notes ?? this.notes,
      comfortClass: comfortClass ?? this.comfortClass,
      dataSource: dataSource ?? this.dataSource,
      isEstimate: isEstimate ?? this.isEstimate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      bookingUrl: bookingUrl ?? this.bookingUrl,
      isCustomEdited: isCustomEdited ?? this.isCustomEdited,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mode': mode,
      'modeName': modeName,
      'durationMinutes': durationMinutes,
      'estimatedCostPerPerson': estimatedCostPerPerson,
      'estimatedTotalCost': estimatedTotalCost,
      'distanceKm': distanceKm,
      'isRecommended': isRecommended,
      if (recommendationReason != null)
        'recommendationReason': recommendationReason,
      'isOvernight': isOvernight,
      'notes': notes,
      'comfortClass': comfortClass,
      'dataSource': dataSource,
      'isEstimate': isEstimate,
      'lastUpdated': lastUpdated.toIso8601String(),
      if (bookingUrl != null) 'bookingUrl': bookingUrl,
      'isCustomEdited': isCustomEdited,
    };
  }

  factory TransportOptionModel.fromMap(Map<String, dynamic> data) {
    return TransportOptionModel(
      id: data['id'] ?? 'opt_${DateTime.now().millisecondsSinceEpoch}',
      mode: data['mode'] ?? 'train',
      modeName: data['modeName'] ?? 'Transit',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 180,
      estimatedCostPerPerson:
          (data['estimatedCostPerPerson'] as num?)?.toInt() ?? 500,
      estimatedTotalCost: (data['estimatedTotalCost'] as num?)?.toInt() ?? 500,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 200.0,
      isRecommended: data['isRecommended'] as bool? ?? false,
      recommendationReason: data['recommendationReason'] as String?,
      isOvernight: data['isOvernight'] as bool? ?? false,
      notes: data['notes'] ?? '',
      comfortClass: data['comfortClass'] ?? 'Standard',
      dataSource: data['dataSource'] ?? 'Indian Transit Fare Engine (2026)',
      isEstimate: data['isEstimate'] as bool? ?? true,
      lastUpdated: data['lastUpdated'] != null
          ? DateTime.tryParse(data['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
      bookingUrl: data['bookingUrl'] as String?,
      isCustomEdited: data['isCustomEdited'] as bool? ?? false,
    );
  }
}
