import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/place_suggestion_model.dart';
import 'package:ghumify_app/core/services/places_service.dart';

void main() {
  group('PlacesService Smart Autocomplete Tests', () {
    late PlacesService placesService;

    setUp(() {
      placesService = PlacesService();
    });

    test('Full destination name search returns accurate place suggestion', () async {
      final results = await placesService.searchPlaceSuggestions('Jaipur');
      expect(results, isNotEmpty);
      expect(results.first.name, equals('Jaipur'));
      expect(results.first.type, equals('city'));
      expect(results.first.latitude, isNotNull);
      expect(results.first.longitude, isNotNull);
    });

    test('Partial tourist landmark query returns relevant suggestions', () async {
      final results = await placesService.searchPlaceSuggestions('Hawa');
      expect(results, isNotEmpty);
      final hawaMahal = results.firstWhere((p) => p.name.contains('Hawa Mahal'));
      expect(hawaMahal.type, equals('monument'));
      expect(hawaMahal.secondaryText, contains('Jaipur'));
    });

    test('Hindi / local-language input correctly resolves destination', () async {
      final resultsJaipur = await placesService.searchPlaceSuggestions('जयपुर');
      expect(resultsJaipur, isNotEmpty);
      expect(resultsJaipur.any((p) => p.name == 'Jaipur'), isTrue);

      final resultsTaj = await placesService.searchPlaceSuggestions('ताज महल');
      expect(resultsTaj, isNotEmpty);
      expect(resultsTaj.any((p) => p.name == 'Taj Mahal'), isTrue);
    });

    test('Case-insensitive and whitespace-padded queries resolve safely', () async {
      final results = await placesService.searchPlaceSuggestions('   mUmBaI   ');
      expect(results, isNotEmpty);
      expect(results.any((p) => p.name == 'Mumbai'), isTrue);
    });

    test('Empty and single-character queries return empty list immediately without error', () async {
      expect(await placesService.searchPlaceSuggestions(''), isEmpty);
      expect(await placesService.searchPlaceSuggestions('   '), isEmpty);
      expect(await placesService.searchPlaceSuggestions('J'), isEmpty);
    });

    test('Gibberish input returns empty list safely without crashing', () async {
      final results = await placesService.searchPlaceSuggestions('xyzqwe999zz');
      expect(results, isEmpty);
    });

    test('Backward-compatible autocomplete() returns required description and placeId', () async {
      final results = await placesService.autocomplete('Goa');
      expect(results, isNotEmpty);
      expect(results.first.containsKey('description'), isTrue);
      expect(results.first.containsKey('placeId'), isTrue);
      expect(results.first.containsKey('name'), isTrue);
    });

    test('getPlaceDetails returns accurate coordinates and address without null crashes', () async {
      final details = await placesService.getPlaceDetails('curated_taj_mahal');
      expect(details['name'], equals('Taj Mahal'));
      expect(details['latitude'], inInclusiveRange(27.0, 28.0));
      expect(details['longitude'], inInclusiveRange(77.0, 79.0));
      expect(details['rating'], isNotNull);
    });

    test('PlaceSuggestion model provides correct category icons and labels', () {
      const citySuggestion = PlaceSuggestion(
        name: 'Delhi',
        secondaryText: 'India',
        fullDescription: 'Delhi, India',
        placeId: 'delhi',
        type: 'city',
      );
      expect(citySuggestion.typeLabel, equals('City / Destination'));

      const monumentSuggestion = PlaceSuggestion(
        name: 'Taj Mahal',
        secondaryText: 'Agra',
        fullDescription: 'Taj Mahal, Agra',
        placeId: 'taj',
        type: 'monument',
      );
      expect(monumentSuggestion.typeLabel, equals('Heritage & Landmark'));
    });
  });
}
