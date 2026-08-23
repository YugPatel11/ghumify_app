/// Represents a single message in an itinerary chat conversation
class ChatMessageModel {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? updatedItinerary; // If AI returned a modified itinerary

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.updatedItinerary,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessageModel.fromMap(Map<String, dynamic> data) {
    return ChatMessageModel(
      id: data['id'] ?? '',
      role: data['role'] ?? 'user',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'])
          : DateTime.now(),
      updatedItinerary: data['updatedItinerary'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (updatedItinerary != null) 'updatedItinerary': updatedItinerary,
    };
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasItineraryUpdate => updatedItinerary != null;
}

/// Represents an entire chat session for an itinerary
class ChatSessionModel {
  final String id;
  final String itineraryId;
  final List<ChatMessageModel> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSessionModel({
    required this.id,
    required this.itineraryId,
    this.messages = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ChatSessionModel.fromMap(Map<String, dynamic> data) {
    return ChatSessionModel(
      id: data['id'] ?? '',
      itineraryId: data['itineraryId'] ?? '',
      messages: (data['messages'] as List? ?? [])
          .map((m) => ChatMessageModel.fromMap(m as Map<String, dynamic>))
          .toList(),
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itineraryId': itineraryId,
      'messages': messages.map((m) => m.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ChatSessionModel copyWith({
    List<ChatMessageModel>? messages,
    DateTime? updatedAt,
  }) {
    return ChatSessionModel(
      id: id,
      itineraryId: itineraryId,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
