import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/widgets/premium_background.dart';
import '../../../core/widgets/premium_card.dart';
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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animController.forward();
    _loadWeather();
  }

  @override
  void dispose() {
    _animController.dispose();
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
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: PremiumBackground(
        imageUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?q=80&w=2000&auto=format&fit=crop', // Stunning India Landscape
        imageHeight: 500,
        overlayOpacity: 0.5,
        child: RefreshIndicator(
          onRefresh: _loadWeather,
          color: AppColors.brand,
          child: CustomScrollView(
            slivers: [
              // ── Header (Logo & Location) ──
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _animController,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.md, AppTokens.lg, 0),
                      child: Row(
                        children: [
                          if (_currentCity != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currentCity!.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          // Logo / App branding
                          Text(
                            'GHUMIFY',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

              // ── Welcome Text ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Explore the\nUnexplored.',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 56,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

              // ── Plan Trip Card (Editorial) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                  child: _buildPlanTripCard(context),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

              // ── Below the fold (Solid Background section) ──
              // Weather Card
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
                  child: Text(
                    'Experiences',
                    style: Theme.of(context).textTheme.headlineMedium,
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

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanTripCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/plan-trip'),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.xl),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95), // Solid luxury white
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURATED JOURNEYS',
                    style: TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Craft Your\nPerfect Itinerary',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.text,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: AppTokens.lg),
                  Row(
                    children: [
                      Text(
                        'START PLANNING',
                        style: TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16, color: AppColors.brand),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_outlined, color: AppColors.brand, size: 32),
            ),
          ],
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
