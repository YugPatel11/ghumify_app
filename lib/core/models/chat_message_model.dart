import 'dart:convert';

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
    required String content,
    DateTime? timestamp,
    this.updatedItinerary,
  })  : content = sanitizeContent(content),
        timestamp = timestamp ?? DateTime.now();

  /// Safely sanitizes raw content to prevent any internal JSON or data objects
  /// from being displayed in the chat interface.
  static String sanitizeContent(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    // Check if the text looks like a serialized JSON object or map
    final looksLikeJson = (trimmed.startsWith('{') || trimmed.startsWith('[')) &&
        (trimmed.contains('"userId"') ||
            trimmed.contains('"stops"') ||
            trimmed.contains('"interests"') ||
            trimmed.contains('"travelMode"') ||
            trimmed.contains('"placeId"') ||
            trimmed.contains('"totalDurationMinutes"') ||
            trimmed.contains('"days"'));

    if (!looksLikeJson) return raw;

    try {
      final parsed = json.decode(trimmed);
      if (parsed is Map<String, dynamic>) {
        if (parsed['chatMessage'] is String &&
            (parsed['chatMessage'] as String).trim().isNotEmpty) {
          return (parsed['chatMessage'] as String).trim();
        }
        if (parsed['aiSummary'] is String &&
            (parsed['aiSummary'] as String).trim().isNotEmpty) {
          return (parsed['aiSummary'] as String).trim();
        }
        if (parsed['overallSummary'] is String &&
            (parsed['overallSummary'] as String).trim().isNotEmpty) {
          return (parsed['overallSummary'] as String).trim();
        }

        // If it contains stops, format them into a human-readable list
        final stops = parsed['stops'] as List?;
        if (stops != null && stops.isNotEmpty) {
          final buffer = StringBuffer();
          final city = parsed['city'] as String?;
          if (city != null && city.isNotEmpty) {
            buffer.writeln("Here is your updated itinerary for $city:\n");
          } else {
            buffer.writeln("Here is your updated itinerary:\n");
          }

          for (final s in stops) {
            if (s is Map) {
              final name = s['name'] ?? 'Stop';
              final start = s['startTime'] ?? '';
              final end = s['endTime'] ?? '';
              final timeStr = (start.isNotEmpty && end.isNotEmpty) ? ' ($start - $end)' : '';
              buffer.writeln('• $name$timeStr');
            }
          }
          return buffer.toString().trim();
        }
      }
    } catch (_) {
      // Truncated or malformed JSON - fallback to regex extraction of place names
      final nameMatches = RegExp(r'"name"\s*:\s*"([^"]+)"').allMatches(trimmed);
      if (nameMatches.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln("Here is your updated itinerary stops:\n");
        for (final m in nameMatches) {
          final name = m.group(1);
          if (name != null && name.isNotEmpty && name != 'Place Name') {
            buffer.writeln('• $name');
          }
        }
        return buffer.toString().trim();
      }
    }

    // Friendly fallback message if extraction failed
    return "I've updated your itinerary based on your request. Tap 'Apply Changes to Itinerary' below to view and apply your updated schedule.";
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> data) {
    return ChatMessageModel(
      id: data['id'] ?? '',
      role: data['role'] ?? 'user',
      content: sanitizeContent(data['content'] ?? ''),
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
