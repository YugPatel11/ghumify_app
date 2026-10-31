import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/constants/food_preferences.dart';
import 'package:ghumify_app/core/constants/meal_config.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/core/models/meal_suggestion_model.dart';
import 'package:ghumify_app/core/models/travelers_model.dart';
import 'package:ghumify_app/core/services/restaurant_service.dart';
import 'package:ghumify_app/core/services/gemini_service.dart';

void main() {
  group('MealConfig Tests', () {
    test('Meal window times and durations are correctly configured', () {
      expect(MealConfig.lunchStartTime, '12:30');
      expect(MealConfig.lunchEndTime, '14:30');
      expect(MealConfig.lunchDefaultDurationMinutes, 75);

      expect(MealConfig.dinnerStartTime, '19:00');
      expect(MealConfig.dinnerEndTime, '21:00');
      expect(MealConfig.dinnerEarlyDefaultTime, '19:00');
      expect(MealConfig.dinnerDefaultDurationMinutes, 90);

      expect(MealConfig.radiusTiersMeters, [1000, 2000, 3000, 5000]);
    });

    test('timeToMinutes and minutesToTime conversions are accurate', () {
      expect(MealConfig.timeToMinutes('00:00'), 0);
      expect(MealConfig.timeToMinutes('12:30'), 750);
      expect(MealConfig.timeToMinutes('13:00'), 780);
      expect(MealConfig.timeToMinutes('19:30'), 1170);

      expect(MealConfig.minutesToTime(750), '12:30');
      expect(MealConfig.minutesToTime(1170), '19:30');
    });

    test('isWithinLunchWindow and isWithinDinnerWindow accurately detect meal times', () {
      expect(MealConfig.isWithinLunchWindow('12:30'), isTrue);
      expect(MealConfig.isWithinLunchWindow('13:15'), isTrue);
      expect(MealConfig.isWithinLunchWindow('14:30'), isTrue);
      expect(MealConfig.isWithinLunchWindow('11:45'), isFalse);
      expect(MealConfig.isWithinLunchWindow('15:00'), isFalse);

      expect(MealConfig.isWithinDinnerWindow('19:00'), isTrue);
      expect(MealConfig.isWithinDinnerWindow('20:00'), isTrue);
      expect(MealConfig.isWithinDinnerWindow('21:00'), isTrue);
      expect(MealConfig.isWithinDinnerWindow('18:00'), isFalse);
      expect(MealConfig.isWithinDinnerWindow('22:00'), isFalse);
    });
  });

  group('Restaurant Anchor Point Determination', () {
    final sampleStops = [
      ItineraryStop(
        name: 'Amer Fort',
        type: 'place',
        startTime: '09:30',
        endTime: '11:45',
        durationMinutes: 135,
        latitude: 26.9855,
        longitude: 75.8513,
      ),
      ItineraryStop(
        name: 'Hawa Mahal',
        type: 'place',
        startTime: '12:15',
        endTime: '13:45',
        durationMinutes: 90,
        latitude: 26.9239,
        longitude: 75.8267,
      ),
      ItineraryStop(
        name: 'City Palace',
        type: 'place',
        startTime: '15:00',
        endTime: '17:00',
        durationMinutes: 120,
        latitude: 26.9258,
        longitude: 75.8236,
      ),
      ItineraryStop(
        name: 'Bapu Bazaar Shopping',
        type: 'market',
        startTime: '18:00',
        endTime: '19:30',
        durationMinutes: 90,
        latitude: 26.9196,
        longitude: 75.8242,
      ),
    ];

    test('Finds stop closest to lunch window (Hawa Mahal)', () {
      final anchor = RestaurantService.findMealAnchorPoint(
        stops: sampleStops,
        mealType: MealConfig.lunch,
      );

      expect(anchor, isNotNull);
      expect(anchor!.name, 'Hawa Mahal');
      expect(anchor.latitude, 26.9239);
      expect(anchor.longitude, 75.8267);
    });

    test('Finds stop closest to dinner window (Bapu Bazaar)', () {
      final anchor = RestaurantService.findMealAnchorPoint(
        stops: sampleStops,
        mealType: MealConfig.dinner,
      );

      expect(anchor, isNotNull);
      expect(anchor!.name, 'Bapu Bazaar Shopping');
      expect(anchor.latitude, 26.9196);
      expect(anchor.longitude, 75.8242);
    });

    test('Attaches to existing food stop if already present in itinerary', () {
      final stopsWithLunch = [
        ...sampleStops,
        ItineraryStop(
          name: 'LMB Hotel Sweet Home',
          type: 'food',
          startTime: '13:00',
          endTime: '14:15',
          durationMinutes: 75,
          latitude: 26.9211,
          longitude: 75.8255,
        ),
      ];

      final anchor = RestaurantService.findMealAnchorPoint(
        stops: stopsWithLunch,
        mealType: MealConfig.lunch,
      );

      expect(anchor, isNotNull);
      expect(anchor!.name, 'LMB Hotel Sweet Home');
      expect(anchor.existingMealStop, isNotNull);
    });

    test('Gracefully uses fallback coordinates when stops list is empty', () {
      final anchor = RestaurantService.findMealAnchorPoint(
        stops: [],
        mealType: MealConfig.lunch,
        fallbackLat: 26.9124,
        fallbackLon: 75.7873,
        fallbackName: 'Jaipur',
      );

      expect(anchor, isNotNull);
      expect(anchor!.name, 'Jaipur');
      expect(anchor.latitude, 26.9124);
      expect(anchor.longitude, 75.7873);
    });
  });

  group('Overpass Query and Parsing Tests', () {
    test('Overpass query generator includes proper timeout, tags, and radius', () {
      final query = RestaurantService.buildOverpassRestaurantQuery(
        latitude: 26.9124,
        longitude: 75.7873,
        radiusMeters: 1000,
      );

      expect(query, contains('[out:json][timeout:15];'));
      expect(query, contains('node["amenity"="restaurant"](around:1000,26.9124,75.7873)'));
      expect(query, contains('node["amenity"="cafe"]'));
      expect(query, contains('node["amenity"="fast_food"]'));
      expect(query, contains('way["amenity"="restaurant"]'));
      expect(query, contains('out center body;'));
    });
  });

  group('Strict Dietary Filtering and Scoring', () {
    test('Pure Veg filter accepts pure veg and rejects meat dishes', () {
      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Sharma Pure Veg Dhaba'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Royal Chicken Biryani & Kebabs'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Fisherman Seafood Cafe'), isFalse);
    });

    test('Jain filter strictly rejects onion, garlic, potatoes, and non-veg', () {
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Jain Thali Restaurant'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Garlic Naan & Aloo Paratha Corner'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Onion Rings & Fries House'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Tandoori Chicken'), isFalse);
    });

    test('Veg + Egg filter rejects meat and fish but allows eggs', () {
      expect(DietaryFilterService.isCompliant(FoodPreference.vegEgg, 'Egg Bhurji & Omlet Point'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.vegEgg, 'Green Salad & Paneer Cafe'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.vegEgg, 'Mutton Rogan Josh Special'), isFalse);
    });
  });

  group('Travelers and Family Safety Rules', () {
    test('Nightlife amenities are identified for filtering when minors present', () {
      for (final badAmenity in MealConfig.nightlifeAmenities) {
        expect(['bar', 'pub', 'nightclub', 'biergarten', 'hookah_lounge'], contains(badAmenity));
      }
    });

    test('TravelersModel summary reflects minors presence', () {
      final family = const TravelersModel(adults: 2, minors: 1);
      expect(family.minors, 1);
      expect(family.summary, contains('2 Adults'));
      expect(family.summary, contains('Child'));

      final solo = const TravelersModel(adults: 1, minors: 0);
      expect(solo.minors, 0);
      expect(solo.summary, contains('1 Adult'));
    });
  });

  group('MealSuggestionModel Serialization & URLs', () {
    test('Model serializes and deserializes accurately without losing data', () {
      final model = MealSuggestionModel(
        id: 'osm_node_12345',
        name: 'Govindam Retreat',
        mealType: MealConfig.lunch,
        dietaryType: FoodPreference.veg,
        dietaryBadge: 'Pure Veg',
        cuisine: 'Rajasthani, North Indian',
        latitude: 26.9240,
        longitude: 75.8250,
        distanceMeters: 450,
        walkingMinutes: 6,
        rating: 4.6,
        reviewCount: 320,
        priceLevel: '₹₹',
        openingHours: '11:00-23:00',
        openingStatus: 'Open for lunch',
        phone: '+91 141 260 0000',
        address: 'Chaugan Stadium Road, Jaipur',
        suggestedReason: 'Pure Veg • 450 m near City Palace',
        isKidFriendly: true,
      );

      final map = model.toMap();
      expect(map['id'], 'osm_node_12345');
      expect(map['name'], 'Govindam Retreat');
      expect(map['dietaryBadge'], 'Pure Veg');
      expect(map['distanceMeters'], 450);
      expect(map['isKidFriendly'], isTrue);

      final restored = MealSuggestionModel.fromMap(map);
      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.rating, 4.6);
      expect(restored.phone, '+91 141 260 0000');
      expect(restored.isKidFriendly, isTrue);
    });

    test('Google Maps and Directions URLs conform to official keyless format', () {
      final model = MealSuggestionModel(
        id: '1',
        name: 'Test Spot',
        mealType: MealConfig.lunch,
        dietaryType: 'all',
        dietaryBadge: 'Dining',
        latitude: 26.924,
        longitude: 75.825,
        distanceMeters: 300,
        suggestedReason: 'Close by',
      );

      expect(
        model.googleMapsUrl,
        'https://www.google.com/maps/search/?api=1&query=26.924,75.825',
      );
      expect(
        model.directionsUrl,
        'https://www.google.com/maps/dir/?api=1&destination=26.924,75.825',
      );
    });

    test('Display distance formats meters and kilometers properly', () {
      final close = MealSuggestionModel(
        id: '1',
        name: 'A',
        mealType: 'lunch',
        dietaryType: 'all',
        dietaryBadge: 'D',
        latitude: 0,
        longitude: 0,
        distanceMeters: 650,
        suggestedReason: '',
      );
      expect(close.displayDistance, '650 m');

      final far = MealSuggestionModel(
        id: '2',
        name: 'B',
        mealType: 'lunch',
        dietaryType: 'all',
        dietaryBadge: 'D',
        latitude: 0,
        longitude: 0,
        distanceMeters: 2400,
        suggestedReason: '',
      );
      expect(far.displayDistance, '2.4 km');
    });
  });

  group('Backward Compatibility with Legacy Saved Itineraries', () {
    test('ItineraryModel handles missing mealSuggestions without crashing', () {
      final legacyData = {
        'id': 'legacy_itinerary_101',
        'userId': 'user_abc',
        'city': 'Jaipur',
        'date': '2026-08-20',
        'startTime': '09:00',
        'endTime': '18:00',
        'totalDurationMinutes': 540,
        'stops': [
          {
            'name': 'Hawa Mahal',
            'type': 'place',
            'startTime': '10:00',
            'endTime': '11:30',
            'durationMinutes': 90,
          }
        ],
        // Note: mealSuggestions is completely absent
      };

      final itinerary = ItineraryModel.fromMap(legacyData);
      expect(itinerary.id, 'legacy_itinerary_101');
      expect(itinerary.mealSuggestions, isNull);
      expect(itinerary.hasMealSuggestions, isFalse);
    });

    test('ItineraryModel deserializes mealSuggestions when present', () {
      final dataWithMeals = {
        'id': 'modern_itinerary_202',
        'userId': 'user_abc',
        'city': 'Jaipur',
        'date': '2026-08-20',
        'startTime': '09:00',
        'endTime': '18:00',
        'totalDurationMinutes': 540,
        'stops': [],
        'mealSuggestions': {
          'lunchAnchorName': 'City Palace',
          'dinnerAnchorName': 'Chokhi Dhani',
          'lunchSuggestions': [
            {
              'id': 's1',
              'name': 'Baradari Restaurant',
              'mealType': 'lunch',
              'dietaryType': 'all',
              'dietaryBadge': 'Fine Dining',
              'latitude': 26.925,
              'longitude': 75.823,
              'distanceMeters': 200,
              'suggestedReason': 'Near City Palace',
            }
          ],
          'dinnerSuggestions': [],
          'lastUpdated': '2026-08-20T12:00:00.000',
        },
      };

      final itinerary = ItineraryModel.fromMap(dataWithMeals);
      expect(itinerary.hasMealSuggestions, isTrue);
      expect(itinerary.mealSuggestions!.lunchAnchorName, 'City Palace');
      expect(itinerary.mealSuggestions!.lunchSuggestions.length, 1);
      expect(itinerary.mealSuggestions!.lunchSuggestions.first.name, 'Baradari Restaurant');
    });
  });

  group('Restaurant Exclusion and Multi-Mirror Overpass Reliability', () {
    test('GeminiService.isRestaurantStop correctly identifies food places and allows sightseeing', () {
      final restaurantStop1 = ItineraryStop(
        name: 'The Grand Thakar',
        type: 'food',
        startTime: '13:00',
        endTime: '14:15',
        durationMinutes: 75,
      );
      final restaurantStop2 = ItineraryStop(
        name: 'Gopi Dining Hall',
        type: 'place',
        startTime: '13:00',
        endTime: '14:00',
        durationMinutes: 60,
      );
      final sightStop1 = ItineraryStop(
        name: 'Amer Fort',
        type: 'place',
        startTime: '09:00',
        endTime: '11:00',
        durationMinutes: 120,
      );
      final sightStop2 = ItineraryStop(
        name: 'Kaba Gandhi No Delo',
        type: 'heritage',
        startTime: '11:30',
        endTime: '12:30',
        durationMinutes: 60,
      );

      expect(GeminiService.isRestaurantStop(restaurantStop1), isTrue);
      expect(GeminiService.isRestaurantStop(restaurantStop2), isTrue);
      expect(GeminiService.isRestaurantStop(sightStop1), isFalse);
      expect(GeminiService.isRestaurantStop(sightStop2), isFalse);
    });

    test('Overpass mirrors list has at least 3 distinct fault-tolerant endpoints', () {
      expect(RestaurantService.overpassMirrors.length, greaterThanOrEqualTo(3));
      expect(RestaurantService.overpassMirrors, contains('https://overpass.kumi.systems/api/interpreter'));
      expect(RestaurantService.overpassMirrors, contains('https://overpass.private.coffee/api/interpreter'));
      expect(RestaurantService.overpassMirrors, contains('https://overpass-api.de/api/interpreter'));
    });

    test('Focused restaurant query contains only amenity=restaurant', () {
      final focusedQuery = RestaurantService.buildOverpassRestaurantQuery(
        latitude: 22.3039,
        longitude: 70.8022,
        radiusMeters: 1000,
        focused: true,
      );
      expect(focusedQuery, contains('node["amenity"="restaurant"]'));
      expect(focusedQuery, isNot(contains('node["amenity"="cafe"]')));
      expect(focusedQuery, isNot(contains('node["amenity"="fast_food"]')));

      final broadQuery = RestaurantService.buildOverpassRestaurantQuery(
        latitude: 22.3039,
        longitude: 70.8022,
        radiusMeters: 1000,
        focused: false,
      );
      expect(broadQuery, contains('node["amenity"="restaurant"]'));
      expect(broadQuery, contains('node["amenity"="cafe"]'));
      expect(broadQuery, contains('node["amenity"="fast_food"]'));
    });
  });
}
