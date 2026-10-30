import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/app_settings_provider.dart';

/// Full-screen splash screen displaying the curated "splash page" visual
/// with seamless startup initialization, zero-flash transitions, and safe routing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeTransitionController;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false;

  // Background color matching the top edge of splash page.png to prevent any visible letterboxing
  static const Color _splashEdgeColor = Color(0xFF5997C9);

  @override
  void initState() {
    super.initState();

    // Set immersive edge-to-edge transparent system overlay for the splash
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _fadeTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0, // Fully visible initially
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeTransitionController,
      curve: Curves.easeInOut,
    );

    _runStartupSequence();
  }

  /// Coordinates service readiness, auth state validation, and smooth navigation.
  Future<void> _runStartupSequence() async {
    final stopwatch = Stopwatch()..start();

    String nextRoute = '/login';

    try {
      // 1. Minimum display time benchmark (1500ms) to ensure smooth presentation without flickering
      const minDisplayDuration = Duration(milliseconds: 1600);

      final settingsProvider = context.read<AppSettingsProvider>();
      final authProvider = context.read<AuthProvider>();

      if (settingsProvider.isFirstLaunch) {
        nextRoute = '/onboarding';
      } else {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          // Await auth listener to hydrate user profile with a strict safety timeout
          int attempts = 0;
          while (authProvider.user == null && attempts < 8 && mounted) {
            await Future.delayed(const Duration(milliseconds: 150));
            attempts++;
          }
          nextRoute = authProvider.isLoggedIn ? '/home' : '/login';
        } else {
          nextRoute = '/login';
        }
      }

      // Ensure minimum display time has elapsed
      final elapsed = stopwatch.elapsed;
      if (elapsed < minDisplayDuration) {
        await Future.delayed(minDisplayDuration - elapsed);
      }
    } catch (_) {
      // Defensive fallback to prevent splash lockup on any startup exception
      nextRoute = '/login';
    } finally {
      stopwatch.stop();
      if (mounted && !_isNavigating) {
        _isNavigating = true;
        // Smooth fade-out transition before route replacement
        await _fadeTransitionController.reverse();
        if (mounted) {
          context.go(nextRoute);
        }
      }
    }
  }

  @override
  void dispose() {
    _fadeTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashEdgeColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: _splashEdgeColor,
          child: Image.asset(
            AppConstants.splashPagePath,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                AppConstants.splashPageOriginalPath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              );
            },
          ),
        ),
      ),
    );
  }
}
