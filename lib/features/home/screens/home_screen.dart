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
      // Fallback — try with a default city
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
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWeather,
          color: AppColors.brand,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _animController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.name ?? 'Traveler',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                            ],
                          ),
                        ),
                        // Logo
                        Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            AppConstants.logoPath,
                            height: 48,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Location
              if (_currentCity != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentCity!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

              // Plan Trip CTA
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildPlanTripCard(context),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

              // Weather Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: WeatherCard(
                    weather: _weather,
                    isLoading: _loadingWeather,
                    city: _currentCity,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

              // Categories
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Explore by Category',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.lg)),

              SliverToBoxAdapter(
                child: const CategoryGrid(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

              // Popular Cities
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Popular Destinations',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.lg)),

              const SliverToBoxAdapter(
                child: PopularCities(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          boxShadow: AppTokens.coloredShadow(AppColors.brand, level: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plan Your Trip ✈️',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us your time & interests.\nAI will create the perfect itinerary!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: const Text(
                      'Start Planning →',
                      style: TextStyle(
                        color: AppColors.brandDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.map_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 🌅';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }
}
