import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/city_stay_model.dart';
import 'package:ghumify_app/core/models/multi_city_trip_model.dart';
import 'package:ghumify_app/core/models/transport_option_model.dart';
import 'package:ghumify_app/core/models/travel_leg_model.dart';
import 'package:ghumify_app/core/models/travelers_model.dart';
import 'package:ghumify_app/core/services/transport_service.dart';

void main() {
  group('Multi-City Models & Limits', () {
    test('CityStayModel stores coordinates, stayDays and dates correctly', () {
      final city = CityStayModel(
        id: 'city_1',
        name: 'Jaipur',
        stateOrRegion: 'Rajasthan',
        country: 'India',
        latitude: 26.9124,
        longitude: 75.7873,
        stayDays: 3,
        arrivalDate: DateTime(2026, 11, 1),
        departureDate: DateTime(2026, 11, 4),
      );

      expect(city.name, 'Jaipur');
      expect(city.stayDays, 3);
      expect(city.stateOrRegion, 'Rajasthan');

      final map = city.toMap();
      final recreated = CityStayModel.fromMap(map);
      expect(recreated.name, city.name);
      expect(recreated.latitude, city.latitude);
      expect(recreated.stayDays, 3);
    });

    test('MultiCityTripModel calculates total distance and route summary accurately', () {
      final cityA = CityStayModel(
        id: 'c1',
        name: 'Delhi',
        latitude: 28.6139,
        longitude: 77.2090,
        stayDays: 2,
        arrivalDate: DateTime(2026, 11, 1),
        departureDate: DateTime(2026, 11, 3),
      );
      final cityB = CityStayModel(
        id: 'c2',
        name: 'Agra',
        latitude: 27.1767,
        longitude: 78.0081,
        stayDays: 1,
        arrivalDate: DateTime(2026, 11, 3),
        departureDate: DateTime(2026, 11, 4),
      );
      final cityC = CityStayModel(
        id: 'c3',
        name: 'Jaipur',
        latitude: 26.9124,
        longitude: 75.7873,
        stayDays: 2,
        arrivalDate: DateTime(2026, 11, 4),
        departureDate: DateTime(2026, 11, 6),
      );

      final now = DateTime.now();

      final leg1 = TravelLegModel(
        id: 'leg_del_agr',
        fromCity: 'Delhi',
        toCity: 'Agra',
        fromLat: 28.6139,
        fromLng: 77.2090,
        toLat: 27.1767,
        toLng: 78.0081,
        distanceKm: 210.0,
        availableOptions: [
          TransportOptionModel(
            id: 'opt1',
            mode: 'train',
            modeName: 'Train',
            durationMinutes: 135,
            estimatedCostPerPerson: 350,
            estimatedTotalCost: 350,
            distanceKm: 210.0,
            lastUpdated: now,
            bookingUrl: 'https://www.irctc.co.in',
          ),
        ],
        selectedOption: TransportOptionModel(
          id: 'opt1',
          mode: 'train',
          modeName: 'Train',
          durationMinutes: 135,
          estimatedCostPerPerson: 350,
          estimatedTotalCost: 350,
          distanceKm: 210.0,
          lastUpdated: now,
          bookingUrl: 'https://www.irctc.co.in',
        ),
      );

      final leg2 = TravelLegModel(
        id: 'leg_agr_jai',
        fromCity: 'Agra',
        toCity: 'Jaipur',
        fromLat: 27.1767,
        fromLng: 78.0081,
        toLat: 26.9124,
        toLng: 75.7873,
        distanceKm: 240.0,
        availableOptions: [
          TransportOptionModel(
            id: 'opt2',
            mode: 'car',
            modeName: 'Car / Taxi',
            durationMinutes: 270,
            estimatedCostPerPerson: 1600,
            estimatedTotalCost: 1600,
            distanceKm: 240.0,
            lastUpdated: now,
            bookingUrl: 'https://m.uber.com/looking',
          ),
        ],
        selectedOption: TransportOptionModel(
          id: 'opt2',
          mode: 'car',
          modeName: 'Car / Taxi',
          durationMinutes: 270,
          estimatedCostPerPerson: 1600,
          estimatedTotalCost: 1600,
          distanceKm: 240.0,
          lastUpdated: now,
          bookingUrl: 'https://m.uber.com/looking',
        ),
      );

      final trip = MultiCityTripModel(
        id: 'golden_triangle',
        userId: 'traveler_1',
        title: 'Golden Triangle Circuit',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 6),
        totalDays: 5,
        cities: [cityA, cityB, cityC],
        legs: [leg1, leg2],
        isRoundTrip: false,
      );

      expect(trip.totalDistanceKm, 450.0);
      expect(trip.routeSummary, 'Delhi → Agra → Jaipur');
      expect(trip.estimatedTravelCost, 1950);

      // Verify Firestore serialization
      final map = trip.toMap();
      expect(map['tripType'], 'multi_city');
      expect(map['totalDays'], 5);

      final deserialized = MultiCityTripModel.fromMap(map);
      expect(deserialized.id, trip.id);
      expect(deserialized.cities.length, 3);
      expect(deserialized.legs.length, 2);
      expect(deserialized.totalDistanceKm, 450.0);
    });
  });

  group('TransportService & Fare Estimator', () {
    final service = TransportService();

    test('Generates transit options for short distances (Delhi to Agra ~200km)', () async {
      const travelers = TravelersModel(adults: 2, minors: 1); // 2 adults, 1 child
      final options = await service.getTransportOptions(
        fromCity: 'Delhi',
        fromLat: 28.6139,
        fromLng: 77.2090,
        toCity: 'Agra',
        toLat: 27.1767,
        toLng: 78.0081,
        travelers: travelers,
      );

      expect(options.isNotEmpty, isTrue);

      // Verify modes: Train, Bus, Car must be present
      final modes = options.map((o) => o.mode).toSet();
      expect(modes.contains('train'), isTrue);
      expect(modes.contains('bus'), isTrue);
      expect(modes.contains('car'), isTrue);

      // Flight should NOT be offered for 200km distance (under 320km threshold)
      expect(modes.contains('flight'), isFalse);

      // Verify honesty rules: every option is tagged as estimate
      for (final opt in options) {
        expect(opt.isEstimate, isTrue);
        expect(opt.dataSource, contains('Fare Engine'));
        expect(opt.bookingUrl?.startsWith('https://'), isTrue);
      }

      // Verify adult/minor fare concession for train
      final trainOpt = options.firstWhere((o) => o.mode == 'train');
      // For train, 1 minor without specified band gets 50% concession: 2 adults + 0.5 child = 2.5 fares
      expect(trainOpt.estimatedTotalCost, (trainOpt.estimatedCostPerPerson * 2.5).round());
    });

    test('Flight option is generated for long distance between airport cities (Delhi to Mumbai)', () async {
      const travelers = TravelersModel(adults: 1, minors: 0);
      final options = await service.getTransportOptions(
        fromCity: 'Delhi',
        fromLat: 28.6139,
        fromLng: 77.2090,
        toCity: 'Mumbai',
        toLat: 19.0760,
        toLng: 72.8777,
        travelers: travelers,
      );

      final modes = options.map((o) => o.mode).toSet();
      expect(modes.contains('flight'), isTrue);

      final flightOpt = options.firstWhere((o) => o.mode == 'flight');
      expect(flightOpt.bookingUrl, contains('makemytrip.com'));
      expect(flightOpt.notes, contains('boarding buffer'));
    });

    test('Route optimizer finds sensible shortest path', () {
      final cJaipur = CityStayModel(
        id: 'c1',
        name: 'Jaipur',
        latitude: 26.9124,
        longitude: 75.7873,
        stayDays: 2,
      );
      final cUdaipur = CityStayModel(
        id: 'c2',
        name: 'Udaipur',
        latitude: 24.5854,
        longitude: 73.7125,
        stayDays: 2,
      );
      final cJodhpur = CityStayModel(
        id: 'c3',
        name: 'Jodhpur',
        latitude: 26.2389,
        longitude: 73.0243,
        stayDays: 2,
      );

      final optimized = service.optimizeRoute([cJaipur, cUdaipur, cJodhpur]);

      expect(optimized.length, 3);
      expect(optimized.first.name, 'Jaipur');
    });

    test('Nearby city suggestions return valid coordinates and realistic distances', () async {
      final suggestions = await service.getNearbyCitySuggestions(
        baseCity: 'Jaipur',
        baseLat: 26.9124,
        baseLng: 75.7873,
        excludeCityNames: ['Jaipur'],
      );

      expect(suggestions.isNotEmpty, isTrue);
      for (final s in suggestions) {
        expect(s.name.isNotEmpty, isTrue);
        expect(s.distanceKm, greaterThan(0));
        expect(s.distanceKm, lessThanOrEqualTo(450));
        expect(s.estimatedHours.isNotEmpty, isTrue);
      }
    });
  });
}
