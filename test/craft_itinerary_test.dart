import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/features/trip_planner/widgets/craft_header.dart';
import 'package:ghumify_app/features/trip_planner/widgets/craft_selector_card.dart';
import 'package:ghumify_app/features/trip_planner/widgets/craft_step_indicator.dart';

void main() {
  group('Craft Itinerary Widget Tests', () {
    testWidgets('CraftStepIndicator renders correct step and percentage',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftStepIndicator(
              currentStep: 0,
              totalSteps: 4,
              stepLabels: const [
                'Where & When',
                'Style & Pace',
                'Group & Budget',
                'Passions & Review',
              ],
            ),
          ),
        ),
      );

      expect(find.text('STEP 1 OF 4'), findsOneWidget);
      expect(find.text('Where & When'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('CraftSelectorCard renders title, subtitle and selected state',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftSelectorCard(
              title: 'Driving / Cab',
              subtitle: 'Comfort and speed',
              icon: Icons.directions_car,
              isSelected: true,
              badge: 'Popular',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Driving / Cab'), findsOneWidget);
      expect(find.text('Comfort and speed'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Driving / Cab'));
      expect(tapped, isTrue);
    });

    testWidgets('CraftHeader renders title and destination pill',
        (tester) async {
      bool backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftHeader(
              heroImageUrl: 'https://example.com/image.jpg',
              destinationName: 'Jaipur',
              onBack: () => backTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Craft Your Itinerary'), findsOneWidget);
      expect(find.text('AI TRIP ARCHITECT'), findsOneWidget);
      expect(find.text('Jaipur'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      expect(backTapped, isTrue);
    });
  });
}
