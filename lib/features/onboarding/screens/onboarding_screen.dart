import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/widgets/language_selector_sheet.dart';
import '../../../core/widgets/translated_text.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.explore_outlined,
      title: 'Discover Hidden Gems',
      description:
          'Explore famous places, local food, markets, and cultural experiences across Indian cities.',
      gradient: AppColors.brandGradient,
      softColor: AppColors.brandSoft,
    ),
    _OnboardingPage(
      icon: Icons.schedule_outlined,
      title: 'AI Trip Planner',
      description:
          'Tell us your time and interests — our AI creates a perfect, time-boxed itinerary just for you.',
      gradient: AppColors.premiumDarkGradient,
      softColor: AppColors.cardAlt,
    ),
    _OnboardingPage(
      icon: Icons.wb_sunny_outlined,
      title: 'Weather-Smart',
      description:
          'Get weather-aware suggestions, packing tips, and the best times to visit outdoor spots.',
      gradient: AppColors.tealGradient,
      softColor: AppColors.bgElevated,
    ),
    _OnboardingPage(
      icon: Icons.translate_outlined,
      title: 'Break Language Barriers',
      description:
          'Available in 10 Indian languages with built-in translator for on-the-ground conversations.',
      gradient: AppColors.sunsetGradient,
      softColor: AppColors.accentSoft,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    final settingsProvider = context.read<AppSettingsProvider>();
    await settingsProvider.setFirstLaunchDone();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = context.watch<AppSettingsProvider>().language;
    final langDisplay = AppConstants.supportedLanguages[currentLang]?.split(' ').first ?? 'English';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Language selector + Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: AppTokens.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => showLanguageSelectorSheet(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.brand.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 16, color: AppColors.brand),
                          const SizedBox(width: 6),
                          Text(
                            langDisplay,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.brand),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Tr(
                      'Skip',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon with gradient background
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: page.gradient,
                            shape: BoxShape.circle,
                            boxShadow: AppTokens.coloredShadow(
                              page.gradient.colors.first,
                              level: 2,
                            ),
                          ),
                          child: Icon(
                            page.icon,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Title
                        Tr(
                          page.title,
                          style: Theme.of(context).textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Tr(
                          page.description,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSoft,
                                    height: 1.6,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Page indicators + Next button
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page dots
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == index ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.brand
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Next/Get Started button
                  GestureDetector(
                    onTap: _onNext,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            _currentPage == _pages.length - 1 ? 32 : 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        boxShadow: AppTokens.coloredShadow(AppColors.brand, level: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tr(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final LinearGradient gradient;
  final Color softColor;

  _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.softColor,
  });
}

