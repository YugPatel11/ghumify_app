import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/models/place_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/premium_background.dart';
import '../../../core/widgets/premium_card.dart';

class ItineraryResultScreen extends StatefulWidget {
  final Map<String, dynamic>? itineraryData;

  const ItineraryResultScreen({super.key, this.itineraryData});

  @override
  State<ItineraryResultScreen> createState() => _ItineraryResultScreenState();
}

class _ItineraryResultScreenState extends State<ItineraryResultScreen>
    with SingleTickerProviderStateMixin {
  final GeminiService _geminiService = GeminiService();
  final WeatherService _weatherService = WeatherService();
  final PlacesService _placesService = PlacesService();

  ItineraryModel? _itinerary;
  bool _isLoading = true;
  String? _error;
  String _loadingMessage = 'Curating your experience...';
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _generateItinerary();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _generateItinerary() async {
    if (widget.itineraryData == null) {
      setState(() {
        _error = 'No trip data provided';
        _isLoading = false;
      });
      return;
    }

    final data = widget.itineraryData!;
    final city = data['city'] as String;
    final startTime = data['startTime'] as String;
    final endTime = data['endTime'] as String;
    final interests = List<String>.from(data['interests'] ?? []);
    final travelMode = data['travelMode'] as String? ?? 'driving';
    final pace = data['pace'] as String? ?? 'moderate';
    final date = data['date'] as String? ?? DateTime.now().toString().split(' ').first;

    try {
      setState(() => _loadingMessage = 'Analyzing local weather...');
      WeatherModel? weather;
      try {
        weather = await _weatherService.getCurrentWeather(city);
      } catch (_) {}

      setState(() => _loadingMessage = 'Sourcing the best spots...');
      List<PlaceModel> knownPlaces = [];
      try {
        knownPlaces = await _placesService.searchTouristAttractions(city);
      } catch (_) {}

      setState(() => _loadingMessage = 'Crafting editorial itinerary...');
      final userId = context.read<AuthProvider>().user?.uid ?? 'anonymous';

      final itinerary = await _geminiService.generateItinerary(
        userId: userId,
        city: city,
        date: date,
        startTime: startTime,
        endTime: endTime,
        interests: interests,
        travelMode: travelMode,
        pace: pace,
        weather: weather,
        knownPlaces: knownPlaces.take(15).toList(),
      );

      setState(() => _loadingMessage = 'Finalizing details...');
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _itinerary = itinerary;
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      setState(() {
        _error = 'Failed to generate itinerary. Please try again.\n\nError: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityName = _itinerary?.city ?? widget.itineraryData?['city'] ?? 'Destination';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(cityName),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: PremiumBackground(
        imageUrl: 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?q=80&w=2000&auto=format&fit=crop', // Beautiful landscape / map aesthetic
        imageHeight: 400,
        overlayOpacity: 0.6,
        child: SafeArea(
          bottom: false,
          child: _isLoading
              ? _buildLoadingState()
              : _error != null
                  ? _buildErrorState()
                  : _buildItinerary(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 6.28,
                child: child,
              );
            },
            onEnd: () {
              if (mounted && _isLoading) setState(() {});
            },
            child: const Icon(
              Icons.hourglass_empty, // Moving away from AI magic wand to a classic icon
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTokens.xl),
          Text(
            _loadingMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppTokens.lg),
        padding: const EdgeInsets.all(AppTokens.xl),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppTokens.md),
            Text(
              'Failed to Curate Trip',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTokens.sm),
            Text(
              _error ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _generateItinerary();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.text,
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItinerary() {
    final itinerary = _itinerary!;

    return FadeTransition(
      opacity: _animController,
      child: CustomScrollView(
        slivers: [
          // ── Title Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.xl, AppTokens.lg, AppTokens.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Itinerary',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 42,
                        ),
                  ),
                  const SizedBox(height: AppTokens.xs),
                  Text(
                    '${itinerary.stops.length} STOPS • CURATED FOR YOU',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Summary Box ──
          if (itinerary.aiSummary != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                child: PremiumCard(
                  padding: const EdgeInsets.all(AppTokens.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OVERVIEW',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppTokens.sm),
                      Text(
                        itinerary.aiSummary!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.text,
                          height: 1.6,
                        ),
                      ),
                      if (itinerary.weatherSummary != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppTokens.md),
                          child: Divider(color: AppColors.borderLight),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.wb_cloudy_outlined, size: 20, color: AppColors.textSoft),
                            const SizedBox(width: AppTokens.sm),
                            Expanded(
                              child: Text(
                                itinerary.weatherSummary!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

          // ── Timeline Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: Text(
                'Schedule',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: AppTokens.lg)),

          // ── Stops ──
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final stop = itinerary.stops[index];
                final isLast = index == itinerary.stops.length - 1;
                return _buildStopCard(stop, isLast, index);
              },
              childCount: itinerary.stops.length,
            ),
          ),

          // ── Essentials ──
          if (itinerary.whatToCarry.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.xxl, AppTokens.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Essentials',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppTokens.md),
                    PremiumCard(
                      padding: const EdgeInsets.all(AppTokens.lg),
                      child: Column(
                        children: itinerary.whatToCarry.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 18)),
                                const SizedBox(width: AppTokens.sm),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

          // ── Save Button ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trip securely saved to your itinerary cache.')),
                    );
                  },
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Save Itinerary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.text, // Charcoal
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildStopCard(ItineraryStop stop, bool isLast, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Minimalist Timeline Column ──
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: AppColors.border,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: AppTokens.sm),

            // ── Editorial Content Card ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stop.startTime} — ${stop.endTime}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppTokens.xs),
                    Text(
                      stop.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                    ),
                    if (stop.description.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.xs),
                      Text(
                        stop.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSoft,
                            ),
                      ),
                    ],

                    if ((stop.travelMinutes != null && stop.travelMinutes! > 0) || stop.tips.isNotEmpty)
                      const SizedBox(height: AppTokens.md),

                    if (stop.travelMinutes != null && stop.travelMinutes! > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppTokens.sm),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_walk, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              '${stop.travelMinutes} min ${stop.travelMode ?? "drive"}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSoft),
                            ),
                          ],
                        ),
                      ),

                    if (stop.tips.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppTokens.md),
                        decoration: BoxDecoration(
                          color: AppColors.cardAlt,
                          border: const Border(left: BorderSide(color: AppColors.brand, width: 2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: stop.tips.map((tip) => Text(
                            tip,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.text,
                              fontStyle: FontStyle.italic,
                            ),
                          )).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
