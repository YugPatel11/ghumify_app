import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/chat_message_model.dart';

void main() {
  group('ChatMessageModel Sanitization & Anti-JSON Leak Tests', () {
    test('Normal conversational text is preserved as-is', () {
      const text = 'Hello! I can help you find great street food in Chandigarh.';
      final message = ChatMessageModel(
        id: '1',
        role: 'assistant',
        content: text,
      );

      expect(message.content, equals(text));
    });

    test('Raw JSON dump from bug report is sanitized into human-readable text', () {
      const rawBugJson = '''
{
  "id": "1793248400981",
  "userId": "wVsut9Hmo3dhhhko0PDdNqREpHi2",
  "city": "Chandigarh District",
  "date": "2026-10-30",
  "totalDurationMinutes": 480,
  "interests": ["Famous Places", "Local Food"],
  "travelMode": "driving",
  "pace": "moderate",
  "stops": [
    {
      "name": "Rock Garden",
      "type": "place",
      "startTime": "10:15",
      "endTime": "11:45",
      "durationMinutes": 90,
      "latitude": 30.7525,
      "longitude": 76.8101,
      "description": "Explore the sculpture garden",
      "tips": ["Wear comfortable shoes"]
    },
    {
      "name": "Sukhna Lake",
      "type": "place",
      "startTime": "12:00",
      "endTime": "13:30",
      "durationMinutes": 90,
      "latitude": 30.7421,
      "longitude": 76.8188,
      "description": "Enjoy scenic lake views",
      "tips": ["Try boating"]
    }
  ]
}
''';

      final message = ChatMessageModel(
        id: '2',
        role: 'assistant',
        content: rawBugJson,
      );

      // Verify that raw JSON syntax and sensitive fields are NOT exposed
      expect(message.content.contains('{"id"'), isFalse);
      expect(message.content.contains('wVsut9Hmo3dhhhko0PDdNqREpHi2'), isFalse);
      expect(message.content.contains('"userId"'), isFalse);
      expect(message.content.contains('"totalDurationMinutes"'), isFalse);

      // Verify that human-friendly content IS present
      expect(message.content.contains('Rock Garden'), isTrue);
      expect(message.content.contains('Sukhna Lake'), isTrue);
      expect(message.content.contains('Chandigarh District'), isTrue);
    });

    test('Truncated raw JSON is safely sanitized without crashing', () {
      const truncatedJson = '{"id":"1793248400981","userId":"wVsut9Hmo3dhhhko0PDdNqREpHi2","stops":[{"name":"Rock Garden","startTime":"10:00"';

      final message = ChatMessageModel(
        id: '3',
        role: 'assistant',
        content: truncatedJson,
      );

      expect(message.content.contains('wVsut9Hmo3dhhhko0PDdNqREpHi2'), isFalse);
      expect(message.content.contains('"userId"'), isFalse);
      expect(message.content.contains('Rock Garden'), isTrue);
    });

    test('JSON with explicit chatMessage extracts chatMessage cleanly', () {
      const jsonWithChatMessage = '''
{
  "chatMessage": "I have updated your itinerary to include Sector 17 Market in the afternoon!",
  "updatedItinerary": {
    "city": "Chandigarh",
    "stops": []
  }
}
''';

      final message = ChatMessageModel(
        id: '4',
        role: 'assistant',
        content: jsonWithChatMessage,
      );

      expect(
        message.content,
        equals('I have updated your itinerary to include Sector 17 Market in the afternoon!'),
      );
    });

    test('Empty or whitespace input returns empty string safely without error', () {
      final sanitized = ChatMessageModel.sanitizeContent('   ');
      expect(sanitized, equals(''));
    });

    test('Saved chat messages loaded via fromMap are sanitized', () {
      final storedData = {
        'id': '5',
        'role': 'assistant',
        'content': '{"userId": "12345", "stops": [{"name": "Rose Garden", "startTime": "09:00", "endTime": "10:30"}]}',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final message = ChatMessageModel.fromMap(storedData);
      expect(message.content.contains('12345'), isFalse);
      expect(message.content.contains('"userId"'), isFalse);
      expect(message.content.contains('Rose Garden'), isTrue);
    });
  });
}
