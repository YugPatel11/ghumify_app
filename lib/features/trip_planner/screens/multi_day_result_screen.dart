import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/models/multi_day_itinerary_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/models/place_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/image_resolver.dart';
import '../widgets/itinerary_chat_sheet.dart';
import '../widgets/nearby_services_section.dart';

class MultiDayResultScreen extends StatefulWidget {
  final Map<String, dynamic>? itineraryData;

  const MultiDayResultScreen({super.key, this.itineraryData});

  @override
  State<MultiDayResultScreen> createState() => _MultiDayResultScreenState();
}

class _MultiDayResultScreenState extends State<MultiDayResultScreen>
    with TickerProviderStateMixin {
  final GeminiService _geminiService = GeminiService();
  final WeatherService _weatherService = WeatherService();
  final PlacesService _placesService = PlacesService();

  MultiDayItineraryModel? _itinerary;
  bool _isLoading = true;
  String? _error;
  String _loadingMessage = 'Planning your adventure...';
  late AnimationController _animController;
  TabController? _tabController;
  late String _heroImage;
  late String _cityName;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _cityName = widget.itineraryData?['city'] as String? ?? 'Destination';
    _heroImage = ImageResolver.getHeroImage(_cityName);
    _generateItinerary();
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabController?.dispose();
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
    
    // Check if it's already an existing itinerary being opened
    if (data.containsKey('multiDayItinerary') && data['multiDayItinerary'] is MultiDayItineraryModel) {
      setState(() {
        _itinerary = data['multiDayItinerary'] as MultiDayItineraryModel;
        _cityName = _itinerary!.city;
        _heroImage = ImageResolver.getHeroImage(_cityName);
        _isLoading = false;
      });
      _tabController = TabController(length: _itinerary!.numberOfDays, vsync: this);
      _animController.forward();
      return;
    }

    final city = data['city'] as String;
    final startTime = data['startTime'] as String;
    final endTime = data['endTime'] as String;
    final interests = List<String>.from(data['interests'] ?? []);
    final travelMode = data['travelMode'] as String? ?? 'driving';
    final pace = data['pace'] as String? ?? 'moderate';
    final startDate = data['startDate'] as String? ??
        DateTime.now().toString().split(' ').first;
    final endDate = data['endDate'] as String? ??
        DateTime.now().toString().split(' ').first;
    final numberOfDays = data['numberOfDays'] as int? ?? 2;

    try {
      setState(() => _loadingMessage = 'Checking weather forecast...');
      WeatherModel? weather;
      try {
        weather = await _weatherService.getCurrentWeather(city);
      } catch (_) {}

      setState(() => _loadingMessage = 'Discovering local gems...');
      List<PlaceModel> knownPlaces = [];
      try {
        knownPlaces = await _placesService.searchTouristAttractions(city);
      } catch (_) {}

      setState(() =>
          _loadingMessage = 'Crafting your $numberOfDays-day experience...');
      final userId = context.read<AuthProvider>().user?.uid ?? 'anonymous';

      final itinerary = await _geminiService.generateMultiDayItinerary(
        userId: userId,
        city: city,
        startDate: startDate,
        endDate: endDate,
        numberOfDays: numberOfDays,
        dailyStartTime: startTime,
        dailyEndTime: endTime,
        interests: interests,
        travelMode: travelMode,
        pace: pace,
        weather: weather,
        knownPlaces: knownPlaces.take(20).toList(),
      );

      setState(() => _loadingMessage = 'Finalizing details...');
      await Future.delayed(const Duration(milliseconds: 500));

      _tabController = TabController(
        length: itinerary.days.length,
        vsync: this,
      );

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

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryChatSheet(
        multiDayItinerary: _itinerary,
        onMultiDayItineraryUpdated: (updated) {
          setState(() => _itinerary = updated);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _cityName,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.text),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
                child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.text),
              ),
            ),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: _itinerary != null
          ? FloatingActionButton.extended(
              onPressed: _openChat,
              backgroundColor: AppColors.brand,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text('Tweak Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Stack(
        children: [
          // ── Dynamic Full-Screen Background ──
          Positioned.fill(
            child: Image.network(
              _heroImage,
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

          SafeArea(
            bottom: false,
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _buildItinerary(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(AppTokens.xxl),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    Icons.explore,
                    size: 48,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: AppTokens.xl),
                Text(
                  _loadingMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: const EdgeInsets.all(AppTokens.lg),
            padding: const EdgeInsets.all(AppTokens.xl),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.8),
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.white),
                const SizedBox(height: AppTokens.md),
                Text(
                  'Failed to Curate Trip',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppTokens.sm),
                Text(
                  _error ?? 'Unknown error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
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
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItinerary() {
    final itinerary = _itinerary!;

    return FadeTransition(
      opacity: _animController,
      child: Column(
        children: [
          // ── Title Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.lg, AppTokens.xl, AppTokens.lg, AppTokens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${itinerary.numberOfDays}-Day Trip',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.text,
                        fontSize: 48,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: AppTokens.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.brandDeep,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${itinerary.startDate} — ${itinerary.endDate}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    if (itinerary.age != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.brand.withOpacity(0.3)),
                        ),
                        child: Text(
                          'AGE: ${itinerary.age}',
                          style: TextStyle(
                            color: AppColors.brandDeep,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    if (itinerary.travelers != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.brand.withOpacity(0.3)),
                        ),
                        child: Text(
                          'TRAVELERS: ${itinerary.travelers}',
                          style: TextStyle(
                            color: AppColors.brandDeep,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Trip Estimate Summary ──
          if (itinerary.budget != null || itinerary.estimatedTotalCost != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.lg, 0, AppTokens.lg, AppTokens.md),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(AppTokens.lg),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      border: Border.all(color: AppColors.borderGlass),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL TRIP ESTIMATE',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSoft,
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (itinerary.budget != null && itinerary.estimatedTotalCost != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: itinerary.remainingBudget != null && itinerary.remainingBudget! >= 0
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  itinerary.remainingBudget != null && itinerary.remainingBudget! >= 0
                                      ? '✓ Within Budget'
                                      : '⚠ Over Budget',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: itinerary.remainingBudget != null && itinerary.remainingBudget! >= 0
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.md),
                        Row(
                          children: [
                            if (itinerary.budget != null) ...[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Budget', style: TextStyle(fontSize: 12, color: AppColors.textSoft)),
                                    Text('₹${itinerary.budget}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                                  ],
                                ),
                              ),
                            ],
                            if (itinerary.estimatedTotalCost != null) ...[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Est. Cost', style: TextStyle(fontSize: 12, color: AppColors.textSoft)),
                                    Text('₹${itinerary.estimatedTotalCost}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.brand)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (itinerary.overallExpenseSummary != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: itinerary.overallExpenseSummary!.entries
                                .where((e) => e.key != 'total')
                                .map((e) => Text(
                                      '${e.key.toUpperCase()}: ₹${e.value}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSoft, fontWeight: FontWeight.w600),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Day Tabs ──
          if (_tabController != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: AppTokens.sm),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                boxShadow: AppTokens.shadow(level: 1),
              ),
              child: TabBar(
                isScrollable: true,
                controller: _tabController,
                labelColor: AppColors.brandDeep,
                unselectedLabelColor: AppColors.textSoft,
                indicatorPadding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                tabs: List.generate(itinerary.days.length, (i) {
                  return Tab(text: 'Day ${i + 1}');
                }),
              ),
            ),

          const SizedBox(height: AppTokens.sm),

          // ── Tab Content ──
          Expanded(
            child: _tabController != null
                ? TabBarView(
                    controller: _tabController,
                    children: itinerary.days.map((day) {
                      return _buildDayContent(day, itinerary);
                    }).toList(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayContent(
      ItineraryModel day, MultiDayItineraryModel overall) {
    return CustomScrollView(
      slivers: [
        // ── Day Summary ──
        if (day.aiSummary != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: AppTokens.md),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(AppTokens.xl),
                    decoration: BoxDecoration(
                      color: AppColors.glassWhiteLight,
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      border: Border.all(color: AppColors.borderGlass),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAY ${day.dayNumber} OVERVIEW',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSoft,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppTokens.sm),
                        Text(
                          day.aiSummary!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.text,
                            height: 1.6,
                          ),
                        ),
                        if (day.dayNumber == 1 && overall.weatherSummary != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppTokens.md),
                            child: Divider(color: AppColors.borderLight),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.wb_cloudy_outlined, size: 20, color: AppColors.textSoft),
                              const SizedBox(width: AppTokens.sm),
                              Expanded(
                                child: Text(
                                  overall.weatherSummary!,
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
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: AppTokens.lg)),

        // ── Schedule Header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
            child: Text(
              'Schedule',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.text),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppTokens.lg)),

        // ── Stops ──
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final stop = day.stops[index];
              final isLast = index == day.stops.length - 1;
              return _buildStopCard(stop, isLast, index);
            },
            childCount: day.stops.length,
          ),
        ),

        // ── Essentials (show on first tab only) ──
        if (day.dayNumber == 1 && overall.whatToCarry.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.lg, AppTokens.xxl, AppTokens.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Essentials',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.text)),
                  const SizedBox(height: AppTokens.md),
                  Container(
                    padding: const EdgeInsets.all(AppTokens.lg),
                    decoration: BoxDecoration(
                      color: AppColors.glassWhiteLight,
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      border: Border.all(color: AppColors.borderGlass),
                    ),
                    child: Column(
                      children: overall.whatToCarry.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•', style: TextStyle(color: AppColors.brand, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(width: AppTokens.sm),
                              Expanded(
                                child: Text(item, style: Theme.of(context).textTheme.bodyMedium),
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

        // ── Nearby Emergency Services (show on first tab only) ──
        if (day.dayNumber == 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.lg, 0, AppTokens.lg, 0),
              child: NearbyServicesSection(
                latitude: day.stops.isNotEmpty ? day.stops.first.latitude : null,
                longitude: day.stops.isNotEmpty ? day.stops.first.longitude : null,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: AppTokens.xxl)),

        // ── Save Button ──
        if (day.dayNumber == 1) // Only show on first tab to avoid clutter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_itinerary == null) return;
                    try {
                      final updatedItinerary = _itinerary!.copyWith(isSaved: true);
                      await FirebaseFirestore.instance
                          .collection(AppConstants.itinerariesCollection)
                          .doc(updatedItinerary.id)
                          .set(updatedItinerary.toFirestore());
                      if (context.mounted) {
                        setState(() {
                          _itinerary = updatedItinerary;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Multi-day trip securely saved to your itineraries!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save trip: $e')),
                        );
                      }
                    }
                  },
                  icon: Icon(_itinerary?.isSaved == true ? Icons.bookmark : Icons.bookmark_border),
                  label: const Text('Save Itinerary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.text, // Charcoal
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
                  ),
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildStopCard(ItineraryStop stop, bool isLast, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Timeline Column ──
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 3),
                      boxShadow: [
                        BoxShadow(color: AppColors.brand.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.sm),

            // ── Content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.xl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(AppTokens.lg),
                      decoration: BoxDecoration(
                        color: AppColors.glassWhite,
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${stop.startTime} — ${stop.endTime}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brand,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.sm),
                      Text(
                        stop.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: AppColors.text,
                            ),
                      ),
                      if (stop.description.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.xs),
                        Text(
                          stop.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSoft,
                                height: 1.5,
                              ),
                        ),
                      ],
                      if ((stop.travelMinutes != null && stop.travelMinutes! > 0) || (stop.estimatedCost != null && stop.estimatedCost! > 0) || stop.tips.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppTokens.md),
                          child: Divider(color: AppColors.borderLight),
                        ),

                      if ((stop.travelMinutes != null && stop.travelMinutes! > 0) || (stop.estimatedCost != null && stop.estimatedCost! > 0))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppTokens.sm),
                          child: Row(
                            children: [
                              if (stop.travelMinutes != null && stop.travelMinutes! > 0) ...[
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgElevated,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.directions, size: 14, color: AppColors.textSoft),
                                ),
                                const SizedBox(width: AppTokens.sm),
                                Text(
                                  '${stop.travelMinutes} min ${stop.travelMode ?? "travel"}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (stop.travelMinutes != null && stop.travelMinutes! > 0 && stop.estimatedCost != null && stop.estimatedCost! > 0)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text('•', style: TextStyle(color: AppColors.textSoft)),
                                ),
                              if (stop.estimatedCost != null && stop.estimatedCost! > 0) ...[
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.currency_rupee, size: 14, color: AppColors.brand),
                                ),
                                const SizedBox(width: AppTokens.sm),
                                Text(
                                  'Est. ₹${stop.estimatedCost}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (stop.tips.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppTokens.md),
                          decoration: BoxDecoration(
                            color: AppColors.glassWhiteLight,
                            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                            border: Border.all(color: AppColors.borderGlass),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: stop.tips.map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSoft,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
