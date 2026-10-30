import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/core/models/multi_day_itinerary_model.dart';
import 'package:ghumify_app/core/models/crowd_estimate_model.dart';

void main() {
  group('Step 3: Itinerary Model Crowd Fields & Backward Compatibility', () {
    test('Old saved-itinerary JSON (no crowd fields) parses cleanly without errors', () {
      final legacyJson = {
        'id': 'legacy_trip_123',
        'userId': 'user_456',
        'city': 'Jaipur',
        'date': '2025-05-10',
        'startTime': '09:00',
        'endTime': '18:00',
        'totalDurationMinutes': 540,
        'interests': ['heritage', 'culture'],
        'travelMode': 'driving',
        'pace': 'moderate',
        'stops': [
          {
            'name': 'Hawa Mahal',
            'type': 'place',
            'startTime': '09:30',
            'endTime': '11:00',
            'durationMinutes': 90,
            'latitude': 26.9239,
            'longitude': 75.8267,
            'description': 'Palace of Winds',
            'tips': ['Visit in the morning'],
          },
          {
            'name': 'City Palace',
            'type': 'place',
            'startTime': '11:30',
            'endTime': '13:30',
            'durationMinutes': 120,
            'latitude': 26.9258,
            'longitude': 75.8236,
            'description': 'Royal residence',
          }
        ],
      };

      final model = ItineraryModel.fromMap(legacyJson);

      expect(model.id, 'legacy_trip_123');
      expect(model.city, 'Jaipur');
      expect(model.stops.length, 2);
      expect(model.avoidCrowds, isNull);
      expect(model.crowdModelVersion, isNull);
      expect(model.stops[0].estimatedCrowdLevel, isNull);
      expect(model.stops[0].crowdConfidence, isNull);
      expect(model.stops[0].crowdReason, isNull);
      expect(model.stops[0].alternatives, isNull);
    });

    test('Old saved multi-day itinerary JSON parses cleanly without errors', () {
      final legacyMultiDayJson = {
        'id': 'legacy_md_1',
        'userId': 'user_1',
        'city': 'Delhi',
        'startDate': '2025-06-01',
        'endDate': '2025-06-02',
        'numberOfDays': 2,
        'dailyStartTime': '09:00',
        'dailyEndTime': '18:00',
        'interests': ['monuments'],
        'travelMode': 'driving',
        'pace': 'moderate',
        'days': [
          {
            'id': 'd1',
            'userId': 'user_1',
            'city': 'Delhi',
            'date': '2025-06-01',
            'startTime': '09:00',
            'endTime': '18:00',
            'totalDurationMinutes': 540,
            'stops': [
              {
                'name': 'Red Fort',
                'type': 'place',
                'startTime': '10:00',
                'endTime': '12:00',
                'durationMinutes': 120,
              }
            ],
          }
        ],
      };

      final multiDayModel = MultiDayItineraryModel.fromMap(legacyMultiDayJson);
      expect(multiDayModel.id, 'legacy_md_1');
      expect(multiDayModel.avoidCrowds, isNull);
      expect(multiDayModel.crowdModelVersion, isNull);
      expect(multiDayModel.days.first.stops.first.estimatedCrowdLevel, isNull);
    });

    test('New itinerary JSON with crowd fields round-trips through toMap and fromMap', () {
      final modernStop = ItineraryStop(
        name: 'Amber Palace',
        type: 'place',
        placeId: 'curated_amber_palace',
        startTime: '09:00',
        endTime: '11:00',
        durationMinutes: 120,
        latitude: 26.9855,
        longitude: 75.8513,
        description: 'Iconic hill fort',
        estimatedCrowdLevel: 'low',
        crowdConfidence: 'medium',
        crowdReason: 'Quiet early morning opening hours',
        bestTimeNote: 'Best visited before 10:30 AM',
        alternatives: [
          {
            'placeId': 'jaigarh_fort',
            'name': 'Jaigarh Fort',
            'category': 'fort',
            'estimatedCrowdLevel': 'low',
          }
        ],
      );

      final modernItinerary = ItineraryModel(
        id: 'modern_trip_1',
        userId: 'user_999',
        city: 'Jaipur',
        date: '2026-11-02',
        startTime: '09:00',
        endTime: '18:00',
        totalDurationMinutes: 540,
        avoidCrowds: true,
        crowdModelVersion: 'v1.0-multiplicative',
        stops: [modernStop],
      );

      // Convert to map
      final map = modernItinerary.toMap();
      expect(map['avoidCrowds'], isTrue);
      expect(map['crowdModelVersion'], 'v1.0-multiplicative');

      final stopMap = (map['stops'] as List).first as Map<String, dynamic>;
      expect(stopMap['placeId'], 'curated_amber_palace');
      expect(stopMap['estimatedCrowdLevel'], 'low');
      expect(stopMap['crowdConfidence'], 'medium');
      expect(stopMap['crowdReason'], 'Quiet early morning opening hours');
      expect(stopMap['bestTimeNote'], 'Best visited before 10:30 AM');
      expect(stopMap['alternatives'], isNotEmpty);

      // Re-hydrate from map
      final parsed = ItineraryModel.fromMap(map);
      expect(parsed.avoidCrowds, isTrue);
      expect(parsed.crowdModelVersion, 'v1.0-multiplicative');

      final rehydratedStop = parsed.stops.first;
      expect(rehydratedStop.placeId, 'curated_amber_palace');
      expect(rehydratedStop.estimatedCrowdLevel, 'low');
      expect(rehydratedStop.crowdConfidence, 'medium');
      expect(rehydratedStop.crowdReason, 'Quiet early morning opening hours');
      expect(rehydratedStop.bestTimeNote, 'Best visited before 10:30 AM');
      expect(rehydratedStop.alternatives?.length, 1);
      expect(rehydratedStop.alternatives?.first['name'], 'Jaigarh Fort');
    });

    test('CrowdEstimateModel and CrowdAlternativeModel parse and serialize correctly', () {
      final estimate = CrowdEstimateModel.fromMap({
        'estimatedCrowdLevel': 'busy',
        'crowdConfidence': 'low',
        'reasons': ['Weekend afternoon rush'],
        'alternatives': [
          {
            'placeId': 'alt_1',
            'name': 'Alternative Art Gallery',
            'category': 'culture',
            'estimatedCrowdLevel': 'low',
            'suggestedStart': '14:00',
            'suggestedEnd': '15:30',
          }
        ],
      });

      expect(estimate.estimatedCrowdLevel, 'busy');
      expect(estimate.crowdConfidence, 'low');
      expect(estimate.crowdReason, 'Weekend afternoon rush');
      expect(estimate.alternatives.length, 1);
      expect(estimate.alternatives.first.name, 'Alternative Art Gallery');

      final serialized = estimate.toMap();
      expect(serialized['estimatedCrowdLevel'], 'busy');
      expect(serialized['crowdReason'], 'Weekend afternoon rush');
    });
  });
}

