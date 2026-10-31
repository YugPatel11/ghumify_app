import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/core/services/location_service.dart';
import 'package:ghumify_app/core/utils/route_proximity_optimizer.dart';

void main() {
  group('RouteProximityOptimizer Nearest-Neighbor Ordering', () {
    test('orders stops nearest-neighbor from start point on known coordinates', () {
      // Start at (15.5000, 73.8000)
      const startLat = 15.5000;
      const startLng = 73.8000;
      const startLabel = 'User Location';

      // Stop B is closest to Start (distance ~1.5 km)
      final stopB = ItineraryStop(
        name: 'Baga Viewpoint',
        type: 'sightseeing',
        latitude: 15.5100,
        longitude: 73.8100,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );

      // Stop A is farther from Start (distance ~15 km), but closer to B
      final stopA = ItineraryStop(
        name: 'Anjuna Flea Market',
        type: 'shopping',
        latitude: 15.5800,
        longitude: 73.7400,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        durationMinutes: 60,
      );

      // Stop C is far north (distance ~35 km)
      final stopC = ItineraryStop(
        name: 'Chapora Fort',
        type: 'historical',
        latitude: 15.6050,
        longitude: 73.7350,
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        durationMinutes: 60,
      );

      // Input in mixed order: C, A, B
      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: [stopC, stopA, stopB],
        startLat: startLat,
        startLng: startLng,
        startPointLabel: startLabel,
      );

      // Expected order: Stop B (closest to start) -> Stop A (closest to B) -> Stop C (closest to A)
      expect(result.orderedStops.length, 3);
      expect(result.orderedStops[0].name, 'Baga Viewpoint');
      expect(result.orderedStops[1].name, 'Anjuna Flea Market');
      expect(result.orderedStops[2].name, 'Chapora Fort');

      // Verify distance and travel time calculated
      expect(result.orderedStops[0].distanceFromPrevKm, isNotNull);
      expect(result.orderedStops[0].distanceFromPrevKm! > 0, isTrue);
      expect(result.orderedStops[0].travelTimeFromPrev, isNotNull);
    });

    test('breaks distance ties deterministically by place name alphabetically', () {
      const startLat = 15.5000;
      const startLng = 73.8000;
      const startLabel = 'Center';

      // Two stops at exact same coordinates (distance = 0 difference)
      final stopZ = ItineraryStop(
        name: 'Zuari River Cruise',
        type: 'activity',
        latitude: 15.5200,
        longitude: 73.8200,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );
      final stopA = ItineraryStop(
        name: 'Aguada Lighthouse',
        type: 'sightseeing',
        latitude: 15.5200,
        longitude: 73.8200,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: [stopZ, stopA],
        startLat: startLat,
        startLng: startLng,
        startPointLabel: startLabel,
      );

      // Should break tie alphabetically: Aguada Lighthouse before Zuari River Cruise
      expect(result.orderedStops[0].name, 'Aguada Lighthouse');
      expect(result.orderedStops[1].name, 'Zuari River Cruise');
    });

    test('handles edge case of zero stops safely without throwing', () {
      const startLat = 15.5000;
      const startLng = 73.8000;

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: [],
        startLat: startLat,
        startLng: startLng,
        startPointLabel: 'Start',
      );

      expect(result.orderedStops, isEmpty);
      expect(result.totalDistanceKm, 0.0);
    });

    test('handles edge case of single stop', () {
      const startLat = 15.5000;
      const startLng = 73.8000;

      final singleStop = ItineraryStop(
        name: 'Calangute Beach',
        type: 'beach',
        latitude: 15.5430,
        longitude: 73.7554,
        startTime: '09:00 AM',
        endTime: '10:30 AM',
        durationMinutes: 90,
      );

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: [singleStop],
        startLat: startLat,
        startLng: startLng,
        startPointLabel: 'Start',
      );

      expect(result.orderedStops.length, 1);
      expect(result.orderedStops[0].name, 'Calangute Beach');
      expect(result.orderedStops[0].distanceFromPrevKm, isNotNull);
      expect(result.orderedStops[0].distanceFromPrevKm! > 0, isTrue);
    });

    test('handles duplicate places and invalid/missing coordinates safely', () {
      const startLat = 15.5000;
      const startLng = 73.8000;

      final stop1 = ItineraryStop(
        name: 'Market',
        type: 'shopping',
        latitude: null,
        longitude: null,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );

      final stop2 = ItineraryStop(
        name: 'Fort',
        type: 'historical',
        latitude: 15.5100,
        longitude: 73.8100,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        durationMinutes: 60,
      );

      final stopDuplicate = ItineraryStop(
        name: 'Fort',
        type: 'historical',
        latitude: 15.5100,
        longitude: 73.8100,
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        durationMinutes: 60,
      );

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: [stop1, stop2, stopDuplicate],
        startLat: startLat,
        startLng: startLng,
        startPointLabel: 'Start',
      );

      expect(result.orderedStops.length, 3);
      // Valid coordinates are ordered first by proximity
      expect(result.orderedStops[0].name, 'Fort');
      expect(result.orderedStops[1].name, 'Fort');
      expect(result.orderedStops[2].name, 'Market');
    });
  });

  group('Anchored Items & Segments Protection', () {
    test('anchored stops (meals, pinned stops, travel legs) stay in fixed positions', () {
      const startLat = 15.4000;
      const startLng = 73.8000;

      final freeStopFar = ItineraryStop(
        name: 'Far North Beach',
        type: 'beach',
        latitude: 15.7000,
        longitude: 73.7000,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );

      final freeStopNear = ItineraryStop(
        name: 'Near Museum',
        type: 'museum',
        latitude: 15.4200,
        longitude: 73.8100,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        durationMinutes: 60,
      );

      // Anchored lunch stop at index 2
      final anchoredLunch = ItineraryStop(
        name: 'Lunch at Coastal Spice',
        type: 'food',
        isAnchored: true,
        latitude: 15.5000,
        longitude: 73.8300,
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        durationMinutes: 60,
      );

      final freeStopAfterLunch1 = ItineraryStop(
        name: 'Dona Paula Viewpoint',
        type: 'viewpoint',
        latitude: 15.4500,
        longitude: 73.8000,
        startTime: '02:30 PM',
        endTime: '03:30 PM',
        durationMinutes: 60,
      );

      final freeStopAfterLunch2 = ItineraryStop(
        name: 'Miramar Beach',
        type: 'beach',
        latitude: 15.4800,
        longitude: 73.8100,
        startTime: '04:00 PM',
        endTime: '05:00 PM',
        durationMinutes: 60,
      );

      // Input list with lunch at index 2
      final input = [
        freeStopFar,
        freeStopNear,
        anchoredLunch,
        freeStopAfterLunch1,
        freeStopAfterLunch2,
      ];

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: input,
        startLat: startLat,
        startLng: startLng,
        startPointLabel: 'Start',
      );

      // Lunch must remain strictly at index 2
      expect(result.orderedStops[2].name, 'Lunch at Coastal Spice');
      expect(result.orderedStops[2].isAnchored, isTrue);

      // Morning stops (before lunch) reordered: Near Museum should be first, Far North Beach second
      expect(result.orderedStops[0].name, 'Near Museum');
      expect(result.orderedStops[1].name, 'Far North Beach');

      // Afternoon stops (after lunch): Miramar Beach is closer to Coastal Spice (15.50, 73.83) than Dona Paula (15.45)
      expect(result.orderedStops[3].name, 'Miramar Beach');
      expect(result.orderedStops[4].name, 'Dona Paula Viewpoint');
    });

    test('pinned stop is treated as anchored and never moves', () {
      const startLat = 15.4000;
      const startLng = 73.8000;

      final stop1 = ItineraryStop(
        name: 'Stop 1',
        type: 'sightseeing',
        latitude: 15.45,
        longitude: 73.85,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );
      final pinnedStop = ItineraryStop(
        name: 'Hand Pinned Sunset Point',
        type: 'scenic',
        isPinned: true,
        latitude: 15.90, // very far away
        longitude: 73.90,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        durationMinutes: 60,
      );
      final stop2 = ItineraryStop(
        name: 'Stop 2',
        type: 'sightseeing',
        latitude: 15.41,
        longitude: 73.81,
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        durationMinutes: 60,
      );

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: [stop1, pinnedStop, stop2],
        startLat: startLat,
        startLng: startLng,
        startPointLabel: 'Start',
      );

      // The pinned stop must stay at index 1
      expect(result.orderedStops[1].name, 'Hand Pinned Sunset Point');
    });
  });

  group('Opening Hours Constraint', () {
    test('shifts closed stops after open stops if opening hours data exists', () {
      const startLat = 15.5000;
      const startLng = 73.8000;

      // Nearest stop is closed at 09:00 AM (opens at 11:00 AM)
      final closedEarlyNear = ItineraryStop(
        name: 'Late Opening Art Gallery',
        type: 'museum',
        latitude: 15.5050,
        longitude: 73.8050, // very close
        openingHours: '11:00 AM - 07:00 PM',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );

      // Slightly farther stop is open at 09:00 AM
      final openEarlyFar = ItineraryStop(
        name: 'Early Morning Public Garden',
        type: 'park',
        latitude: 15.5200,
        longitude: 73.8200, // slightly farther
        openingHours: '08:00 AM - 06:00 PM',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: [closedEarlyNear, openEarlyFar],
        startLat: startLat,
        startLng: startLng,
        startPointLabel: 'Start',
        dayStartTime: '09:00',
      );

      // The open stop must be placed first at 09:00 AM
      expect(result.orderedStops[0].name, 'Early Morning Public Garden');
      expect(result.orderedStops[1].name, 'Late Opening Art Gallery');
    });

    test('preserves proximity order if opening hours are unknown without guessing', () {
      const startLat = 15.5000;
      const startLng = 73.8000;

      final nearUnknown = ItineraryStop(
        name: 'Hidden Hill View',
        type: 'scenic',
        latitude: 15.5050,
        longitude: 73.8050,
        openingHours: null,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        durationMinutes: 60,
      );

      final farUnknown = ItineraryStop(
        name: 'Distant Beach',
        type: 'beach',
        latitude: 15.5500,
        longitude: 73.8500,
        openingHours: null,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        durationMinutes: 60,
      );

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: [farUnknown, nearUnknown],
        startLat: startLat,
        startLng: startLng,
        startPointLabel: 'Start',
      );

      // Kept nearest-first since hours are unknown
      expect(result.orderedStops[0].name, 'Hidden Hill View');
      expect(result.orderedStops[1].name, 'Distant Beach');
    });
  });

  group('Start Point Fallback Cascade', () {
    test('LocationService.resolveStartPoint cascades properly', () async {
      final locService = LocationService();

      // 1. User coordinates provided
      final custom = await locService.resolveStartPoint(
        city: 'Goa',
        userPickedLat: 15.2993,
        userPickedLng: 74.1240,
        userPickedLabel: 'Chosen Location',
      );
      expect(custom.source, RouteStartPointSource.userPicked);
      expect(custom.latitude, 15.2993);

      // 2. Hotel stay provided
      final hotel = await locService.resolveStartPoint(
        city: 'Goa',
        hotelLat: 15.5500,
        hotelLng: 73.7600,
        hotelLabel: 'Taj Cidade',
      );
      expect(hotel.source, RouteStartPointSource.hotel);
      expect(hotel.label, contains('Taj Cidade'));

      // 3. Fallback to city center
      final cityCenter = await locService.resolveStartPoint(
        city: 'Goa',
      );
      expect(cityCenter.source, RouteStartPointSource.cityCenter);
      expect(cityCenter.label, contains('Goa'));
      expect(cityCenter.latitude, closeTo(15.2993, 0.5));
    });
  });

  group('Data Model & Backward Compatibility', () {
    test('ItineraryStop serializes and deserializes new card fields cleanly', () {
      final stop = ItineraryStop(
        name: 'Fort Aguada',
        type: 'sightseeing',
        latitude: 15.4920,
        longitude: 73.7735,
        startTime: '10:00 AM',
        endTime: '11:30 AM',
        durationMinutes: 90,
        description: 'Historic 17th-century Portuguese lighthouse and fort overlooking the Arabian Sea.',
        shortLabel: 'Historic 17th-century Portuguese fort',
        briefDescription: 'A well-preserved seventeenth-century Portuguese lighthouse and fort overlooking the Arabian Sea.',
        openingHours: '09:30 AM - 06:00 PM',
        ticketPrice: '₹50 per person',
        bestTimeToVisit: 'Morning or Sunset',
        isAnchored: false,
        isPinned: true,
        galleryPhotos: ['https://example.com/img1.jpg', 'https://example.com/img2.jpg'],
        distanceFromPrevKm: 2.4,
        travelTimeFromPrev: '6 min drive',
      );

      final map = stop.toMap();
      final restored = ItineraryStop.fromMap(map);

      expect(restored.name, 'Fort Aguada');
      expect(restored.shortLabel, 'Historic 17th-century Portuguese fort');
      expect(restored.briefDescription, contains('seventeenth-century'));
      expect(restored.openingHours, '09:30 AM - 06:00 PM');
      expect(restored.ticketPrice, '₹50 per person');
      expect(restored.isPinned, isTrue);
      expect(restored.galleryPhotos.length, 2);
      expect(restored.distanceFromPrevKm, 2.4);
      expect(restored.travelTimeFromPrev, '6 min drive');
    });

    test('backward compatibility: legacy stop without new fields falls back gracefully', () {
      final legacyMap = {
        'name': 'Old Legacy Stop',
        'type': 'place',
        'startTime': '09:00 AM',
        'endTime': '10:00 AM',
        'durationMinutes': 60,
        'description': 'A long legacy description that was saved in the database before the redesign was introduced.',
        'tips': ['Old tip 1'],
      };

      final stop = ItineraryStop.fromMap(legacyMap);

      expect(stop.name, 'Old Legacy Stop');
      expect(stop.shortLabel, isNull);
      expect(stop.briefDescription, isNull);
      expect(stop.openingHours, isNull);
      expect(stop.ticketPrice, isNull);
      expect(stop.isAnchored, isFalse);
      expect(stop.isPinned, isFalse);
      expect(stop.galleryPhotos, isEmpty);

      // Getters ensure UI displays gracefully without breaking
      expect(stop.displayShortLabel.isNotEmpty, isTrue);
      expect(stop.displayBriefDescription, contains('A long legacy description'));
    });

    test('intercity start (e.g. Delhi to Rajkot 1374 km) does not eat day time budget or drop stops', () {
      // User is in Delhi (28.6139, 77.2090)
      const delhiLat = 28.6139;
      const delhiLng = 77.2090;

      // 4 sightseeing stops in Rajkot (22.28, 70.82)
      final stops = <ItineraryStop>[
        ItineraryStop(
          name: 'Pradhyuman Zoological Park',
          type: 'sightseeing',
          startTime: '09:00 AM',
          endTime: '10:30 AM',
          latitude: 22.2888,
          longitude: 70.8104,
          durationMinutes: 90,
        ),
        ItineraryStop(
          name: 'Watson Museum',
          type: 'heritage',
          startTime: '10:45 AM',
          endTime: '11:45 AM',
          latitude: 22.3020,
          longitude: 70.8030,
          durationMinutes: 60,
        ),
        ItineraryStop(
          name: 'Rotary Dolls Museum',
          type: 'activity',
          startTime: '12:00 PM',
          endTime: '01:00 PM',
          latitude: 22.2980,
          longitude: 70.7980,
          durationMinutes: 60,
        ),
        ItineraryStop(
          name: 'Aji Dam Garden',
          type: 'sightseeing',
          startTime: '02:30 PM',
          endTime: '04:00 PM',
          latitude: 22.2500,
          longitude: 70.8300,
          durationMinutes: 90,
        ),
      ];

      final result = RouteProximityOptimizer.optimizeStopsProximity(
        stops: stops,
        startLat: delhiLat,
        startLng: delhiLng,
        startPointLabel: 'your current location',
        dayStartTime: '09:00',
        dayEndTime: '21:00',
      );

      // Verify that all 4 stops are retained (none dropped as overflow)
      expect(result.orderedStops.length, 4);
      expect(result.overflowStops, isEmpty);

      // First stop starts at 09:00 AM, not afternoon
      expect(result.orderedStops.first.startTime, '09:00 AM');
      expect(result.orderedStops.first.distanceFromPrevKm, isNull);

      // Subsequent stops proceed chronologically
      expect(result.orderedStops[1].startTime, isNot('09:00 AM'));
      expect(result.startPointMessage, contains('destination'));
    });
  });
}
