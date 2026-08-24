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
import '../../../core/widgets/app_image.dart';
import '../../../widgets/image_carousel.dart';
import '../../../widgets/destination_hero.dart';
import '../widgets/weather_card.dart';
import '../widgets/category_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  WeatherModel? _weather;
  String? _currentCity;
  bool _loadingWeather = true;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    _loadWeather();
  }

  @override
  void dispose() {
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Scrollable Content ──
          RefreshIndicator(
            onRefresh: _loadWeather,
            color: AppColors.brand,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── True Hero Header ──
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      // Beautiful hero image
                      const SizedBox(
                        height: 380,
                        width: double.infinity,
                        child: AppImage(
                          imageUrl: 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?q=80&w=2000&auto=format&fit=crop', // India architecture
                          fit: BoxFit.cover,
                        ),
                      ),
                      
                      // Gradient overlay for text readability
                      Container(
                        height: 380,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.6),
                              Colors.black.withOpacity(0.1),
                              AppColors.bg,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 50,
                          left: AppTokens.lg,
                          right: AppTokens.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Where will\nyou go next?',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Search Bar
                            _buildPremiumSearchBar(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

                // ── Distinct Quick Actions ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickAction(context, Icons.auto_awesome, 'AI Trip', AppColors.brand, () => context.push('/plan-trip'), isNew: true),
                        _buildQuickAction(context, Icons.translate_rounded, 'Translate', AppColors.accentDeep, () => context.push('/translator')),
                        _buildQuickAction(context, Icons.bookmark_outline_rounded, 'Saved', AppColors.text, () => context.push('/saved-itineraries')),
                        _buildQuickAction(context, Icons.map_outlined, 'Explore', AppColors.textSoft, () => context.push('/discover')),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

                // ── Trending Destinations Carousel ──
                SliverToBoxAdapter(
                  child: ImageCarousel(
                    sectionTitle: 'Trending in India',
                    items: [
                      CarouselItem(
                        imageUrl: 'https://images.unsplash.com/photo-1593693397690-362cb9666c6b?q=80&w=2000&auto=format&fit=crop',
                        title: 'Jaipur',
                        subtitle: 'The Pink City',
                        onTap: () {},
                      ),
                      CarouselItem(
                        imageUrl: 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?q=80&w=2000&auto=format&fit=crop',
                        title: 'Goa',
                        subtitle: 'Beaches & Sunsets',
                        onTap: () {},
                      ),
                      CarouselItem(
                        imageUrl: 'https://images.unsplash.com/photo-1564507592208-028271380905?q=80&w=2000&auto=format&fit=crop',
                        title: 'Kerala',
                        subtitle: "God's Own Country",
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

                // ── Highlight Destination Hero ──
                SliverToBoxAdapter(
                  child: DestinationHero(
                    imageUrl: 'https://images.unsplash.com/photo-1621217277884-7a31ff8db452?q=80&w=2000&auto=format&fit=crop', // Taj Mahal
                    title: 'Agra',
                    subtitle: 'Symbol of eternal love',
                    badgeText: 'TOP PICK',
                    onExploreTap: () {},
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

                // ── Categories Header ──
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
                        TextButton(
                          onPressed: () {},
                          child: const Text('See All', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                        )
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: CategoryGrid(),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

                // ── Weather & Info ──
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

                const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for bottom nav
              ],
            ),
          ),

          // ── Sticky App Bar (Fades in on scroll) ──
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

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap, {bool isNew = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              if (isNew)
                Positioned(
                  top: -5,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStickyAppBar() {
    final opacity = (_scrollOffset / 150.0).clamp(0.0, 1.0);
    
    return IgnorePointer(
      ignoring: opacity == 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: AppColors.bg.withOpacity(0.9),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 15,
                left: AppTokens.lg,
                right: AppTokens.lg,
              ),
              child: Row(
                children: [
                  const Text(
                    'Ghumify',
                    style: TextStyle(
                      color: AppColors.brandDeep,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (_currentCity != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: AppColors.textSoft),
                        const SizedBox(width: 4),
                        Text(
                          _currentCity!,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/plan-trip'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30), // Pill shape for search
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.brand, size: 24),
            const SizedBox(width: AppTokens.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search Destinations',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cities, hotels, or attractions',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 20),
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
