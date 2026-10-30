import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a pending group invitation
class GroupInvitationModel {
  final String id;
  final String groupId;
  final String groupName;
  final String? groupPhotoUrl;
  final String inviterId;
  final String inviterName;
  final String inviteeEmail; // normalized lowercase
  final String? inviteeUserId;
  final String status; // "pending" | "accepted" | "declined" | "expired"
  final DateTime createdAt;
  final DateTime expiresAt;

  GroupInvitationModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    this.groupPhotoUrl,
    required this.inviterId,
    required this.inviterName,
    required this.inviteeEmail,
    this.inviteeUserId,
    this.status = 'pending',
    DateTime? createdAt,
    DateTime? expiresAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(days: 7));

  factory GroupInvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupInvitationModel(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      groupPhotoUrl: data['groupPhotoUrl'],
      inviterId: data['inviterId'] ?? '',
      inviterName: data['inviterName'] ?? '',
      inviteeEmail: data['inviteeEmail'] ?? '',
      inviteeUserId: data['inviteeUserId'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'groupPhotoUrl': groupPhotoUrl,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'inviteeEmail': inviteeEmail,
      'inviteeUserId': inviteeUserId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  bool get isPending => status == 'pending';
  bool get isExpired => status == 'expired' || DateTime.now().isAfter(expiresAt);
}
