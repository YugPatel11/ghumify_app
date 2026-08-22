import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/places_service.dart';
import '../../../core/models/place_model.dart';
import '../../../core/widgets/premium_background.dart';
import '../../../core/widgets/premium_card.dart';

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

  final Map<String, IconData> _categoryIcons = {
    'all': Icons.public,
    'heritage': Icons.account_balance,
    'temples': Icons.temple_hindu,
    'food': Icons.restaurant,
    'markets': Icons.storefront,
    'nature': Icons.park,
    'culture': Icons.theater_comedy,
  };

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Discover'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: Colors.white,
          fontSize: 28,
        ),
      ),
      body: PremiumBackground(
        imageUrl: 'https://images.unsplash.com/photo-1596422846543-74c6fc0e241e?q=80&w=2000&auto=format&fit=crop', // Varanasi ghats / cultural
        imageHeight: 380,
        overlayOpacity: 0.5,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTokens.xl),
              // ── Search Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Search city (e.g. Jaipur)',
                            hintStyle: TextStyle(color: AppColors.textSoft.withOpacity(0.7)),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textSoft),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: AppColors.textSoft),
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
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.sm),
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: IconButton(
                        onPressed: _searchPlaces,
                        icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTokens.lg),

              // ── Categories ──
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                  children: _categoryIcons.entries.map((entry) {
                    final isSelected = _selectedCategory == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTokens.sm),
                      child: FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.value,
                              size: 16,
                              color: isSelected ? Colors.white : AppColors.brand,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.key == 'all'
                                  ? 'All Places'
                                  : entry.key[0].toUpperCase() + entry.key.substring(1),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedCategory = entry.key);
                          if (_searchCity.isNotEmpty) _searchPlaces();
                        },
                        selectedColor: AppColors.text,
                        backgroundColor: isSelected ? AppColors.text : Colors.white.withOpacity(0.85),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                          side: BorderSide(
                            color: isSelected ? AppColors.text : Colors.transparent,
                          ),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppTokens.lg),

              // ── Results Body ──
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppTokens.radiusXl),
                      topRight: Radius.circular(AppTokens.radiusXl),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTokens.radiusXl),
                      topRight: Radius.circular(AppTokens.radiusXl),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.brand),
                          )
                        : _error != null
                            ? _buildError()
                            : _places.isEmpty
                                ? _buildEmptyState()
                                : _buildPlacesList(),
                  ),
                ),
              ),
            ],
          ),
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
            decoration: const BoxDecoration(
              color: AppColors.cardAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppTokens.lg),
          Text(
            _searchCity.isEmpty
                ? 'Discover hidden gems'
                : 'No places found in $_searchCity',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textSoft,
                ),
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
          OutlinedButton(
            onPressed: _searchPlaces,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.xl, AppTokens.lg, AppTokens.xxl),
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
      child: PremiumCard(
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
        padding: const EdgeInsets.all(AppTokens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon Block
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getCategoryColor(place.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: _getCategoryColor(place.category).withOpacity(0.2)),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(place.category),
                  color: _getCategoryColor(place.category),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.lg),

            // Content Block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _getCategoryColor(place.category),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (place.address != null && place.address!.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.address!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            // Rating Block
            if (place.rating != null) ...[
              const SizedBox(width: AppTokens.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: AppColors.accentDeep),
                    const SizedBox(width: 4),
                    Text(
                      place.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
    );
  }

  IconData _getCategoryIcon(String category) {
    return _categoryIcons[category] ?? Icons.place;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'heritage':
        return AppColors.brand;
      case 'temples':
        return AppColors.accent;
      case 'food':
        return AppColors.rose;
      case 'markets':
        return AppColors.indigo;
      case 'nature':
        return AppColors.teal;
      case 'culture':
        return const Color(0xFFD946EF);
      default:
        return AppColors.textSoft;
    }
  }
}
