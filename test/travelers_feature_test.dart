import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/travelers_model.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/core/models/multi_day_itinerary_model.dart';
import 'package:ghumify_app/core/services/family_travel_service.dart';

void main() {
  group('TravelersModel Unit Tests', () {
    test('Default constructor sets 1 adult, 0 minors (solo trip)', () {
      const model = TravelersModel();
      expect(model.adults, equals(1));
      expect(model.minors, equals(0));
      expect(model.minorAgeBands, isEmpty);
      expect(model.isSoloTrip, isTrue);
      expect(model.isFamilyFriendly, isFalse);
      expect(model.totalCount, equals(1));
      expect(model.summary, equals('1 Adult (Solo)'));
      expect(model.compactSummary, equals('1 Adult'));
    });

    test('Clamping enforces limits: adults 1-20, minors 0-20', () {
      const belowMin = TravelersModel(adults: -5, minors: -2);
      expect(belowMin.adults, equals(1));
      expect(belowMin.minors, equals(0));

      const aboveMax = TravelersModel(adults: 99, minors: 50);
      expect(aboveMax.adults, equals(TravelersModel.maxAdults));
      expect(aboveMax.minors, equals(TravelersModel.maxMinors));
    });

    test('normalizeCount helper cleans invalid, negative, or excessive strings', () {
      expect(TravelersModel.normalizeCount('5', min: 1, max: 20, fallback: 1), equals(5));
      expect(TravelersModel.normalizeCount('-3', min: 1, max: 20, fallback: 1), equals(1));
      expect(TravelersModel.normalizeCount('99', min: 1, max: 20, fallback: 1), equals(20));
      expect(TravelersModel.normalizeCount('abc', min: 1, max: 20, fallback: 2), equals(2));
      expect(TravelersModel.normalizeCount(null, min: 1, max: 20, fallback: 1), equals(1));
      expect(TravelersModel.normalizeCount('', min: 0, max: 20, fallback: 0), equals(0));
    });

    test('Effective age bands defaults to child (6-12) if minors > 0 and skipped', () {
      const skippedBands = TravelersModel(adults: 2, minors: 2, minorAgeBands: []);
      expect(skippedBands.effectiveAgeBands, equals([MinorAgeBand.child]));
      expect(skippedBands.isAgeBandSkipped, isTrue);
      expect(skippedBands.summary, contains('Ages 6–12 (General mix)'));
    });

    test('Summary formatting handles multiple adults and minors with age bands', () {
      const family = TravelersModel(
        adults: 2,
        minors: 2,
        minorAgeBands: [MinorAgeBand.youngChild, MinorAgeBand.child],
      );
      expect(family.isSoloTrip, isFalse);
      expect(family.isFamilyFriendly, isTrue);
      expect(family.totalCount, equals(4));
      expect(family.compactSummary, equals('2 Adults, 2 Children'));
      expect(family.summary, contains('2 Adults, 2 Children (Ages 3–5 yrs, 6–12 yrs)'));
    });

    test('DPDP Privacy: Serialization stores only counts and age bands', () {
      const model = TravelersModel(
        adults: 3,
        minors: 1,
        minorAgeBands: [MinorAgeBand.teen],
      );
      final map = model.toMap();
      expect(map.keys, containsAll(['adults', 'minors', 'minorAgeBands']));
      expect(map.containsKey('name'), isFalse);
      expect(map.containsKey('dob'), isFalse);
      expect(map.containsKey('photo'), isFalse);

      final restored = TravelersModel.fromMap(map);
      expect(restored.adults, equals(3));
      expect(restored.minors, equals(1));
      expect(restored.minorAgeBands, equals([MinorAgeBand.teen]));
    });
  });

  group('MinorAgeBand Tests', () {
    test('Contains exactly 4 bands covering ages 0 to 17', () {
      expect(MinorAgeBand.all.length, equals(4));
      expect(MinorAgeBand.toddler, equals('0-2'));
      expect(MinorAgeBand.youngChild, equals('3-5'));
      expect(MinorAgeBand.child, equals('6-12'));
      expect(MinorAgeBand.teen, equals('13-17'));
    });

    test('getLabel & getShortLabel returns accurate descriptions', () {
      expect(MinorAgeBand.getLabel(MinorAgeBand.toddler), contains('0–2 yrs'));
      expect(MinorAgeBand.getLabel(MinorAgeBand.youngChild), contains('3–5 yrs'));
      expect(MinorAgeBand.getLabel(MinorAgeBand.child), contains('6–12 yrs'));
      expect(MinorAgeBand.getLabel(MinorAgeBand.teen), contains('13–17 yrs'));

      expect(MinorAgeBand.getShortLabel(MinorAgeBand.child), equals('6–12 yrs'));
    });
  });

  group('Backward Compatibility Tests (ItineraryModel & MultiDayItineraryModel)', () {
    test('ItineraryModel handles legacy map without travelers data safely', () {
      final legacyMap = {
        'id': 'legacy_1',
        'userId': 'user_1',
        'city': 'Goa',
        'date': '2026-11-01',
        'travelers': 2, // legacy scalar count
        'budget': 5000,
        'pace': 'relaxed',
        'interests': ['Beach', 'Culture'],
        'stops': [
          {
            'name': 'Calangute Beach',
            'startTime': '10:00 AM',
            'endTime': '12:00 PM',
            'durationMinutes': 120,
            'description': 'Enjoy the waves',
          }
        ],
      };

      final itinerary = ItineraryModel.fromMap(legacyMap, docId: 'legacy_1');
      expect(itinerary.adultsCount, equals(2));
      expect(itinerary.minorsCount, equals(0));
      expect(itinerary.isFamilyFriendly, isFalse);
      expect(itinerary.displayTravelersSummary, contains('2 Adults'));
      expect(itinerary.stops.first.isKidFriendly, isFalse);
      expect(itinerary.stops.first.childTicketInfo, isNull);
    });

    test('ItineraryModel handles null travelers in legacy doc without crashing', () {
      final legacyNullMap = {
        'id': 'legacy_2',
        'userId': 'user_1',
        'city': 'Jaipur',
        'date': '2026-11-05',
        'stops': [],
      };

      final itinerary = ItineraryModel.fromMap(legacyNullMap, docId: 'legacy_2');
      expect(itinerary.adultsCount, equals(1));
      expect(itinerary.minorsCount, equals(0));
      expect(itinerary.displayTravelersSummary, contains('1 Adult'));
    });

    test('MultiDayItineraryModel handles legacy map without travelers data safely', () {
      final legacyMultiDayMap = {
        'id': 'multi_legacy_1',
        'userId': 'user_1',
        'city': 'Manali',
        'days': [
          {
            'dayNumber': 1,
            'title': 'Solang Valley',
            'date': '2026-12-01',
            'stops': [
              {
                'name': 'Solang Valley Park',
                'startTime': '09:00 AM',
                'endTime': '11:00 AM',
                'durationMinutes': 120,
                'description': 'Scenic views',
              }
            ],
          }
        ],
      };

      final multiDay = MultiDayItineraryModel.fromMap(legacyMultiDayMap);
      expect(multiDay.adultsCount, equals(1));
      expect(multiDay.minorsCount, equals(0));
      expect(multiDay.isFamilyFriendly, isFalse);
      expect(multiDay.displayTravelersSummary, contains('1 Adult'));
    });

    test('ItineraryModel serializes and deserializes family travelers data accurately', () {
      final familyMap = {
        'id': 'fam_1',
        'userId': 'user_1',
        'city': 'Singapore',
        'date': '2026-12-15',
        'adultsCount': 2,
        'minorsCount': 1,
        'minorAgeBands': ['6-12'],
        'travelersSummary': '2 Adults, 1 Child (Ages 6–12 yrs)',
        'stops': [
          {
            'name': 'Singapore Zoo',
            'startTime': '09:30 AM',
            'endTime': '01:00 PM',
            'durationMinutes': 210,
            'description': 'Award-winning wildlife park',
            'isKidFriendly': true,
            'ageRangeRecommendation': 'All ages (ideal 3–12)',
            'strollerAccess': 'Fully accessible with pram ramps',
            'childTicketInfo': 'Children under 3 free, child rate applies ages 3-12',
          }
        ],
      };

      final itinerary = ItineraryModel.fromMap(familyMap, docId: 'fam_1');
      expect(itinerary.adultsCount, equals(2));
      expect(itinerary.minorsCount, equals(1));
      expect(itinerary.isFamilyFriendly, isTrue);
      expect(itinerary.minorAgeBands, equals(['6-12']));
      expect(itinerary.stops.first.isKidFriendly, isTrue);
      expect(itinerary.stops.first.strollerAccess, contains('Fully accessible'));

      final firestoreMap = itinerary.toFirestore();
      expect(firestoreMap['adultsCount'], equals(2));
      expect(firestoreMap['minorsCount'], equals(1));
      expect(firestoreMap['minorAgeBands'], equals(['6-12']));
      expect(firestoreMap['isFamilyFriendly'], isTrue);
    });
  });

  group('FamilyTravelService Tests', () {
    test('Prompt directive specifies adult-only behavior when minors = 0', () {
      const adultTrip = TravelersModel(adults: 2, minors: 0);
      final directive = FamilyTravelService.getTravelersPromptDirective(adultTrip);
      expect(directive, contains('2 adults'));
      expect(directive, isNot(contains('MANDATORY FAMILY & CHILD-FRIENDLY PLANNING DIRECTIVE')));
    });

    test('Prompt directive includes strict family rules and age adaptations when minors > 0', () {
      const familyTrip = TravelersModel(
        adults: 2,
        minors: 1,
        minorAgeBands: [MinorAgeBand.youngChild],
      );
      final directive = FamilyTravelService.getTravelersPromptDirective(familyTrip);
      expect(directive, contains('Adults: 2'));
      expect(directive, contains('Children (Minors): 1'));
      expect(directive, contains('Young Child (3–5 yrs)'));
      expect(directive, contains('MANDATORY FAMILY & CHILD-FRIENDLY PLANNING DIRECTIVE'));
      expect(directive, contains('NEVER schedule bars, pubs, nightclubs'));
      expect(directive, contains('NEVER invent fake prices'));
    });

    test('validateAndEnrichStops replaces forbidden nightlife stops when minors > 0', () {
      const familyTrip = TravelersModel(adults: 2, minors: 1);
      final rawStops = [
        ItineraryStop(
          name: 'City Botanical Gardens',
          type: 'place',
          startTime: '10:00 AM',
          endTime: '12:00 PM',
          durationMinutes: 120,
          description: 'Beautiful green park with playground',
        ),
        ItineraryStop(
          name: 'Club Oxygen Nightclub & Bar',
          type: 'place',
          startTime: '09:00 PM',
          endTime: '11:00 PM',
          durationMinutes: 120,
          description: 'Late night dancing, beer, and loud music',
        ),
      ];

      final sanitized = FamilyTravelService.validateAndEnrichStops(
        rawStops,
        familyTrip,
      );

      expect(sanitized.length, equals(2));
      expect(sanitized[0].name, equals('City Botanical Gardens'));
      expect(sanitized[0].isKidFriendly, isTrue);

      // Nightclub must be replaced with a family-friendly alternative
      expect(sanitized[1].name, isNot(contains('Nightclub')));
      expect(sanitized[1].name, isNot(contains('Bar')));
      expect(sanitized[1].isKidFriendly, isTrue);
    });

    test('validateAndEnrichStops enforces maximum pace limits for young children', () {
      const toddlerTrip = TravelersModel(
        adults: 2,
        minors: 1,
        minorAgeBands: [MinorAgeBand.toddler],
      );
      // 6 stops is too many for a toddler day (max is 4)
      final busyDayStops = List.generate(
        6,
        (i) => ItineraryStop(
          name: 'Family Spot $i',
          type: 'place',
          startTime: '${9 + i}:00 AM',
          endTime: '${10 + i}:00 AM',
          durationMinutes: 60,
          description: 'Playground and museum park',
        ),
      );

      final sanitized = FamilyTravelService.validateAndEnrichStops(
        busyDayStops,
        toddlerTrip,
      );

      expect(sanitized.length, lessThanOrEqualTo(4));
    });

    test('validateAndEnrichStops leaves adult-only itineraries unaltered', () {
      const adultTrip = TravelersModel(adults: 2, minors: 0);
      final rawStops = [
        ItineraryStop(
          name: 'Rooftop Lounge & Bar',
          type: 'place',
          startTime: '08:00 PM',
          endTime: '10:00 PM',
          durationMinutes: 120,
          description: 'Craft cocktails and skyline view',
        ),
      ];

      final result = FamilyTravelService.validateAndEnrichStops(
        rawStops,
        adultTrip,
      );

      expect(result.first.name, equals('Rooftop Lounge & Bar'));
    });
  });
}
