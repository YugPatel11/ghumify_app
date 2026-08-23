import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Main shell with floating glass bottom navigation bar
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/discover')) return 1;
    if (location.startsWith('/translator')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/discover');
        break;
      case 2:
        context.go('/translator');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      extendBody: true, // Crucial for glassmorphism to show content underneath
      body: child,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              border: Border.all(color: AppColors.borderGlass, width: 1),
              boxShadow: AppTokens.shadow(level: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => _onItemTapped(context, index),
                  animationDuration: const Duration(milliseconds: 300),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, // Cleaner look
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: AppColors.brandSoft.withOpacity(0.5),
                  height: 64, // Slightly shorter for floating bar
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined, color: AppColors.textSoft),
                      selectedIcon: Icon(Icons.home_rounded, color: AppColors.brandDeep),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.explore_outlined, color: AppColors.textSoft),
                      selectedIcon: Icon(Icons.explore_rounded, color: AppColors.brandDeep),
                      label: 'Discover',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.translate_outlined, color: AppColors.textSoft),
                      selectedIcon: Icon(Icons.translate_rounded, color: AppColors.brandDeep),
                      label: 'Translate',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline, color: AppColors.textSoft),
                      selectedIcon: Icon(Icons.person_rounded, color: AppColors.brandDeep),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

