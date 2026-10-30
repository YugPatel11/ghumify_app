import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/constants/meal_config.dart';
import 'package:ghumify_app/core/models/meal_suggestion_model.dart';
import 'package:ghumify_app/core/models/weather_model.dart';
import 'package:ghumify_app/core/widgets/destination_card.dart';
import 'package:ghumify_app/features/home/widgets/weather_card.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/features/trip_planner/widgets/craft_selector_card.dart';
import 'package:ghumify_app/features/trip_planner/widgets/craft_step_indicator.dart';
import 'package:ghumify_app/features/trip_planner/widgets/itinerary_stop_card.dart';
import 'package:ghumify_app/features/trip_planner/widgets/meal_suggestion_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Responsive UI Layout Tests (320px viewport)', () {
    testWidgets('CraftSelectorCard renders with long title & badge without overflow on 320px screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: CraftSelectorCard(
                  title: 'Public Transit & Metro Rail Network',
                  subtitle: 'Fastest eco-friendly way to navigate heritage stops.',
                  icon: Icons.directions_transit_rounded,
                  isSelected: true,
                  badge: 'Most Popular',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CraftSelectorCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CraftStepIndicator renders on 320px screen without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: CraftStepIndicator(
                  currentStep: 3,
                  totalSteps: 4,
                  stepLabels: [
                    'Destinations',
                    'Rhythm & Mode',
                    'Interests & Mood',
                    'Passions & Review',
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CraftStepIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('ItineraryStopCard renders collapsed and expanded on 320px screen without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockStop = ItineraryStop(
        name: 'Very Long Historical Monument and Palace Complex',
        type: 'place',
        startTime: '10:00 AM',
        endTime: '12:30 PM',
        durationMinutes: 150,
        shortLabel: 'Historic Palace Complex in North Sector',
        briefDescription: 'A magnificent heritage fortress showcasing royal architecture.',
        distanceFromPrevKm: 14.8392,
        openingHours: '09:00 - 18:00',
        ticketPrice: '₹50 per person',
        tips: ['Visit early to avoid long queues at ticket counter.'],
        isKidFriendly: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ItineraryStopCard(
                  index: 0,
                  stop: mockStop,
                  isLast: false,
                  isExpanded: false,
                  onToggleExpand: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ItineraryStopCard), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Also test expanded
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ItineraryStopCard(
                  index: 0,
                  stop: mockStop,
                  isLast: false,
                  isExpanded: true,
                  onToggleExpand: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });
    testWidgets('DestinationCard renders on 320px screen without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: DestinationCard(
                  imageUrl: 'https://images.unsplash.com/photo-1544735716-392fe2489ffa',
                  title: 'Very Long Destination Title In Himachal Pradesh',
                  subtitle: 'Detailed description that stretches across multiple lines and would overflow without expanded text wrapping',
                  rating: 4.8,
                  badge: 'Adventure',
                  isFeatured: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(DestinationCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WeatherCard renders cleanly on 320px screen without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockWeather = WeatherModel(
        city: 'Thiruvananthapuram Metropolitan Area',
        temperature: 28.5,
        feelsLike: 31.0,
        tempMin: 26.0,
        tempMax: 30.0,
        humidity: 85,
        condition: 'Thunderstorm',
        conditionDescription: 'heavy thunderstorms with precipitation and wind gusts',
        iconCode: '11d',
        windSpeed: 5.2,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: WeatherCard(
                  weather: mockWeather,
                  city: 'Thiruvananthapuram',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(WeatherCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MealSuggestionCard wraps action buttons on 320px screen without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockSuggestion = MealSuggestionModel(
        id: 'test_rest_1',
        name: 'The Grand Heritage Authentic Thali & Fine Dining Restaurant',
        mealType: MealConfig.lunch,
        dietaryType: 'veg',
        dietaryBadge: 'Pure Veg',
        cuisine: 'North Indian, South Indian & Gujarati',
        latitude: 28.6139,
        longitude: 77.2090,
        distanceMeters: 450,
        walkingMinutes: 6,
        rating: 4.7,
        reviewCount: 1250,
        priceLevel: '₹₹',
        phone: '+919876543210',
        suggestedReason: 'Near your visit to India Gate around lunch hour',
        fetchedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: MealSuggestionCard(
                  mealType: MealConfig.lunch,
                  anchorStopName: 'India Gate Monument',
                  suggestions: [mockSuggestion],
                  onAddToItinerary: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(MealSuggestionCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
