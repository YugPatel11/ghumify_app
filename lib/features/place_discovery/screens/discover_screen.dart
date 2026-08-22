import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
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

  final Map<String, IconData> _categoryIcons = {
    'all': Icons.apps,
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
    // Check if category was passed
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

      // Filter by category if needed
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'Discover',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: 16),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search city (e.g. Indore, Jaipur)',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
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
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed: _searchPlaces,
                      icon: const Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Category filter
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: _categoryIcons.entries.map((entry) {
                  final isSelected = _selectedCategory == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.value,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : AppColors.neutral600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.key == 'all'
                                ? 'All'
                                : entry.key[0].toUpperCase() +
                                    entry.key.substring(1),
                          ),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = entry.key);
                        if (_searchCity.isNotEmpty) _searchPlaces();
                      },
                      selectedColor: AppColors.primaryOrange,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.neutral600,
                        fontSize: 13,
                      ),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
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
          Icon(
            Icons.explore_outlined,
            size: 80,
            color: AppColors.neutral300,
          ),
          const SizedBox(height: 16),
          Text(
            _searchCity.isEmpty
                ? 'Search for a city to discover places'
                : 'No places found in $_searchCity',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.neutral500,
                ),
            textAlign: TextAlign.center,
          ),
          if (_searchCity.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Try "Indore", "Jaipur", or "Varanasi"',
              style: Theme.of(context).textTheme.bodySmall,
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
          Text(_error ?? 'Unknown error'),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _places.length,
      itemBuilder: (context, index) {
        final place = _places[index];
        return _buildPlaceCard(place);
      },
    );
  }

  Widget _buildPlaceCard(PlaceModel place) {
    return GestureDetector(
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _getCategoryColor(place.category).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _getCategoryIcon(place.category),
                color: _getCategoryColor(place.category),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (place.address != null && place.address!.isNotEmpty)
                    Text(
                      place.address!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(place.category)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          place.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _getCategoryColor(place.category),
                          ),
                        ),
                      ),
                      if (place.rating != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          place.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.neutral400,
            ),
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
        return AppColors.primaryOrange;
      case 'temples':
        return AppColors.accentGreen;
      case 'food':
        return AppColors.error;
      case 'markets':
        return AppColors.secondaryBlue;
      case 'nature':
        return const Color(0xFF66BB6A);
      case 'culture':
        return const Color(0xFFAB47BC);
      case 'adventure':
        return const Color(0xFFFF7043);
      default:
        return AppColors.primaryOrange;
    }
  }
}
