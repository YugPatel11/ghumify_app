import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/widgets/premium_card.dart';

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
        final details = await _placesService.getPlaceDetails(_googlePlaceId!);
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
        _history = 'Editorial information is currently unavailable.';
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Dynamic Full-Screen Background ──
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1582510003544-4d00b7f7415e?q=80&w=2000&auto=format&fit=crop', // Taj Mahal / Heritage fallback
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
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.95),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              // ── Editorial Hero Header ──
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.glassWhiteLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderGlass),
                        ),
                        child: const Icon(Icons.arrow_back, color: AppColors.brandDeep, size: 20),
                      ),
                    ),
                  ),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: AppTokens.lg),
                  title: Text(
                    _name,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.brandDeep,
                      fontSize: 24,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // ── Content Area ──
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _animController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.xl, AppTokens.lg, AppTokens.xxl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(AppTokens.xl),
                          decoration: BoxDecoration(
                            color: AppColors.glassWhite,
                            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                            border: Border.all(color: AppColors.borderGlass),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Metadata Row ──
                              Row(
                                children: [
                                  Text(
                                    _category.toUpperCase(),
                                    style: TextStyle(
                                      color: AppColors.accentDeep,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (_rating != null) ...[
                                    const Spacer(),
                                    const Icon(Icons.star, size: 16, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      _rating!.toStringAsFixed(1),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppTokens.lg),

                              // ── Location Details ──
                              if (_address != null && _address!.isNotEmpty)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 20,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: AppTokens.sm),
                                    Expanded(
                                      child: Text(
                                        _address!,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: AppColors.textSoft,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),

                              if (_details?['opening_hours'] != null) ...[
                      const SizedBox(height: AppTokens.md),
                      _buildOpeningHours(),
                    ],

                    const SizedBox(height: AppTokens.xl),

                    // ── Editorial History / About ──
                    Text(
                      'The Story',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: AppTokens.md),
                    _isLoadingHistory
                        ? Column(
                            children: List.generate(
                              4,
                              (index) => Container(
                                height: 16,
                                margin: const EdgeInsets.only(bottom: AppTokens.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.borderLight,
                                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                                ),
                              ),
                            ),
                          )
                        : Text(
                            _history ?? 'Information not available.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.text,
                                  height: 1.8, // Editorial line height
                                  letterSpacing: 0.2,
                                ),
                          ),

                    const SizedBox(height: AppTokens.xxl),

                    // ── Reviews ──
                    if (_details?['reviews'] != null) ...[
                      Text(
                        'Voices',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: AppTokens.md),
                      ..._buildReviews(),
                      const SizedBox(height: AppTokens.xl),
                    ],

                    // ── Action Button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/plan-trip', extra: {'city': _city});
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Add to Itinerary'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.xl),
                  ],
                ),
              ),
            ),
            ),
            ),
          ),
        ),
        ],
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
              size: 20,
              color: isOpen ? AppColors.brand : AppColors.error,
            ),
            const SizedBox(width: AppTokens.sm),
            Text(
              isOpen ? 'Open Now' : 'Closed',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isOpen ? AppColors.brand : AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (weekdayText.isNotEmpty) ...[
          const SizedBox(height: AppTokens.sm),
          ...weekdayText.take(7).map((day) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 28),
                child: Text(
                  day.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSoft,
                      ),
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
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.md),
        child: PremiumCard(
          padding: const EdgeInsets.all(AppTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    (r['author_name'] ?? 'Anonymous').toString().toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppColors.textSoft,
                    ),
                  ),
                  const Spacer(),
                  ...List.generate(
                    (r['rating'] as num?)?.toInt() ?? 0,
                    (_) => const Icon(Icons.star, size: 14, color: AppColors.text),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sm),
              Text(
                r['text'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.text,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
