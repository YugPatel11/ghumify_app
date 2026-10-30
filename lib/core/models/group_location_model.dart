import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a live location share within a group
class GroupLocationModel {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final int? batteryLevel;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime updatedAt;
  final bool isActive;

  GroupLocationModel({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.batteryLevel,
    DateTime? startedAt,
    required this.expiresAt,
    DateTime? updatedAt,
    this.isActive = true,
  })  : startedAt = startedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory GroupLocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupLocationModel(
      userId: data['userId'] ?? doc.id,
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      heading: (data['heading'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      batteryLevel: data['batteryLevel'],
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'batteryLevel': batteryLevel,
      'startedAt': Timestamp.fromDate(startedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'isActive': isActive,
    };
  }

  /// Check if the live share has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if the share is still valid (active and not expired)
  bool get isLive => isActive && !isExpired;
}
