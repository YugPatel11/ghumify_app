import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/places_service.dart';
import '../../../core/models/place_model.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final PlacesService _placesService = PlacesService();
  final TextEditingController _searchController = TextEditingController();

  List<PlaceModel> _places = [];
  bool _isLoading = false;
  String? _error;
  String _selectedCategory = 'all';
  String _searchCity = '';

  static const List<_CatItem> _categories = [
    _CatItem('all', 'All', Icons.public),
    _CatItem('heritage', 'Heritage', Icons.account_balance),
    _CatItem('temples', 'Temples', Icons.temple_hindu),
    _CatItem('food', 'Food', Icons.restaurant),
    _CatItem('markets', 'Markets', Icons.storefront),
    _CatItem('nature', 'Nature', Icons.park),
    _CatItem('culture', 'Culture', Icons.theater_comedy),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null && extra['category'] != null) {
        setState(() {
          _selectedCategory = extra['category'] as String;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    final city = _searchController.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _searchCity = city;
    });

    try {
      List<PlaceModel> results;
      switch (_selectedCategory) {
        case 'food':
          results = await _placesService.searchFoodSpots(city);
          break;
        case 'markets':
          results = await _placesService.searchMarkets(city);
          break;
        default:
          results = await _placesService.searchTouristAttractions(city);
      }

      if (_selectedCategory != 'all' &&
          _selectedCategory != 'food' &&
          _selectedCategory != 'markets') {
        results = results
            .where((p) => p.category == _selectedCategory)
            .toList();
      }

      setState(() {
        _places = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to search places: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTokens.md),
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: Text(
                'Explore',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: Text(
                'Discover amazing places across India',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ),
            const SizedBox(height: AppTokens.lg),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Search city (e.g. Jaipur)',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _places = [];
                                      _searchCity = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _searchPlaces(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _searchPlaces,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.md),

            // ── Category Chips ──
            SizedBox(
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
                      onTap: () {
                        setState(() => _selectedCategory = cat.id);
                        if (_searchCity.isNotEmpty) _searchPlaces();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
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

            const SizedBox(height: AppTokens.md),

            // ── Results ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                  : _error != null
                      ? _buildError()
                      : _places.isEmpty
                          ? _buildEmptyState()
                          : _buildPlacesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.xl),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.explore_outlined, size: 48, color: AppColors.brand),
          ),
          const SizedBox(height: AppTokens.lg),
          Text(
            _searchCity.isEmpty ? 'Discover hidden gems' : 'No places found in $_searchCity',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.textSoft),
            textAlign: TextAlign.center,
          ),
          if (_searchCity.isEmpty) ...[
            const SizedBox(height: AppTokens.sm),
            Text(
              'Try searching "Indore", "Jaipur", or "Varanasi"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_error ?? 'Unknown error', style: const TextStyle(color: AppColors.textSoft)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _searchPlaces,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.sm, AppTokens.lg, AppTokens.xxl),
      itemCount: _places.length,
      itemBuilder: (context, index) {
        final place = _places[index];
        return _buildPlaceCard(place);
      },
    );
  }

  Widget _buildPlaceCard(PlaceModel place) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.md),
      child: GestureDetector(
        onTap: () {
          context.push('/place/${place.id}', extra: {
            'name': place.name,
            'city': place.city,
            'category': place.category,
            'latitude': place.latitude,
            'longitude': place.longitude,
            'rating': place.rating,
            'address': place.address,
            'googlePlaceId': place.googlePlaceId,
          });
        },
        child: Container(
          padding: const EdgeInsets.all(AppTokens.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _getCategoryColor(place.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(place.category),
                    color: _getCategoryColor(place.category),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _getCategoryColor(place.category),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (place.address != null && place.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.address!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (place.rating != null) ...[
                const SizedBox(width: AppTokens.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 12, color: AppColors.accentDeep),
                      const SizedBox(width: 4),
                      Text(
                        place.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    for (final cat in _categories) {
      if (cat.id == category) return cat.icon;
    }
    return Icons.place;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'heritage':
        return AppColors.brand;
      case 'temples':
        return AppColors.accent;
      case 'food':
        return AppColors.warning;
      case 'markets':
        return AppColors.brandDeep;
      case 'nature':
        return AppColors.success;
      case 'culture':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.textSoft;
    }
  }
}

class _CatItem {
  final String id;
  final String label;
  final IconData icon;
  const _CatItem(this.id, this.label, this.icon);
}
