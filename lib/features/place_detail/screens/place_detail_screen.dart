import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/gemini_service.dart';

class PlaceDetailScreen extends StatefulWidget {
  final String placeId;
  final Map<String, dynamic>? placeData;

  const PlaceDetailScreen({
    super.key,
    required this.placeId,
    this.placeData,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen>
    with SingleTickerProviderStateMixin {
  final PlacesService _placesService = PlacesService();
  final GeminiService _geminiService = GeminiService();

  Map<String, dynamic>? _details;
  String? _history;
  bool _isLoading = true;
  bool _isLoadingHistory = true;
  late AnimationController _animController;

  String get _name => widget.placeData?['name'] ?? 'Place';
  String get _city => widget.placeData?['city'] ?? '';
  String get _category => widget.placeData?['category'] ?? 'heritage';
  double? get _rating => widget.placeData?['rating']?.toDouble();
  String? get _address => widget.placeData?['address'];
  String? get _googlePlaceId => widget.placeData?['googlePlaceId'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadDetails();
    _loadHistory();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    if (_googlePlaceId != null) {
      try {
        final details =
            await _placesService.getPlaceDetails(_googlePlaceId!);
        setState(() {
          _details = details;
          _isLoading = false;
        });
        _animController.forward();
      } catch (e) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    } else {
      setState(() => _isLoading = false);
      _animController.forward();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _geminiService.generatePlaceHistory(
        placeName: _name,
        city: _city,
      );
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _history = 'Historical information is currently unavailable.';
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero app bar
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _getCategoryColor(_category),
                      _getCategoryColor(_category).withOpacity(0.7),
                    ],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Category icon as background
                    Center(
                      child: Icon(
                        _getCategoryIcon(_category),
                        size: 100,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    // Gradient overlay
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black45],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _animController,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick info row
                    Row(
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(_category)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(_category),
                                size: 16,
                                color: _getCategoryColor(_category),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _category[0].toUpperCase() +
                                    _category.substring(1),
                                style: TextStyle(
                                  color: _getCategoryColor(_category),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Rating
                        if (_rating != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.star, size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            _rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Address
                    if (_address != null && _address!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.neutral500,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _address!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.neutral600),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Opening hours
                    if (_details?['opening_hours'] != null) ...[
                      const SizedBox(height: 16),
                      _buildOpeningHours(),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // History
                    Text(
                      'About & History',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _isLoadingHistory
                        ? Column(
                            children: List.generate(
                              5,
                              (index) => Container(
                                height: 14,
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.neutral200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          )
                        : Text(
                            _history ?? 'Information not available.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.7),
                          ),

                    // Reviews from Google
                    if (_details?['reviews'] != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      Text(
                        'Visitor Reviews',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      ..._buildReviews(),
                    ],

                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.push('/plan-trip',
                                  extra: {'city': _city});
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Plan Trip Here'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningHours() {
    final hours = _details?['opening_hours'];
    if (hours == null) return const SizedBox.shrink();

    final isOpen = hours['open_now'] as bool? ?? false;
    final weekdayText = hours['weekday_text'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 18,
              color: isOpen ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text(
              isOpen ? 'Open Now' : 'Closed',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isOpen ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
        if (weekdayText.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...weekdayText.take(7).map((day) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  day.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )),
        ],
      ],
    );
  }

  List<Widget> _buildReviews() {
    final reviews = _details?['reviews'] as List? ?? [];
    return reviews.take(3).map((review) {
      final r = review as Map<String, dynamic>;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  r['author_name'] ?? 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                ...List.generate(
                  (r['rating'] as num?)?.toInt() ?? 0,
                  (_) => const Icon(Icons.star, size: 14, color: Colors.amber),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r['text'] ?? '',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'heritage': return AppColors.primaryOrange;
      case 'temples': return AppColors.accentGreen;
      case 'food': return AppColors.error;
      case 'markets': return AppColors.secondaryBlue;
      case 'nature': return const Color(0xFF66BB6A);
      case 'culture': return const Color(0xFFAB47BC);
      default: return AppColors.primaryOrange;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'heritage': return Icons.account_balance;
      case 'temples': return Icons.temple_hindu;
      case 'food': return Icons.restaurant;
      case 'markets': return Icons.storefront;
      case 'nature': return Icons.park;
      case 'culture': return Icons.theater_comedy;
      default: return Icons.place;
    }
  }
}
