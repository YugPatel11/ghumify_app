import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
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
  
  bool _isAudioPlaying = false;

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
    if (_googlePlaceId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final details = await _placesService.getPlaceDetails(_googlePlaceId!);
      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prompt =
          "Write a 3 paragraph historical summary and cultural significance of $_name in $_city, India. Make it engaging for a tourist. Format it in plain text without markdown.";
      final history = await _geminiService.generateText(prompt);
      if (mounted) {
        setState(() {
          _history = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_border, color: Colors.white),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: _getCategoryGradient(_category),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Subtle pattern overlay could go here
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 160,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.bg,
                              AppColors.bg.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                                ),
                                child: Text(
                                  _category.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              if (_rating != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star,
                                          color: AppColors.accentLight, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        _rating!.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _name,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppColors.brand, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _city,
                                style: const TextStyle(
                                  color: AppColors.textSoft,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: _isAudioPlaying ? Icons.pause_circle : Icons.headset,
                          label: 'Audio Guide',
                          onTap: () {
                            setState(() => _isAudioPlaying = !_isAudioPlaying);
                          },
                          isPrimary: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.directions_car,
                          label: 'Book Ride',
                          onTap: () {},
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),
                  
                  if (_isAudioPlaying) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up, color: AppColors.brandDeep),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Playing Audio Guide...', style: TextStyle(color: AppColors.brandDeep, fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: 0.3,
                                  backgroundColor: AppColors.brand.withOpacity(0.2),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandDeep),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  ],

                  const SizedBox(height: 32),

                  // History Section
                  Row(
                    children: [
                      const Icon(Icons.history_edu, color: AppColors.brand),
                      const SizedBox(width: 8),
                      Text(
                        'History & Culture',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: AppColors.brand),
                      ),
                    )
                  else if (_history != null)
                    Text(
                      _history!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSoft,
                            height: 1.6,
                          ),
                    )
                  else
                    const Text('History not available.'),

                  const SizedBox(height: 32),

                  // Location Details
                  if (_address != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: AppColors.brand),
                        const SizedBox(width: 8),
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: AppTokens.shadow(level: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.brandSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.map, color: AppColors.brand),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _address!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSoft,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Details API Data
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: AppColors.brand),
                      ),
                    )
                  else if (_details != null) ...[
                    if (_details!['opening_hours'] != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: AppColors.brand),
                          const SizedBox(width: 8),
                          Text(
                            'Opening Hours',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                          border: Border.all(color: AppColors.borderLight),
                          boxShadow: AppTokens.shadow(level: 1),
                        ),
                        child: Column(
                          children: (_details!['opening_hours']['weekday_text']
                                  as List<dynamic>)
                              .map((day) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            size: 16, color: AppColors.teal),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            day.toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textSoft,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 60), // bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppColors.cherryGradient : null,
          color: isPrimary ? null : AppColors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: isPrimary ? null : Border.all(color: AppColors.border),
          boxShadow: isPrimary ? AppTokens.coloredShadow(AppColors.brand, level: 1) : AppTokens.shadow(level: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : AppColors.text,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getCategoryGradient(String category) {
    switch (category) {
      case 'heritage':
        return AppColors.cherryGradient;
      case 'temples':
        return AppColors.saffronGradient;
      case 'food':
        return AppColors.roseGradient;
      case 'markets':
        return AppColors.indigoGradient;
      case 'nature':
        return AppColors.tealGradient;
      case 'culture':
        return AppColors.sunsetGradient;
      default:
        return AppColors.cherryGradient;
    }
  }
}
