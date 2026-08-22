import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/models/place_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';

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
  String _loadingMessage = 'Preparing your trip...';
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
      // Step 1: Fetch weather
      setState(() => _loadingMessage = 'Checking weather in $city... ☀️');
      WeatherModel? weather;
      try {
        weather = await _weatherService.getCurrentWeather(city);
      } catch (_) {
        // Weather is optional
      }

      // Step 2: Fetch known places
      setState(() => _loadingMessage = 'Discovering places in $city... 🗺️');
      List<PlaceModel> knownPlaces = [];
      try {
        knownPlaces = await _placesService.searchTouristAttractions(city);
      } catch (_) {
        // Places data is supplementary
      }

      // Step 3: Generate AI itinerary
      setState(() => _loadingMessage = 'AI is crafting your perfect itinerary... ✨');
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

      // Step 4: Save trip (mocked)
      setState(() => _loadingMessage = 'Saving your trip... 💾');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_itinerary?.city ?? 'Your Itinerary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_itinerary != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                // TODO: Share itinerary
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share feature coming soon!')),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildItinerary(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
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
                // Restart animation
                if (mounted && _isLoading) setState(() {});
              },
              child: const Icon(
                Icons.auto_awesome,
                size: 48,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _loadingMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.neutral600,
                  ),
            ),
            const SizedBox(height: 24),
            const LinearProgressIndicator(
              color: AppColors.primaryOrange,
              backgroundColor: AppColors.surfaceCream,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _generateItinerary();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
          // AI Summary
          if (itinerary.aiSummary != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'AI Summary',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      itinerary.aiSummary!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Weather summary
          if (itinerary.weatherSummary != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined,
                        size: 18, color: AppColors.primaryOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        itinerary.weatherSummary!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryOrange,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Trip timeline header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                children: [
                  Text(
                    'Your Itinerary',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${itinerary.stops.length} Stops',
                      style: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stops
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

          // What to Carry
          if (itinerary.whatToCarry.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎒 What to Carry',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCream,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: itinerary.whatToCarry.map((item) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
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

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Save button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Trip saved to your profile!')),
                    );
                  },
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Save This Trip'),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildStopCard(ItineraryStop stop, bool isLast, int index) {
    IconData stopIcon;
    Color iconColor;

    switch (stop.type) {
      case 'food':
        stopIcon = Icons.restaurant;
        iconColor = AppColors.error;
        break;
      case 'market':
        stopIcon = Icons.storefront;
        iconColor = AppColors.secondaryBlue;
        break;
      case 'travel':
        stopIcon = Icons.directions_car;
        iconColor = AppColors.neutral500;
        break;
      case 'break':
        stopIcon = Icons.coffee;
        iconColor = AppColors.accentGreen;
        break;
      default:
        stopIcon = Icons.place;
        iconColor = AppColors.primaryOrange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(stopIcon, size: 20, color: iconColor),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: AppColors.neutral200,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.surfaceDarkCard 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    if (Theme.of(context).brightness == Brightness.light)
                      BoxShadow(
                        color: AppColors.neutral900.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                  ],
                  border: Border.all(
                    color: iconColor.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time and Duration
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${stop.startTime} – ${stop.endTime}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: AppColors.neutral500),
                            const SizedBox(width: 4),
                            Text(
                              '${stop.durationMinutes}m',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.neutral500,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Name
                    Text(
                      stop.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                    ),

                    // Description
                    if (stop.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        stop.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? AppColors.neutral300 
                                  : AppColors.neutral600,
                              height: 1.5,
                            ),
                      ),
                    ],

                    // Travel info
                    if (stop.travelMinutes != null &&
                        stop.travelMinutes! > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions,
                              size: 16,
                              color: AppColors.neutral500,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${stop.travelMinutes} min ${stop.travelMode ?? "drive"}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: AppColors.neutral500, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Tips
                    if (stop.tips.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accentGreen.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: stop.tips.take(2).map((tip) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('💡 ', style: TextStyle(fontSize: 14)),
                                    Expanded(
                                      child: Text(
                                        tip,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.accentGreen,
                                              height: 1.4,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                        ),
                      ),
                    ],
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
