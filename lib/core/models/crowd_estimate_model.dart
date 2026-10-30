/// Represents a crowd estimate and alternatives for an itinerary stop
class CrowdEstimateModel {
  final String estimatedCrowdLevel; // 'low', 'moderate', 'busy', 'very_busy'
  final String crowdConfidence;     // 'low', 'medium'
  final String? crowdReason;
  final String? bestTimeNote;
  final List<CrowdAlternativeModel> alternatives;

  const CrowdEstimateModel({
    required this.estimatedCrowdLevel,
    this.crowdConfidence = 'low',
    this.crowdReason,
    this.bestTimeNote,
    this.alternatives = const [],
  });

  factory CrowdEstimateModel.fromMap(Map<String, dynamic> map) {
    return CrowdEstimateModel(
      estimatedCrowdLevel: map['estimatedCrowdLevel'] ?? map['level'] ?? 'moderate',
      crowdConfidence: map['crowdConfidence'] ?? map['confidence'] ?? 'low',
      crowdReason: map['crowdReason'] ??
          (map['reasons'] is List && (map['reasons'] as List).isNotEmpty
              ? map['reasons'].first.toString()
              : null),
      bestTimeNote: map['bestTimeNote'],
      alternatives: (map['alternatives'] as List? ?? [])
          .map((a) => CrowdAlternativeModel.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'estimatedCrowdLevel': estimatedCrowdLevel,
      'crowdConfidence': crowdConfidence,
      if (crowdReason != null) 'crowdReason': crowdReason,
      if (bestTimeNote != null) 'bestTimeNote': bestTimeNote,
      'alternatives': alternatives.map((a) => a.toMap()).toList(),
    };
  }
}

/// Represents an alternative place with lower estimated crowd
class CrowdAlternativeModel {
  final String placeId;
  final String name;
  final String category;
  final String estimatedCrowdLevel;
  final String? suggestedStart;
  final String? suggestedEnd;
  final List<String> reasons;

  const CrowdAlternativeModel({
    required this.placeId,
    required this.name,
    required this.category,
    required this.estimatedCrowdLevel,
    this.suggestedStart,
    this.suggestedEnd,
    this.reasons = const [],
  });

  factory CrowdAlternativeModel.fromMap(Map<String, dynamic> map) {
    return CrowdAlternativeModel(
      placeId: map['placeId'] ?? map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      estimatedCrowdLevel: map['estimatedCrowdLevel'] ?? 'low',
      suggestedStart: map['suggestedStart'],
      suggestedEnd: map['suggestedEnd'],
      reasons: List<String>.from(map['reasons'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'category': category,
      'estimatedCrowdLevel': estimatedCrowdLevel,
      if (suggestedStart != null) 'suggestedStart': suggestedStart,
      if (suggestedEnd != null) 'suggestedEnd': suggestedEnd,
      'reasons': reasons,
    };
  }
}

