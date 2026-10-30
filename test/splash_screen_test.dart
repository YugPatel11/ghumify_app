import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/constants/app_constants.dart';
import 'package:ghumify_app/features/auth/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen Visual & Structure Tests', () {
    test('Splash asset constants point to valid splash page paths', () {
      expect(AppConstants.splashPagePath, 'assets/images/splash_page.png');
      expect(AppConstants.splashPageOriginalPath, 'assets/images/splash page.png');
    });

    testWidgets('SplashScreen renders with edge-matching background color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Verify Scaffold uses the exact sampled top-edge background color
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, const Color(0xFF5997C9));

      // Verify splash image is present
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.fit, BoxFit.cover);

      // Verify old splash elements are completely removed
      expect(find.text(AppConstants.appTagline), findsNothing);
      expect(find.text(AppConstants.appDescription), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
