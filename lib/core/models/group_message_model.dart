import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a chat message within a group
class GroupMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String type; // "text" | "image" | "location_pin" | "live_location_share" | "itinerary_card" | "system"
  final String content;
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;
  final String? replyToMessageId;
  final Map<String, String>? replyPreview;
  final List<String> seenBy;
  final DateTime createdAt;
  final bool isDeletedForEveryone;

  GroupMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    this.type = 'text',
    required this.content,
    this.mediaUrl,
    this.metadata,
    this.replyToMessageId,
    this.replyPreview,
    this.seenBy = const [],
    DateTime? createdAt,
    this.isDeletedForEveryone = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory GroupMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoUrl: data['senderPhotoUrl'],
      type: data['type'] ?? 'text',
      content: data['content'] ?? '',
      mediaUrl: data['mediaUrl'],
      metadata: data['metadata'] as Map<String, dynamic>?,
      replyToMessageId: data['replyToMessageId'],
      replyPreview: data['replyPreview'] != null
          ? Map<String, String>.from(data['replyPreview'])
          : null,
      seenBy: List<String>.from(data['seenBy'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeletedForEveryone: data['isDeletedForEveryone'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'type': type,
      'content': content,
      'mediaUrl': mediaUrl,
      'metadata': metadata,
      'replyToMessageId': replyToMessageId,
      'replyPreview': replyPreview,
      'seenBy': seenBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeletedForEveryone': isDeletedForEveryone,
    };
  }

  bool get isSystem => type == 'system' || senderId == 'system';
  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isLocationPin => type == 'location_pin';
  bool get isItineraryCard => type == 'itinerary_card';
}
