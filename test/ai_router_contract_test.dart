import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/core/models/multi_day_itinerary_model.dart';
import 'package:ghumify_app/core/models/chat_message_model.dart';
import 'package:ghumify_app/core/models/nearby_service_model.dart';
import 'package:ghumify_app/core/models/place_model.dart';

void main() {
  group('Backend AI Router -> Flutter Models Contract Tests', () {
    test('ItineraryStop and ItineraryModel parse backend single-day output', () {
      final backendStopJson = {
        'name': 'Hawa Mahal',
        'type': 'place',
        'placeId': 'osm_node_101',
        'startTime': '09:00',
        'endTime': '10:30',
        'durationMinutes': 90,
        'latitude': 26.9239,
        'longitude': 75.8267,
        'description': 'Palace of Winds in Jaipur',
        'photoUrl': 'https://example.com/hawa.jpg',
        'travelMode': 'driving',
        'travelMinutes': 15,
        'tips': ['Best photographed in morning light'],
        'estimatedCost': 100,
      };

      final stop = ItineraryStop.fromMap(backendStopJson);
      expect(stop.name, equals('Hawa Mahal'));
      expect(stop.type, equals('place'));
      expect(stop.placeId, equals('osm_node_101'));
      expect(stop.durationMinutes, equals(90));
      expect(stop.latitude, equals(26.9239));
      expect(stop.longitude, equals(75.8267));
      expect(stop.estimatedCost, equals(100));

      final backendItineraryJson = {
        'id': 'itinerary_123',
        'userId': 'user_demo',
        'city': 'Jaipur',
        'date': '2026-10-31',
        'startTime': '09:00',
        'endTime': '18:00',
        'totalDurationMinutes': 540,
        'interests': ['heritage', 'culture'],
        'travelMode': 'driving',
        'pace': 'moderate',
        'stops': [backendStopJson],
        'weatherSummary': 'Pleasant day',
        'whatToCarry': ['Water bottle', 'Phone'],
        'aiSummary': 'A great day in Jaipur',
        'isSaved': false,
        'dayNumber': 1,
        'currency': 'INR',
        'estimatedTotalCost': 1500,
        'remainingBudget': 500,
        'expenseSummary': {
          'food': 500,
          'transport': 400,
          'activities': 500,
          'other': 100,
          'total': 1500,
        },
      };

      // Ensure model creates and serializes symmetrically
      final stopFromMap = ItineraryStop.fromMap(backendStopJson);
      final model = ItineraryModel(
        id: backendItineraryJson['id'] as String,
        userId: backendItineraryJson['userId'] as String,
        city: backendItineraryJson['city'] as String,
        date: backendItineraryJson['date'] as String,
        startTime: backendItineraryJson['startTime'] as String,
        endTime: backendItineraryJson['endTime'] as String,
        totalDurationMinutes: backendItineraryJson['totalDurationMinutes'] as int,
        interests: List<String>.from(backendItineraryJson['interests'] as List),
        travelMode: backendItineraryJson['travelMode'] as String,
        pace: backendItineraryJson['pace'] as String,
        stops: [stopFromMap],
        weatherSummary: backendItineraryJson['weatherSummary'] as String?,
        whatToCarry: List<String>.from(backendItineraryJson['whatToCarry'] as List),
        aiSummary: backendItineraryJson['aiSummary'] as String?,
        expenseSummary: backendItineraryJson['expenseSummary'] as Map<String, dynamic>?,
        estimatedTotalCost: backendItineraryJson['estimatedTotalCost'] as int?,
        remainingBudget: backendItineraryJson['remainingBudget'] as int?,
      );

      expect(model.city, equals('Jaipur'));
      expect(model.stops.length, equals(1));
      expect(model.stops.first.name, equals('Hawa Mahal'));
      expect(model.expenseSummary?['total'], equals(1500));
    });

    test('MultiDayItineraryModel parses backend multi-day output', () {
      final backendMultiDayJson = {
        'id': 'multiday_456',
        'userId': 'user_demo',
        'city': 'Jaipur',
        'startDate': '2026-10-31',
        'endDate': '2026-11-01',
        'numberOfDays': 2,
        'dailyStartTime': '09:00',
        'dailyEndTime': '18:00',
        'interests': ['heritage'],
        'travelMode': 'driving',
        'pace': 'moderate',
        'overallSummary': '2 days exploring Jaipur',
        'weatherSummary': 'Clear skies',
        'whatToCarry': ['Comfortable shoes', 'Sunscreen'],
        'overallExpenseSummary': {
          'food': 1000,
          'transport': 800,
          'activities': 1000,
          'other': 200,
          'total': 3000,
        },
        'days': [
          {
            'id': 'day_1',
            'userId': 'user_demo',
            'city': 'Jaipur',
            'date': '2026-10-31',
            'startTime': '09:00',
            'endTime': '18:00',
            'totalDurationMinutes': 540,
            'interests': ['heritage'],
            'travelMode': 'driving',
            'pace': 'moderate',
            'dayNumber': 1,
            'aiSummary': 'Day 1 Forts',
            'stops': [
              {
                'name': 'Amber Fort',
                'type': 'place',
                'startTime': '09:00',
                'endTime': '11:00',
                'durationMinutes': 120,
                'description': 'Majestic hill fort',
              }
            ],
          }
        ],
      };

      final multiDay = MultiDayItineraryModel.fromMap(backendMultiDayJson);
      expect(multiDay.numberOfDays, equals(2));
      expect(multiDay.days.length, equals(1));
      expect(multiDay.days.first.stops.first.name, equals('Amber Fort'));
      expect(multiDay.overallExpenseSummary?['total'], equals(3000));
    });

    test('ChatMessageModel parses message with updatedItinerary from AI router', () {
      final backendChatJson = {
        'id': 'msg_789',
        'role': 'assistant',
        'content': 'I have updated your itinerary with a food stop at LMB!',
        'timestamp': DateTime.now().toIso8601String(),
        'updatedItinerary': {
          'city': 'Jaipur',
          'stops': [
            {'name': 'Laxmi Mishthan Bhandar', 'type': 'food', 'startTime': '13:00', 'endTime': '14:00', 'durationMinutes': 60}
          ]
        },
      };

      final chatMsg = ChatMessageModel.fromMap(backendChatJson);
      expect(chatMsg.isAssistant, isTrue);
      expect(chatMsg.hasItineraryUpdate, isTrue);
      expect(chatMsg.updatedItinerary?['city'], equals('Jaipur'));
    });

    test('NearbyServiceModel parses emergency services', () {
      final element = {
        'type': 'node',
        'id': 12345,
        'lat': 26.9124,
        'lon': 75.7873,
        'tags': {
          'name': 'SMS Hospital',
          'amenity': 'hospital',
          'addr:street': 'Tonk Road',
        },
      };

      final service = NearbyServiceModel.fromOverpassElement(element);
      expect(service.name, equals('SMS Hospital'));
      expect(service.type, equals('hospital'));
      expect(service.latitude, equals(26.9124));
      expect(service.longitude, equals(75.7873));
    });

    test('PlaceModel parses normalized Google Places response', () {
      final googlePlaceJson = {
        'place_id': 'place_amber_fort',
        'name': 'Amer Fort',
        'formatted_address': 'Devisinghpura, Amer, Jaipur',
        'geometry': {
          'location': {'lat': 26.9855, 'lng': 75.8513}
        },
        'rating': 4.6,
        'user_ratings_total': 32000,
        'types': ['tourist_attraction', 'point_of_interest'],
      };

      final place = PlaceModel.fromGooglePlaces(googlePlaceJson, 'Jaipur');
      expect(place.id, equals('place_amber_fort'));
      expect(place.name, equals('Amer Fort'));
      expect(place.city, equals('Jaipur'));
      expect(place.category, equals('heritage'));
      expect(place.rating, equals(4.6));
    });
  });
}

