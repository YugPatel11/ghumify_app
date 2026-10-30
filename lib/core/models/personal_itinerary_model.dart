import 'package:cloud_firestore/cloud_firestore.dart';

/// Meeting point where a member with a personal itinerary rejoins the group
class MeetingPointModel {
  final String id;
  final String placeName;
  final double latitude;
  final double longitude;
  final String? address;
  final String meetTime; // e.g. "17:00" or "5:00 PM"
  final String? meetDate; // e.g. "Day 1" or "2026-11-01"
  final String? rejoinStopName; // Name of group stop where member rejoins
  final String? notes; // e.g. "Near the main entrance ticket booth"

  MeetingPointModel({
    required this.id,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.meetTime,
    this.meetDate,
    this.rejoinStopName,
    this.notes,
  });

  /// Official Google Maps search URL (works without API key)
  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  /// Official Google Maps turn-by-turn directions URL
  String get directionsUrl =>
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

  factory MeetingPointModel.fromMap(Map<String, dynamic> map) {
    return MeetingPointModel(
      id: map['id'] ?? '',
      placeName: map['placeName'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'],
      meetTime: map['meetTime'] ?? '',
      meetDate: map['meetDate'],
      rejoinStopName: map['rejoinStopName'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placeName': placeName,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'meetTime': meetTime,
      'meetDate': meetDate,
      'rejoinStopName': rejoinStopName,
      'notes': notes,
    };
  }

  MeetingPointModel copyWith({
    String? id,
    String? placeName,
    double? latitude,
    double? longitude,
    String? address,
    String? meetTime,
    String? meetDate,
    String? rejoinStopName,
    String? notes,
  }) {
    return MeetingPointModel(
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      meetTime: meetTime ?? this.meetTime,
      meetDate: meetDate ?? this.meetDate,
      rejoinStopName: rejoinStopName ?? this.rejoinStopName,
      notes: notes ?? this.notes,
    );
  }
}

/// Represents a member's customized personal plan overlaid on the shared group itinerary
class PersonalItineraryModel {
  final String id; // Matches member userId
  final String userId;
  final String userName;
  final String groupId;
  final String status; // "active" | "needs_review"
  final String? reviewReason;
  final List<MeetingPointModel> meetingPoints;
  final List<Map<String, dynamic>> customStops;
  final List<String> removedStopNames;
  final List<String> addedStopNames;
  final List<String> modifiedStopNames;
  final DateTime updatedAt;

  PersonalItineraryModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.groupId,
    this.status = 'active',
    this.reviewReason,
    this.meetingPoints = const [],
    this.customStops = const [],
    this.removedStopNames = const [],
    this.addedStopNames = const [],
    this.modifiedStopNames = const [],
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Whether this personal plan has changes compared to the group plan
  bool get hasDiverged =>
      addedStopNames.isNotEmpty ||
      removedStopNames.isNotEmpty ||
      modifiedStopNames.isNotEmpty ||
      customStops.any((s) => s['statusTag'] != null && s['statusTag'] != 'unchanged');

  /// Whether the plan is currently marked as needing member review due to upstream group edits
  bool get needsReview => status == 'needs_review';

  /// First/primary meeting point summary text for display
  String get meetingSummaryText {
    if (meetingPoints.isEmpty) return 'No meeting point scheduled';
    final mp = meetingPoints.first;
    final timeStr = mp.meetTime.isNotEmpty ? 'at ${mp.meetTime}' : '';
    final placeStr = mp.placeName.isNotEmpty ? 'at ${mp.placeName}' : '';
    return '$userName rejoins the group $placeStr $timeStr'.trim();
  }

  factory PersonalItineraryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PersonalItineraryModel.fromMap(doc.id, data);
  }

  factory PersonalItineraryModel.fromMap(String docId, Map<String, dynamic> data) {
    return PersonalItineraryModel(
      id: docId,
      userId: data['userId'] ?? docId,
      userName: data['userName'] ?? 'Member',
      groupId: data['groupId'] ?? '',
      status: data['status'] ?? 'active',
      reviewReason: data['reviewReason'],
      meetingPoints: (data['meetingPoints'] as List<dynamic>? ?? [])
          .map((m) => MeetingPointModel.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      customStops: (data['customStops'] as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList(),
      removedStopNames: List<String>.from(data['removedStopNames'] ?? []),
      addedStopNames: List<String>.from(data['addedStopNames'] ?? []),
      modifiedStopNames: List<String>.from(data['modifiedStopNames'] ?? []),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'groupId': groupId,
      'status': status,
      'reviewReason': reviewReason,
      'meetingPoints': meetingPoints.map((m) => m.toMap()).toList(),
      'customStops': customStops,
      'removedStopNames': removedStopNames,
      'addedStopNames': addedStopNames,
      'modifiedStopNames': modifiedStopNames,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PersonalItineraryModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? groupId,
    String? status,
    String? reviewReason,
    List<MeetingPointModel>? meetingPoints,
    List<Map<String, dynamic>>? customStops,
    List<String>? removedStopNames,
    List<String>? addedStopNames,
    List<String>? modifiedStopNames,
    DateTime? updatedAt,
  }) {
    return PersonalItineraryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      reviewReason: reviewReason ?? this.reviewReason,
      meetingPoints: meetingPoints ?? this.meetingPoints,
      customStops: customStops ?? this.customStops,
      removedStopNames: removedStopNames ?? this.removedStopNames,
      addedStopNames: addedStopNames ?? this.addedStopNames,
      modifiedStopNames: modifiedStopNames ?? this.modifiedStopNames,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
