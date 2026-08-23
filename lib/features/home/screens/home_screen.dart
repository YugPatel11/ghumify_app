import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/utils/image_resolver.dart';
import '../widgets/weather_card.dart';
import '../widgets/category_grid.dart';
import '../widgets/popular_cities.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  WeatherModel? _weather;
  String? _currentCity;
  bool _loadingWeather = true;
  late AnimationController _animController;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animController.forward();
    
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    
    _loadWeather();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    try {
      final city = await _locationService.getCurrentCity();
      final weather = await _weatherService.getCurrentWeather(city);
      if (mounted) {
        setState(() {
          _currentCity = city;
          _weather = weather;
          _loadingWeather = false;
        });
      }
    } catch (e) {
      // Fallback
      try {
        final weather = await _weatherService.getCurrentWeather('New Delhi');
        if (mounted) {
          setState(() {
            _currentCity = 'New Delhi';
            _weather = weather;
            _loadingWeather = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _loadingWeather = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final heroImageUrl = ImageResolver.getHeroImage(_currentCity ?? 'Jaipur');
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Let background image show through
      body: Stack(
        children: [
          // ── Dynamic Full-Screen Background ──
          Positioned.fill(
            child: Image.network(
              heroImageUrl,
              fit: BoxFit.cover,
            ),
          ),
          // ── Atmospheric Overlay ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.7),
                    Colors.white.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // ── Scrollable Content ──
          RefreshIndicator(
            onRefresh: _loadWeather,
            color: AppColors.brand,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 80)),

                // ── Welcome Text ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                    child: FadeTransition(
                      opacity: _animController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              color: AppColors.brandDeep,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Where to\nNext?',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppColors.text,
                              fontSize: 52,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

                // ── Search / Plan Trip Glass Bar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                    child: _buildSearchGlassBar(context),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

                // ── Content Below Fold ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                    child: WeatherCard(
                      weather: _weather,
                      isLoading: _loadingWeather,
                      city: _currentCity,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

                // Categories Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Experiences',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          'See All',
                          style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600, fontSize: 14),
                        )
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.md)),
                const SliverToBoxAdapter(
                  child: CategoryGrid(),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

                // Popular Cities
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                    child: Text(
                      'Popular Destinations',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.md)),
                const SliverToBoxAdapter(
                  child: PopularCities(),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom nav
              ],
            ),
          ),

          // ── Sticky Glassmorphism App Bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildStickyAppBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyAppBar() {
    // Calculate opacity based on scroll
    final opacity = (_scrollOffset / 150.0).clamp(0.0, 1.0);
    
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: opacity * 15, sigmaY: opacity * 15),
        child: Container(
          color: AppColors.bgElevated.withOpacity(opacity * 0.7),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 10,
            left: AppTokens.lg,
            right: AppTokens.lg,
          ),
          child: Row(
            children: [
              if (_currentCity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.glassWhiteLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderGlass),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppColors.brandDeep),
                        const SizedBox(width: 4),
                        Text(
                          _currentCity!.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              const Spacer(),
              // Profile or Actions
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.glassWhiteLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGlass),
                ),
                child: Icon(Icons.person_outline, size: 20, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchGlassBar(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/plan-trip'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: AppColors.borderGlass, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.brandDeep, size: 28),
                const SizedBox(width: AppTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Trip Planner',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Generate an itinerary in seconds',
                        style: TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_forward_ios, color: AppColors.brand, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }
}

