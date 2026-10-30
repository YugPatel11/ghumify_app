import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghumify_app/core/services/local_chat/intent_parser.dart';
import 'package:ghumify_app/core/services/local_chat/itinerary_editor.dart';
import 'package:ghumify_app/core/services/local_chat/local_chat_assistant.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/core/models/multi_day_itinerary_model.dart';
import 'package:ghumify_app/core/models/chat_message_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 4.1: Intent Parsing Multilingual (10+ phrases)', () {
    final parser = IntentParser();

    test('English food intent', () {
      final res = parser.parse("I'm hungry, add a food place");
      expect(res.intent, LocalChatIntent.addFood);
    });

    test('Hindi food intent (Devanagari)', () {
      final res = parser.parse("मुझे भूख लगी है खाना खाना है");
      expect(res.intent, LocalChatIntent.addFood);
    });

    test('Hinglish food intent', () {
      final res = parser.parse("bhookh lagi hai bhai lunch add karo");
      expect(res.intent, LocalChatIntent.addFood);
    });

    test('English remove stop with ordinal', () {
      final res = parser.parse("remove the second stop");
      expect(res.intent, LocalChatIntent.removeStop);
      expect(res.targetStopOrdinal, 2);
    });

    test('Hinglish remove stop', () {
      final res = parser.parse("pehla stop hata do please");
      expect(res.intent, LocalChatIntent.removeStop);
      expect(res.targetStopOrdinal, 1);
    });

    test('Replace stop intent', () {
      final res = parser.parse("replace Hawa Mahal with City Palace");
      expect(res.intent, LocalChatIntent.replaceStop);
    });

    test('Hinglish less time', () {
      final res = parser.parse("kam time hai jaldi niptao");
      expect(res.intent, LocalChatIntent.lessTime);
    });

    test('English more relaxed', () {
      final res = parser.parse("make it more relaxed and slow paced");
      expect(res.intent, LocalChatIntent.moreRelaxed);
    });

    test('Hinglish more relaxed', () {
      final res = parser.parse("araam se ghumna hai thoda time badhao");
      expect(res.intent, LocalChatIntent.moreRelaxed);
    });

    test('Nearest emergency service (hospital)', () {
      final res = parser.parse("nearest hospital kahan hai emergency");
      expect(res.intent, LocalChatIntent.nearestService);
      expect(res.serviceType, 'hospital');
    });

    test('Nearest ATM service', () {
      final res = parser.parse("where is the closest atm machine?");
      expect(res.intent, LocalChatIntent.nearestService);
      expect(res.serviceType, 'atm');
    });

    test('Help intent', () {
      final res = parser.parse("kya kar sakte ho help me");
      expect(res.intent, LocalChatIntent.help);
    });

    test('Translate cached intent', () {
      final res = parser.parse("translate this itinerary to hindi");
      expect(res.intent, LocalChatIntent.translateCached);
    });
  });

  group('Step 4.2: Stop Resolution', () {
    final parser = IntentParser();
    final stops = [
      {'name': 'Amber Palace', 'type': 'heritage'},
      {'name': 'Johari Market', 'type': 'market'},
      {'name': 'Bapu Market', 'type': 'market'},
      {'name': 'Chokhi Dhani', 'type': 'food'},
    ];

    test('Exact and substring match', () {
      final idx = parser.resolveStopIndex(
        stops: stops,
        targetName: 'Amber Palace',
      );
      expect(idx, 0);

      final idxSub = parser.resolveStopIndex(
        stops: stops,
        targetName: 'amber',
      );
      expect(idxSub, 0);
    });

    test('Ordinal resolution: second, last, pehla', () {
      expect(parser.resolveStopIndex(stops: stops, ordinal: 1), 0);
      expect(parser.resolveStopIndex(stops: stops, ordinal: 2), 1);
      expect(parser.resolveStopIndex(stops: stops, ordinal: 4), 3);
      expect(parser.resolveStopIndex(stops: stops, ordinal: -1), 3); // last
    });

    test('Ambiguity detection for duplicate matches', () {
      final match = parser.resolveStopDetailed(
        stops: stops,
        targetName: 'market',
      );
      expect(match.isAmbiguous, isTrue);
      expect(match.candidateNames.length, 2);
      expect(match.candidateNames, contains('Johari Market'));
      expect(match.candidateNames, contains('Bapu Market'));
    });
  });

  group('Step 4.3 & 4.4: Resequencing & Boundary Preservation', () {
    final testDay = {
      'id': 'test_day_1',
      'userId': 'user_1',
      'city': 'Jaipur',
      'date': '2026-11-01',
      'startTime': '09:00',
      'endTime': '18:00',
      'totalDurationMinutes': 540,
      'interests': ['culture'],
      'travelMode': 'driving',
      'pace': 'medium',
      'stops': [
        {
          'placeId': 'stop_1',
          'name': 'Hawa Mahal',
          'startTime': '09:00',
          'endTime': '10:30',
          'durationMinutes': 90,
          'travelMinutes': 0,
          'latitude': 26.9239,
          'longitude': 75.8267,
          'type': 'place',
        },
        {
          'placeId': 'stop_2',
          'name': 'City Palace',
          'startTime': '10:45',
          'endTime': '12:45',
          'durationMinutes': 120,
          'travelMinutes': 15,
          'latitude': 26.9258,
          'longitude': 75.8236,
          'type': 'place',
        },
        {
          'placeId': 'stop_3',
          'name': 'LMB Sweet Shop',
          'startTime': '13:00',
          'endTime': '14:00',
          'durationMinutes': 60,
          'travelMinutes': 15,
          'latitude': 26.9210,
          'longitude': 75.8240,
          'type': 'food',
        },
        {
          'placeId': 'stop_4',
          'name': 'Albert Hall Museum',
          'startTime': '14:30',
          'endTime': '16:30',
          'durationMinutes': 120,
          'travelMinutes': 30,
          'latitude': 26.9116,
          'longitude': 75.8195,
          'type': 'place',
        },
      ],
    };

    test('Resequencing after removing stop #2', () {
      final result = ItineraryEditor.removeStop(
        currentItineraryMap: testDay,
        stopIndex: 1, // Stop #2
      );
      expect(result.success, isTrue);
      final stops = result.updatedItinerary!['stops'] as List;
      expect(stops.length, 3);
      expect(stops[0]['name'], 'Hawa Mahal');
      expect(stops[1]['name'], 'LMB Sweet Shop');
      expect(stops[2]['name'], 'Albert Hall Museum');

      // First stop has travelMinutes 0
      expect(stops[0]['travelMinutes'], 0);
      expect(stops[0]['startTime'], '09:00');

      // Monotonic progression: stop 1 end <= stop 2 start, no overlaps
      for (int i = 0; i < stops.length - 1; i++) {
        final curEnd = stops[i]['endTime'] as String;
        final nextStart = stops[i + 1]['startTime'] as String;
        expect(curEnd.compareTo(nextStart) <= 0, isTrue);
      }
    });

    test('Boundary preservation rejects edit extending past day endTime', () {
      final tightDay = Map<String, dynamic>.from(testDay);
      tightDay['endTime'] = '14:00'; // Tight end before stops finish

      final result = ItineraryEditor.moreRelaxed(currentItineraryMap: tightDay);
      // Rejects or handles gracefully without violating boundary
      if (result.success) {
        final stops = result.updatedItinerary!['stops'] as List;
        final lastEnd = stops.last['endTime'] as String;
        expect(lastEnd.compareTo('14:00') <= 0, isTrue);
      } else {
        expect(result.message, contains('Cannot make current stops more relaxed'));
      }
    });
  });

  group('Step 4.5: Shrink Duration (LESS_TIME)', () {
    final testDay = {
      'id': 'test_day_1',
      'userId': 'user_1',
      'city': 'Jaipur',
      'date': '2026-11-01',
      'startTime': '09:00',
      'endTime': '18:00',
      'totalDurationMinutes': 540,
      'interests': ['culture'],
      'travelMode': 'driving',
      'pace': 'medium',
      'stops': [
        {
          'placeId': 'stop_1',
          'name': 'Amber Fort',
          'startTime': '09:00',
          'endTime': '12:00',
          'durationMinutes': 180,
          'travelMinutes': 0,
          'latitude': 26.9855,
          'longitude': 75.8513,
          'type': 'place',
        },
        {
          'placeId': 'stop_2',
          'name': 'Lunch Stop',
          'startTime': '12:30',
          'endTime': '14:00',
          'durationMinutes': 90,
          'travelMinutes': 30,
          'latitude': 26.9258,
          'longitude': 75.8236,
          'type': 'food',
        },
      ],
    };

    test('Shortens durations proportionally down to minimum', () {
      final result = ItineraryEditor.lessTime(currentItineraryMap: testDay);
      expect(result.success, isTrue);
      final stops = result.updatedItinerary!['stops'] as List;

      const originalTotal = 180 + 90;
      final newTotal = (stops[0]['durationMinutes'] as int) + (stops[1]['durationMinutes'] as int);

      expect(newTotal, lessThan(originalTotal));
      expect(stops[0]['durationMinutes'], lessThan(180));
      expect(stops[1]['durationMinutes'], greaterThanOrEqualTo(25));
    });
  });

  group('Step 4.6 & 4.7: Contract Preservation & Sanitization', () {
    final singleDay = {
      'id': 'sd_1',
      'userId': 'u1',
      'city': 'Jaipur',
      'date': '2026-11-01',
      'startTime': '09:00',
      'endTime': '18:00',
      'totalDurationMinutes': 540,
      'interests': ['culture'],
      'travelMode': 'driving',
      'pace': 'medium',
      'stops': [
        {
          'placeId': 'p1',
          'name': 'Hawa Mahal',
          'startTime': '09:00',
          'endTime': '10:30',
          'durationMinutes': 90,
          'travelMinutes': 0,
          'latitude': 26.9239,
          'longitude': 75.8267,
          'type': 'place',
        },
        {
          'placeId': 'p2',
          'name': 'City Palace',
          'startTime': '11:00',
          'endTime': '13:00',
          'durationMinutes': 120,
          'travelMinutes': 30,
          'latitude': 26.9258,
          'longitude': 75.8236,
          'type': 'place',
        },
      ],
    };

    final multiDay = {
      'id': 'md_1',
      'userId': 'u1',
      'city': 'Jaipur',
      'startDate': '2026-11-01',
      'endDate': '2026-11-02',
      'numberOfDays': 2,
      'dailyStartTime': '09:00',
      'dailyEndTime': '18:00',
      'interests': ['culture'],
      'travelMode': 'driving',
      'pace': 'medium',
      'days': [singleDay, singleDay],
    };

    test('Single-day edit passes ItineraryModel.fromMap', () {
      final result = ItineraryEditor.removeStop(currentItineraryMap: singleDay, stopIndex: 0);
      expect(result.success, isTrue);
      final model = ItineraryModel.fromMap(result.updatedItinerary!);
      expect(model.id, 'sd_1');
      expect(model.stops.length, 1);
      expect(model.stops.first.name, 'City Palace');
    });

    test('Multi-day edit passes MultiDayItineraryModel.fromMap', () {
      final result = ItineraryEditor.removeStop(
        currentItineraryMap: multiDay,
        stopIndex: 0,
        isMultiDay: true,
        targetDayNumber: 1,
      );
      expect(result.success, isTrue);
      final model = MultiDayItineraryModel.fromMap(result.updatedItinerary!);
      expect(model.id, 'md_1');
      expect(model.days.length, 2);
      expect(model.days[0].stops.length, 1);
    });

    test('Assistant messages sanitized against raw JSON leaks', () {
      const rawWithJson = 'I have removed the stop for you.\n{"stops": [{"name": "Palace"}]}';
      final clean = ChatMessageModel.sanitizeContent(rawWithJson);
      expect(clean.contains('{"stops":'), isFalse);
      expect(clean, contains('I have removed the stop for you.'));
    });
  });

  group('Step 4.8: No-invention Guarantee with Empty Cache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ADD_FOOD with empty cache returns honest refusal and leaves itinerary null', () async {
      final assistant = LocalChatAssistant();
      final dayItinerary = {
        'id': 'test_day',
        'city': 'RemoteVillageWithoutCache',
        'startTime': '09:00',
        'endTime': '18:00',
        'stops': [
          {
            'placeId': 'p1',
            'name': 'Unknown Ancient Temple',
            'startTime': '09:00',
            'endTime': '11:00',
            'durationMinutes': 120,
            'travelMinutes': 0,
            'latitude': 25.0,
            'longitude': 74.0,
            'type': 'place',
          }
        ],
      };

      final response = await assistant.handleMessage(
        userMessage: 'add food here',
        currentItinerary: dayItinerary,
        isMultiDay: false,
      );

      // Verify prefix
      expect(response.content, startsWith('[Offline Mode]'));
      // Verify refusal text
      expect(response.content, contains('No real places were found in offline cache'));
      // Verify itinerary was untouched
      expect(response.updatedItinerary, isNull);
    });

    test('Uncached translation request returns honest refusal', () async {
      final assistant = LocalChatAssistant();
      final response = await assistant.handleMessage(
        userMessage: 'translate this to spanish',
        currentItinerary: {'id': '1', 'city': 'Jaipur', 'stops': []},
        isMultiDay: false,
      );

      expect(response.content, startsWith('[Offline Mode]'));
      expect(response.content, contains('Offline translation is only available for previously cached phrases'));
      expect(response.updatedItinerary, isNull);
    });
  });
}
