import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ghumify_app/core/constants/safety_constants.dart';
import 'package:ghumify_app/core/models/nearby_service_model.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/core/models/multi_day_itinerary_model.dart';
import 'package:ghumify_app/core/services/places_service.dart';

void main() {
  group('SafetyConstants Tests', () {
    test('Contains correct OpenStreetMap attribution and emergency numbers', () {
      expect(SafetyConstants.osmAttribution, contains('OpenStreetMap contributors'));
      expect(SafetyConstants.osmCopyrightUrl, 'https://www.openstreetmap.org/copyright');
      expect(SafetyConstants.nationalEmergencyNumber, '112');
      expect(SafetyConstants.policeEmergencyNumber, '100');
      expect(SafetyConstants.ambulanceEmergencyNumber, '108');
      expect(SafetyConstants.cacheTtl.inHours, 24);
      expect(SafetyConstants.initialRadiusMeters, 3000);
      expect(SafetyConstants.expandedRadiusMeters, 5000);
      expect(SafetyConstants.maxRadiusMeters, 10000);
      expect(SafetyConstants.maxResultsPerCategory, 5);
    });
  });

  group('NearbyServiceModel Tests', () {
    test('Parses node element with full tags correctly', () {
      final node = {
        'type': 'node',
        'id': 123456,
        'lat': 26.9124,
        'lon': 75.7873,
        'tags': {
          'name': 'SMS Hospital',
          'amenity': 'hospital',
          'addr:full': 'JLN Marg, Jaipur, Rajasthan',
          'phone': '+91 141 2518224',
          'opening_hours': '24/7',
          'emergency': 'yes',
        },
      };

      final service = NearbyServiceModel.fromOverpassElement(node, distanceKm: 1.5);

      expect(service.name, 'SMS Hospital');
      expect(service.type, 'hospital');
      expect(service.subtype, 'hospital');
      expect(service.latitude, 26.9124);
      expect(service.longitude, 75.7873);
      expect(service.address, 'JLN Marg, Jaipur, Rajasthan');
      expect(service.phone, '+91 141 2518224');
      expect(service.openingHours, '24/7');
      expect(service.isEmergency, isTrue);
      expect(service.distanceKm, 1.5);
    });

    test('Parses way element with center coordinates', () {
      final way = {
        'type': 'way',
        'id': 789101,
        'center': {'lat': 26.9200, 'lon': 75.8000},
        'tags': {
          'name': 'Kotwali Police Station',
          'amenity': 'police',
          'addr:street': 'MI Road',
          'addr:city': 'Jaipur',
        },
      };

      final service = NearbyServiceModel.fromOverpassElement(way, distanceKm: 2.1);

      expect(service.name, 'Kotwali Police Station');
      expect(service.type, 'police');
      expect(service.subtype, 'police');
      expect(service.latitude, 26.9200);
      expect(service.longitude, 75.8000);
      expect(service.address, 'MI Road, Jaipur');
      expect(service.isEmergency, isFalse);
    });

    test('Parses relation element with center coordinates', () {
      final relation = {
        'type': 'relation',
        'id': 999999,
        'center': {'lat': 26.9050, 'lon': 75.7900},
        'tags': {
          'name': 'Fortis Escorts Hospital',
          'amenity': 'hospital',
        },
      };

      final service = NearbyServiceModel.fromOverpassElement(relation);

      expect(service.name, 'Fortis Escorts Hospital');
      expect(service.type, 'hospital');
      expect(service.latitude, 26.9050);
      expect(service.longitude, 75.7900);
    });

    test('Correctly handles clinic tag with clinic subtype', () {
      final clinic = {
        'type': 'node',
        'id': 55555,
        'lat': 26.9150,
        'lon': 75.7950,
        'tags': {
          'name': 'City Health Clinic',
          'amenity': 'clinic',
        },
      };

      final service = NearbyServiceModel.fromOverpassElement(clinic);

      expect(service.name, 'City Health Clinic');
      expect(service.type, 'hospital');
      expect(service.subtype, 'clinic');
    });

    test('Provides graceful fallbacks when name tag is missing', () {
      final unnamedHospital = {
        'type': 'node',
        'id': 111,
        'lat': 26.91,
        'lon': 75.78,
        'tags': {'amenity': 'hospital'},
      };
      final unnamedClinic = {
        'type': 'node',
        'id': 222,
        'lat': 26.92,
        'lon': 75.79,
        'tags': {'amenity': 'clinic'},
      };
      final unnamedPolice = {
        'type': 'node',
        'id': 333,
        'lat': 26.93,
        'lon': 75.80,
        'tags': {'amenity': 'police'},
      };

      expect(NearbyServiceModel.fromOverpassElement(unnamedHospital).name,
          'Hospital (name not available)');
      expect(NearbyServiceModel.fromOverpassElement(unnamedClinic).name,
          'Clinic (name not available)');
      expect(NearbyServiceModel.fromOverpassElement(unnamedPolice).name,
          'Police Station (name not available)');
    });

    test('Generates official Google Maps and Phone URLs correctly', () {
      final service = NearbyServiceModel(
        name: 'SMS Hospital',
        type: 'hospital',
        latitude: 26.9124,
        longitude: 75.7873,
        phone: '+91 (141) 251-8224',
      );

      expect(service.googleMapsSearchUrl.toString(),
          'https://www.google.com/maps/search/?api=1&query=26.9124,75.7873');
      expect(service.googleMapsDirectionsUrl.toString(),
          'https://www.google.com/maps/dir/?api=1&destination=26.9124,75.7873');
      expect(service.phoneDialerUri.toString(), 'tel:+911412518224');
    });

    test('Serialization toMap and fromMap works cleanly', () {
      final original = NearbyServiceModel(
        name: 'Apollo Hospital',
        type: 'hospital',
        subtype: 'hospital',
        latitude: 26.9000,
        longitude: 75.8000,
        address: 'Bapu Nagar, Jaipur',
        distanceKm: 3.2,
        phone: '1234567890',
        openingHours: '24/7',
        isEmergency: true,
        fetchedAt: DateTime(2026, 10, 30, 12, 0),
      );

      final map = original.toMap();
      expect(map['name'], 'Apollo Hospital');
      expect(map['isEmergency'], isTrue);
      expect(map['fetchedAt'], isA<Timestamp>());

      final deserialized = NearbyServiceModel.fromMap(map);
      expect(deserialized.name, original.name);
      expect(deserialized.type, original.type);
      expect(deserialized.subtype, original.subtype);
      expect(deserialized.latitude, original.latitude);
      expect(deserialized.longitude, original.longitude);
      expect(deserialized.distanceKm, original.distanceKm);
      expect(deserialized.phone, original.phone);
      expect(deserialized.isEmergency, isTrue);
    });
  });

  group('PlacesService Overpass QL & Element Parser Tests', () {
    test('buildOverpassSafetyQuery includes node, way, relation and center output', () {
      final query = PlacesService.buildOverpassSafetyQuery(
        latitude: 26.9124,
        longitude: 75.7873,
        radiusMeters: 3000,
      );

      expect(query, contains('node["amenity"="hospital"](around:3000,26.9124,75.7873);'));
      expect(query, contains('node["amenity"="police"](around:3000,26.9124,75.7873);'));
      expect(query, contains('way["amenity"="hospital"](around:3000,26.9124,75.7873);'));
      expect(query, contains('way["amenity"="police"](around:3000,26.9124,75.7873);'));
      expect(query, contains('relation["amenity"="hospital"](around:3000,26.9124,75.7873);'));
      expect(query, contains('relation["amenity"="police"](around:3000,26.9124,75.7873);'));
      expect(query, contains('out center body;'));
    });

    test('parseOverpassElements parses, dedupes, and sorts distances', () {
      final elements = [
        {
          'type': 'node',
          'id': 1,
          'lat': 26.9150,
          'lon': 75.7890,
          'tags': {'name': 'Hospital A', 'amenity': 'hospital'},
        },
        {
          'type': 'way',
          'id': 2,
          'center': {'lat': 26.9150, 'lon': 75.7890},
          'tags': {'name': 'Hospital A', 'amenity': 'hospital'}, // duplicate
        },
        {
          'type': 'node',
          'id': 3,
          'lat': 0.0,
          'lon': 0.0,
          'tags': {'name': 'Invalid Coords', 'amenity': 'hospital'}, // invalid coords
        },
        {
          'type': 'node',
          'id': 4,
          'lat': 26.9200,
          'lon': 75.8000,
          'tags': {'name': 'Police Station 1', 'amenity': 'police'},
        },
      ];

      final parsed = PlacesService.parseOverpassElements(
        elements,
        originLat: 26.9124,
        originLon: 75.7873,
      );

      expect(parsed.length, 2); // 1 hospital (deduped), 1 police
      expect(parsed.any((s) => s.name == 'Hospital A'), isTrue);
      expect(parsed.any((s) => s.name == 'Police Station 1'), isTrue);
      expect(parsed.every((s) => s.distanceKm != null), isTrue);
    });
  });

  group('Data Models & Saved Itineraries Safety Persistence Tests', () {
    test('ItineraryModel defaults nearbySafetyServices to empty list on legacy data', () {
      final legacy = ItineraryModel(
        id: 'itin_legacy',
        userId: 'user_1',
        city: 'Jaipur',
        date: '2026-10-30',
        startTime: '09:00',
        endTime: '18:00',
        totalDurationMinutes: 540,
      );

      expect(legacy.nearbySafetyServices, isEmpty);
    });

    test('ItineraryModel preserves nearbySafetyServices across toMap and copyWith', () {
      final safetyService = NearbyServiceModel(
        name: 'City Police Station',
        type: 'police',
        latitude: 26.9100,
        longitude: 75.7800,
        distanceKm: 0.8,
      );

      final itinerary = ItineraryModel(
        id: 'itin_1',
        userId: 'user_1',
        city: 'Jaipur',
        date: '2026-10-30',
        startTime: '09:00',
        endTime: '18:00',
        totalDurationMinutes: 540,
        nearbySafetyServices: [safetyService],
      );

      expect(itinerary.nearbySafetyServices.length, 1);
      expect(itinerary.nearbySafetyServices.first.name, 'City Police Station');

      final copied = itinerary.copyWith(
        isSaved: true,
      );
      expect(copied.isSaved, isTrue);
      expect(copied.nearbySafetyServices.length, 1);
      expect(copied.nearbySafetyServices.first.name, 'City Police Station');

      final map = itinerary.toMap();
      expect(map['nearbySafetyServices'], isA<List>());
      expect((map['nearbySafetyServices'] as List).length, 1);
    });

    test('MultiDayItineraryModel preserves nearbySafetyServices', () {
      final safetyService = NearbyServiceModel(
        name: 'SMS Hospital',
        type: 'hospital',
        latitude: 26.9124,
        longitude: 75.7873,
      );

      final multiDay = MultiDayItineraryModel(
        id: 'multi_1',
        userId: 'user_1',
        city: 'Jaipur',
        startDate: '2026-10-30',
        endDate: '2026-11-01',
        numberOfDays: 3,
        dailyStartTime: '09:00',
        dailyEndTime: '18:00',
        nearbySafetyServices: [safetyService],
      );

      expect(multiDay.nearbySafetyServices.length, 1);
      expect(multiDay.nearbySafetyServices.first.name, 'SMS Hospital');

      final copied = multiDay.copyWith(isSaved: true);
      expect(copied.isSaved, isTrue);
      expect(copied.nearbySafetyServices.length, 1);
    });
  });
}
