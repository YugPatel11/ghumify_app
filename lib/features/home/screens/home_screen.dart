import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/widgets/destination_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/utils/image_resolver.dart';
import '../widgets/weather_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  WeatherModel? _weather;
  String? _currentCity;
  bool _loadingWeather = true;
  String _selectedCategory = 'all';

  static const List<_CategoryData> _categories = [
    _CategoryData('all', 'All', Icons.grid_view_rounded),
    _CategoryData('beach', 'Beach', Icons.beach_access),
    _CategoryData('mountain', 'Mountain', Icons.landscape),
    _CategoryData('heritage', 'Heritage', Icons.account_balance),
    _CategoryData('temples', 'Temples', Icons.temple_hindu),
    _CategoryData('nature', 'Nature', Icons.park),
    _CategoryData('food', 'Food', Icons.restaurant),
  ];

  static const List<_DestinationData> _featured = [
    _DestinationData(
      'Udaipur',
      'Rajasthan, India',
      'assets/images/jaipur.jpeg',
      'City of Lakes',
      4.8,
      2340,
      '₹3,500',
      true,
    ),
  ];

  static const List<_DestinationData> _popular = [
    _DestinationData('Goa', 'India', 'assets/images/goa.jpeg', 'Adventure', 4.7, 5200, '₹4,000', true),
    _DestinationData('Kerala', 'India', 'assets/images/kerela.jpeg', 'Romantic', 4.9, 3800, '₹5,500', true),
    _DestinationData('Agra', 'India', 'assets/images/agra.jpeg', 'Heritage', 4.8, 8100, '₹2,500', true),
    _DestinationData('Jaipur', 'India', 'assets/images/jaipur.jpeg', 'Culture', 4.6, 4500, '₹3,200', true),
  ];

  @override
  void initState() {
    super.initState();
    _loadWeather();
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final userName = user?.name ?? 'Traveler';
    final firstName = userName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWeather,
          color: AppColors.brand,
          child: CustomScrollView(
            slivers: [
              // ── Top Bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.md, AppTokens.lg, 0),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                      ),
                      const Spacer(),
                      // Notification
                      GestureDetector(
                        onTap: () => context.push('/saved-itineraries'),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: AppColors.text, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // User Avatar
                      GestureDetector(
                        onTap: () => context.go('/settings'),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              firstName.isNotEmpty ? firstName[0].toUpperCase() : 'T',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Greeting ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.lg, AppTokens.lg, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()}, $firstName',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Where's your next adventure?",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Search Bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.lg, AppTokens.lg, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/plan-trip'),
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.bgElevated,
                              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Search destinations...',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => context.push('/plan-trip'),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                          ),
                          child: const Icon(Icons.tune, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category Chips ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppTokens.lg),
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.brand : AppColors.bgElevated,
                                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                                border: Border.all(
                                  color: isSelected ? AppColors.brand : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cat.icon,
                                    size: 16,
                                    color: isSelected ? Colors.white : AppColors.textSoft,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textSoft,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.lg)),

              // ── Quick Actions Row ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                  child: Row(
                    children: [
                      _QuickAction(
                        icon: Icons.auto_awesome,
                        label: 'AI Trip',
                        color: AppColors.brand,
                        onTap: () => context.push('/plan-trip'),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.translate_rounded,
                        label: 'Translate',
                        color: AppColors.accentDeep,
                        onTap: () => context.push('/translator'),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.bookmark_outline_rounded,
                        label: 'Saved',
                        color: AppColors.info,
                        onTap: () => context.push('/saved-itineraries'),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.map_outlined,
                        label: 'Explore',
                        color: AppColors.success,
                        onTap: () => context.go('/discover'),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

              // ── Featured Section ──
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Featured',
                  actionText: 'See all',
                  onActionTap: () => context.go('/discover'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.md)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                  child: DestinationCard(
                    imageUrl: _featured[0].image,
                    title: _featured[0].name,
                    subtitle: _featured[0].subtitle,
                    badge: _featured[0].badge,
                    badgeColor: AppColors.badgeBeach,
                    rating: _featured[0].rating,
                    reviewCount: _featured[0].reviewCount,
                    price: _featured[0].price,
                    isAsset: _featured[0].isAsset,
                    isFeatured: true,
                    onTap: () => context.push('/plan-trip', extra: {'city': _featured[0].name}),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

              // ── Popular Section ──
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Popular',
                  actionText: 'See all',
                  onActionTap: () => context.go('/discover'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.md)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _popular.length,
                    itemBuilder: (context, index) {
                      final dest = _popular[index];
                      return DestinationCard(
                        imageUrl: dest.image,
                        title: dest.name,
                        subtitle: dest.subtitle,
                        badge: dest.badge,
                        badgeColor: _getBadgeColor(dest.badge),
                        rating: dest.rating,
                        price: dest.price,
                        isAsset: dest.isAsset,
                        onTap: () => context.push('/plan-trip', extra: {'city': dest.name}),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),

              // ── Weather Card ──
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

              const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xl)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBadgeColor(String badge) {
    switch (badge.toLowerCase()) {
      case 'adventure':
        return AppColors.badgeAdventure;
      case 'romantic':
        return AppColors.badgeRomantic;
      case 'heritage':
        return AppColors.badgeHeritage;
      case 'culture':
        return AppColors.badgeCulture;
      case 'beach':
        return AppColors.badgeBeach;
      case 'nature':
        return AppColors.badgeNature;
      default:
        return AppColors.brand;
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryData {
  final String id;
  final String label;
  final IconData icon;
  const _CategoryData(this.id, this.label, this.icon);
}

class _DestinationData {
  final String name;
  final String subtitle;
  final String image;
  final String badge;
  final double rating;
  final int reviewCount;
  final String price;
  final bool isAsset;
  const _DestinationData(this.name, this.subtitle, this.image, this.badge, this.rating, this.reviewCount, this.price, this.isAsset);
}
