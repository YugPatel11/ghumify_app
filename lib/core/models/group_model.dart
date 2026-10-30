import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a group in the Ghumify app
class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? photoUrl;
  final String ownerId;
  final List<String> adminIds;
  final List<String> memberIds;
  final List<String> memberEmails;
  final String itineraryEditPolicy; // "admins_only" | "all_members" | "selected_members"
  final List<String> editableMemberIds;
  final String? sharedItineraryId;
  final String? lastItineraryEditBy;
  final String? lastItineraryEditByName;
  final DateTime? lastItineraryEditAt;
  final String? lastMessageText;
  final String? lastMessageSenderName;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.photoUrl,
    required this.ownerId,
    this.adminIds = const [],
    this.memberIds = const [],
    this.memberEmails = const [],
    this.itineraryEditPolicy = 'admins_only',
    this.editableMemberIds = const [],
    this.sharedItineraryId,
    this.lastItineraryEditBy,
    this.lastItineraryEditByName,
    this.lastItineraryEditAt,
    this.lastMessageText,
    this.lastMessageSenderName,
    this.lastMessageAt,
    this.unreadCounts = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      photoUrl: data['photoUrl'],
      ownerId: data['ownerId'] ?? '',
      adminIds: List<String>.from(data['adminIds'] ?? []),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      memberEmails: List<String>.from(data['memberEmails'] ?? []),
      itineraryEditPolicy: data['itineraryEditPolicy'] ?? 'admins_only',
      editableMemberIds: List<String>.from(data['editableMemberIds'] ?? []),
      sharedItineraryId: data['sharedItineraryId'],
      lastItineraryEditBy: data['lastItineraryEditBy'],
      lastItineraryEditByName: data['lastItineraryEditByName'],
      lastItineraryEditAt: (data['lastItineraryEditAt'] as Timestamp?)?.toDate(),
      lastMessageText: data['lastMessageText'],
      lastMessageSenderName: data['lastMessageSenderName'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCounts: Map<String, int>.from(
        (data['unreadCounts'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'photoUrl': photoUrl,
      'ownerId': ownerId,
      'adminIds': adminIds,
      'memberIds': memberIds,
      'memberEmails': memberEmails,
      'itineraryEditPolicy': itineraryEditPolicy,
      'editableMemberIds': editableMemberIds,
      'sharedItineraryId': sharedItineraryId,
      'lastItineraryEditBy': lastItineraryEditBy,
      'lastItineraryEditByName': lastItineraryEditByName,
      'lastItineraryEditAt': lastItineraryEditAt != null
          ? Timestamp.fromDate(lastItineraryEditAt!)
          : null,
      'lastMessageText': lastMessageText,
      'lastMessageSenderName': lastMessageSenderName,
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : null,
      'unreadCounts': unreadCounts,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// Check if a user is an admin (includes owner)
  bool isAdmin(String userId) => adminIds.contains(userId) || ownerId == userId;

  /// Check if a user is a member
  bool isMember(String userId) => memberIds.contains(userId);

  /// Check if a user can edit the itinerary
  bool canEditItinerary(String userId) {
    if (isAdmin(userId)) return true;
    switch (itineraryEditPolicy) {
      case 'all_members':
        return isMember(userId);
      case 'selected_members':
        return editableMemberIds.contains(userId);
      case 'admins_only':
      default:
        return false;
    }
  }

  /// Get unread count for a user
  int getUnreadCount(String userId) => unreadCounts[userId] ?? 0;

  GroupModel copyWith({
    String? name,
    String? description,
    String? photoUrl,
    List<String>? adminIds,
    List<String>? memberIds,
    List<String>? memberEmails,
    String? itineraryEditPolicy,
    List<String>? editableMemberIds,
    String? sharedItineraryId,
    String? lastMessageText,
    String? lastMessageSenderName,
    DateTime? lastMessageAt,
    Map<String, int>? unreadCounts,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      ownerId: ownerId,
      adminIds: adminIds ?? this.adminIds,
      memberIds: memberIds ?? this.memberIds,
      memberEmails: memberEmails ?? this.memberEmails,
      itineraryEditPolicy: itineraryEditPolicy ?? this.itineraryEditPolicy,
      editableMemberIds: editableMemberIds ?? this.editableMemberIds,
      sharedItineraryId: sharedItineraryId ?? this.sharedItineraryId,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      createdAt: createdAt,
    );
  }
}
