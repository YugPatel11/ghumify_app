import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/travelers_model.dart';
import 'package:ghumify_app/core/services/gemini_service.dart';
import 'package:ghumify_app/core/services/local_chat/local_chat_assistant.dart';

void main() {
  group('Offline / Online Harmonized Fallback Tests', () {
    final geminiService = GeminiService();
    final localAssistant = LocalChatAssistant();

    test('Offline single-day itinerary generates fully valid ItineraryModel', () async {
      // Force offline execution (no Gemini API calls)
      final itinerary = await geminiService.generateItinerary(
        userId: 'test_user',
        city: 'Jaipur',
        date: '2026-11-01',
        startTime: '09:00',
        endTime: '18:00',
        interests: ['heritage', 'culture'],
        travelMode: 'driving',
        pace: 'moderate',
        budget: 5000,
        travelersData: const TravelersModel(adults: 2, minors: 1),
      );

      expect(itinerary, isNotNull);
      expect(itinerary.city, equals('Jaipur'));
      expect(itinerary.stops.length, greaterThanOrEqualTo(3));
      expect(itinerary.stops.any((s) => s.type == 'food'), isTrue);
      expect(itinerary.whatToCarry.length, equals(5));
      expect(itinerary.estimatedTotalCost, isNotNull);
      expect(itinerary.crowdModelVersion, equals('v1.0-offline'));
    });

    test('Offline multi-day itinerary generates fully valid MultiDayItineraryModel', () async {
      final multiDay = await geminiService.generateMultiDayItinerary(
        userId: 'test_user',
        city: 'Jaipur',
        startDate: '2026-11-01',
        endDate: '2026-11-03',
        numberOfDays: 3,
        dailyStartTime: '09:00',
        dailyEndTime: '18:00',
        interests: ['heritage', 'nature'],
        travelMode: 'driving',
        pace: 'moderate',
        budget: 15000,
        travelersData: const TravelersModel(adults: 2, minors: 0),
      );

      expect(multiDay, isNotNull);
      expect(multiDay.numberOfDays, equals(3));
      expect(multiDay.days.length, equals(3));
      expect(multiDay.days.first.stops.isNotEmpty, isTrue);
      expect(multiDay.overallSummary, isNotNull);
      expect(multiDay.crowdModelVersion, equals('v1.0-offline'));
    });

    test('Local chat assistant answers photo spots and what to carry offline', () async {
      final sampleItinerary = {
        'city': 'Jaipur',
        'stops': [
          {
            'name': 'Hawa Mahal',
            'type': 'monument',
            'startTime': '09:00',
            'endTime': '10:30',
            'tips': ['Best photo spot opposite wind view cafe at morning'],
          },
          {
            'name': 'Amber Fort',
            'type': 'monument',
            'startTime': '11:00',
            'endTime': '13:00',
            'tips': ['Great photography at Maota lake'],
          },
        ],
        'whatToCarry': ['💧 Water bottle', '📱 Charged phone', '👟 Walking shoes'],
      };

      // Photo query
      final photoRes = await localAssistant.handleMessage(
        userMessage: 'What are the best photo spots?',
        currentItinerary: sampleItinerary,
      );
      expect(photoRes.content.contains('photo spots'), isTrue);
      expect(photoRes.content.contains('Hawa Mahal'), isTrue);

      // Carry query
      final carryRes = await localAssistant.handleMessage(
        userMessage: 'What should I carry and pack?',
        currentItinerary: sampleItinerary,
      );
      expect(carryRes.content.contains('Water bottle'), isTrue);
    });

    test('Local chat assistant handles food addition and pace adjustments offline', () async {
      final sampleItinerary = {
        'city': 'Jaipur',
        'stops': [
          {
            'name': 'Hawa Mahal',
            'type': 'monument',
            'startTime': '09:00',
            'endTime': '10:30',
            'durationMinutes': 90,
          },
          {
            'name': 'City Palace',
            'type': 'monument',
            'startTime': '11:00',
            'endTime': '12:30',
            'durationMinutes': 90,
          },
        ],
      };

      // Add food
      final foodRes = await localAssistant.handleMessage(
        userMessage: 'Add food stop',
        currentItinerary: sampleItinerary,
      );
      expect(foodRes.updatedItinerary, isNotNull);

      // Make more relaxed
      final relaxedRes = await localAssistant.handleMessage(
        userMessage: 'Make it more relaxed',
        currentItinerary: sampleItinerary,
      );
      expect(relaxedRes.updatedItinerary, isNotNull);
    });
  });
}

