import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an activity log entry within a group
class GroupActivityModel {
  final String id;
  final String actorId;
  final String actorName;
  final String action; // "itinerary_edit" | "permission_change" | "member_add" | "member_remove" | "role_change"
  final String details;
  final DateTime timestamp;

  GroupActivityModel({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory GroupActivityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupActivityModel(
      id: doc.id,
      actorId: data['actorId'] ?? '',
      actorName: data['actorName'] ?? '',
      action: data['action'] ?? '',
      details: data['details'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'actorId': actorId,
      'actorName': actorName,
      'action': action,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
