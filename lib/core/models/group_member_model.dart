import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a member within a group
class GroupMemberModel {
  final String userId;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String role; // "owner" | "admin" | "member"
  final bool canEditItinerary;
  final bool isMuted;
  final String foodPreference;
  final DateTime joinedAt;
  final DateTime lastSeenAt;

  GroupMemberModel({
    required this.userId,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.role = 'member',
    this.canEditItinerary = false,
    this.isMuted = false,
    this.foodPreference = 'all',
    DateTime? joinedAt,
    DateTime? lastSeenAt,
  })  : joinedAt = joinedAt ?? DateTime.now(),
        lastSeenAt = lastSeenAt ?? DateTime.now();

  factory GroupMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupMemberModel(
      userId: data['userId'] ?? doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      role: data['role'] ?? 'member',
      canEditItinerary: data['canEditItinerary'] ?? false,
      isMuted: data['isMuted'] ?? false,
      foodPreference: data['foodPreference'] ?? 'all',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'canEditItinerary': canEditItinerary,
      'isMuted': isMuted,
      'foodPreference': foodPreference,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
    };
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';

  GroupMemberModel copyWith({
    String? displayName,
    String? photoUrl,
    String? role,
    bool? canEditItinerary,
    bool? isMuted,
    String? foodPreference,
    DateTime? lastSeenAt,
  }) {
    return GroupMemberModel(
      userId: userId,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      canEditItinerary: canEditItinerary ?? this.canEditItinerary,
      isMuted: isMuted ?? this.isMuted,
      foodPreference: foodPreference ?? this.foodPreference,
      joinedAt: joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
