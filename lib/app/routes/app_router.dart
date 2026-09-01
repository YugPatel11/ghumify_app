import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/app_settings_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/main_shell.dart';
import '../../features/trip_planner/screens/trip_input_screen.dart';
import '../../features/trip_planner/screens/itinerary_result_screen.dart';
import '../../features/trip_planner/screens/multi_day_result_screen.dart';
import '../../features/place_discovery/screens/discover_screen.dart';
import '../../features/place_detail/screens/place_detail_screen.dart';
import '../../features/translator/screens/translator_screen.dart';
import '../../features/trip_planner/screens/saved_itineraries_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/auth/screens/splash_screen.dart';

/// App router using GoRouter
class AppRouter {
  static GoRouter router(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final settingsProvider = context.read<AppSettingsProvider>();

    return GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: false,
      redirect: (context, state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final isOnAuth = state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup';
        final isOnSplash = state.matchedLocation == '/splash';
        final isOnOnboarding = state.matchedLocation == '/onboarding';

        // Let splash screen handle its own logic
        if (isOnSplash) return null;

        // Show onboarding on first launch
        if (settingsProvider.isFirstLaunch && !isOnOnboarding) {
          return '/onboarding';
        }

        // If not logged in, redirect to login
        if (!isLoggedIn && !isOnAuth && !isOnOnboarding) {
          return '/login';
        }

        // If logged in and on auth page, go to home
        if (isLoggedIn && isOnAuth) {
          return '/home';
        }

        return null;
      },
      routes: [
        // Splash
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),

        // Onboarding
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),

        // Auth routes
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),

        // Main app shell with bottom navigation
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeScreen(),
              ),
            ),
            GoRoute(
              path: '/discover',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DiscoverScreen(),
              ),
            ),
            GoRoute(
              path: '/trips',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SavedItinerariesScreen(),
              ),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
            ),
          ],
        ),

        // Translator (standalone route, accessible from home quick actions)
        GoRoute(
          path: '/translator',
          builder: (context, state) => const TranslatorScreen(),
        ),

        // Trip planner flow
        GoRoute(
          path: '/plan-trip',
          builder: (context, state) => const TripInputScreen(),
        ),
        GoRoute(
          path: '/itinerary',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ItineraryResultScreen(itineraryData: extra);
          },
        ),
        GoRoute(
          path: '/multi-day-itinerary',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return MultiDayResultScreen(itineraryData: extra);
          },
        ),
        GoRoute(
          path: '/saved-itineraries',
          builder: (context, state) => const SavedItinerariesScreen(),
        ),

        // Place detail
        GoRoute(
          path: '/place/:id',
          builder: (context, state) {
            final placeId = state.pathParameters['id']!;
            final extra = state.extra as Map<String, dynamic>?;
            return PlaceDetailScreen(
              placeId: placeId,
              placeData: extra,
            );
          },
        ),
      ],
    );
  }
}
