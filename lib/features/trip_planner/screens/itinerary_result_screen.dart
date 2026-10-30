import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/food_preferences.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/models/travelers_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/models/place_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/image_resolver.dart';
import '../widgets/itinerary_chat_sheet.dart';
import '../widgets/nearby_services_section.dart';
import '../widgets/place_media_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
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
    if (data.containsKey('itinerary') && data['itinerary'] is ItineraryModel) {
      setState(() {
        _itinerary = data['itinerary'] as ItineraryModel;
        _cityName = _itinerary!.city;
        _heroImage = ImageResolver.getHeroImage(_cityName);
        _isLoading = false;
      });
      _animController.forward();
      return;
    }

    final city = data['city'] as String;
    final startTime = data['startTime'] as String;
    final endTime = data['endTime'] as String;
    final interests = List<String>.from(data['interests'] ?? []);
    final travelMode = data['travelMode'] as String? ?? 'driving';
    final pace = data['pace'] as String? ?? 'moderate';
    final date = data['date'] as String? ?? DateTime.now().toString().split(' ').first;
    final foodPreference = data['foodPreference'] as String? ?? 'all';
    final age = data['age'] as int?;
    final budget = data['budget'] as int?;
    final travelers = data['travelers'] as int?;
    final adults = data['adults'] as int? ?? travelers ?? 1;
    final minors = data['minors'] as int? ?? 0;
    final minorAgeBands = (data['minorAgeBands'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final travelersData = TravelersModel(
      adults: adults,
      minors: minors,
      minorAgeBands: minorAgeBands,
    );

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
        age: age,
        travelers: travelersData.totalCount,
        budget: budget,
        weather: weather,
        knownPlaces: knownPlaces.take(15).toList(),
        foodPreference: foodPreference,
        travelersData: travelersData,
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

  void _openChat() {
    if (_itinerary == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryChatSheet(
        itinerary: _itinerary,
        onItineraryUpdated: (updated) {
          setState(() => _itinerary = updated);
          Navigator.pop(context);
        },
      ),
    );
  }

  String _formatMapStop(ItineraryStop stop) {
    if (stop.latitude != null && stop.longitude != null) {
      return '${stop.latitude},${stop.longitude}';
    }
    return Uri.encodeComponent(stop.name.trim());
  }

  Future<void> _openRouteInGoogleMaps() async {
    final stops = _itinerary?.stops;
    if (stops == null || stops.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No stops available in this itinerary.')),
        );
      }
      return;
    }

    try {
      String urlStr;
      if (stops.length == 1) {
        final destination = _formatMapStop(stops.first);
        urlStr = 'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving';
      } else {
        final origin = _formatMapStop(stops.first);
        final destination = _formatMapStop(stops.last);
        var waypointsList = stops.sublist(1, stops.length - 1);
        if (waypointsList.length > 9) {
          waypointsList = waypointsList.sublist(0, 9);
        }

        urlStr = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination';
        if (waypointsList.isNotEmpty) {
          final waypoints = waypointsList.map(_formatMapStop).join('%7C');
          urlStr += '&waypoints=$waypoints';
        }
        urlStr += '&travelmode=driving';
      }

      final Uri url = Uri.parse(urlStr);
      bool launched = false;
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (!launched) {
        try {
          launched = await launchUrl(url, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }
      if (!launched) {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open route: $e')),
        );
      }
    }
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
              label: const Text('Tweak Itinerary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Stack(
        children: [
          // ── Clean Gradient Background ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.brandSoft,
                    AppColors.bg,
                  ],
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
      child: Container(
        padding: const EdgeInsets.all(AppTokens.xxl),
        margin: const EdgeInsets.all(AppTokens.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.brand,
                strokeWidth: 3,
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
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppTokens.lg),
        padding: const EdgeInsets.all(AppTokens.xl),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.9),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
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
              padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.xl, AppTokens.lg, AppTokens.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Itinerary',
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
                          '${itinerary.stops.length} STOPS',
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: itinerary.isFamilyFriendly
                              ? AppColors.brand.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: itinerary.isFamilyFriendly
                                ? AppColors.brand
                                : AppColors.brand.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (itinerary.isFamilyFriendly) ...[
                              const Icon(Icons.family_restroom_rounded,
                                  size: 13, color: AppColors.brand),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              itinerary.isFamilyFriendly
                                  ? itinerary.displayTravelersSummary.toUpperCase()
                                  : 'TRAVELERS: ${itinerary.adultsCount} ADULT${itinerary.adultsCount > 1 ? 'S' : ''}',
                              style: const TextStyle(
                                color: AppColors.brandDeep,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (itinerary.isFamilyFriendly) ...[
                    const SizedBox(height: AppTokens.md),
                    Container(
                      padding: const EdgeInsets.all(AppTokens.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
                        boxShadow: AppTokens.shadow(level: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.family_restroom_rounded,
                                size: 20, color: AppColors.brand),
                          ),
                          const SizedBox(width: AppTokens.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Family-Friendly Trip',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brandDeep,
                                  ),
                                ),
                                Text(
                                  'Planned for ${itinerary.displayTravelersSummary} with kid-friendly venues, safe pacing, and restful breaks.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSoft,
                                    height: 1.3,
                                  ),
                                ),
                              ],
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

          // ── Trip Estimate Summary ──
          if (itinerary.budget != null || itinerary.estimatedTotalCost != null)
            SliverToBoxAdapter(
              child: Padding(
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
                                'TRIP ESTIMATE',
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
                          if (itinerary.expenseSummary != null) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(),
                            ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: itinerary.expenseSummary!.entries
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
            ),

          // ── Summary Box ──
          if (itinerary.aiSummary != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.lg),
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
                            'OVERVIEW',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSoft,
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
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: AppTokens.lg)),

          // ── Timeline Header ──
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
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: AppTokens.md),
                    Container(
                      padding: const EdgeInsets.all(AppTokens.lg),
                      decoration: BoxDecoration(
                        color: AppColors.glassWhiteLight,
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                        border: Border.all(color: AppColors.borderGlass),
                      ),
                      child: Column(
                        children: itinerary.whatToCarry.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('•', style: TextStyle(color: AppColors.brand, fontSize: 18, fontWeight: FontWeight.bold)),
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

          // ── Nearby Safety (Hospitals & Police Stations) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.lg, 0, AppTokens.lg, 0),
              child: NearbyServicesSection(
                latitude: itinerary.stops.isNotEmpty ? itinerary.stops.first.latitude : null,
                longitude: itinerary.stops.isNotEmpty ? itinerary.stops.first.longitude : null,
                locationName: itinerary.city,
                initialServices: itinerary.nearbySafetyServices,
                isSavedMode: itinerary.isSaved,
                onServicesUpdated: (services) async {
                  setState(() {
                    _itinerary = _itinerary?.copyWith(nearbySafetyServices: services);
                  });
                  if (_itinerary != null && _itinerary!.isSaved) {
                    try {
                      await FirebaseFirestore.instance
                          .collection(AppConstants.itinerariesCollection)
                          .doc(_itinerary!.id)
                          .update({
                        'nearbySafetyServices': services.map((s) => s.toMap()).toList(),
                      });
                    } catch (_) {}
                  }
                },
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
                          const SnackBar(content: Text('Trip securely saved to your itineraries!')),
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

          const SliverToBoxAdapter(child: SizedBox(height: AppTokens.md)),

          // ── Open Route in Google Maps Button ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openRouteInGoogleMaps,
                  icon: const Icon(Icons.directions_car),
                  label: const Text('Open Route in Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
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

            // ── Editorial Content Card ──
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brandSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${stop.startTime} — ${stop.endTime}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brand,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (stop.isKidFriendly) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.child_care_rounded, size: 12, color: AppColors.brand),
                                      SizedBox(width: 3),
                                      Text(
                                        'Kid-Friendly',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.brandDeep,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              _buildDietaryBadge(stop),
                            ],
                          ),
                        ],
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
                      
                      const SizedBox(height: AppTokens.md),
                      PlaceMediaGallery(
                        placeName: stop.name,
                        cityName: _itinerary?.city,
                      ),

                      if ((stop.travelMinutes != null && stop.travelMinutes! > 0) || (stop.estimatedCost != null && stop.estimatedCost! > 0) || stop.tips.isNotEmpty || stop.isKidFriendly || stop.childTicketInfo != null)
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

                      if (stop.ageRangeRecommendation != null || stop.strollerAccess != null || stop.childTicketInfo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppTokens.sm),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (stop.ageRangeRecommendation != null && stop.ageRangeRecommendation!.isNotEmpty)
                                _buildFamilyInfoChip(
                                  icon: Icons.cake_outlined,
                                  label: 'Age: ${stop.ageRangeRecommendation}',
                                ),
                              if (stop.strollerAccess != null && stop.strollerAccess!.isNotEmpty)
                                _buildFamilyInfoChip(
                                  icon: Icons.stroller_outlined,
                                  label: stop.strollerAccess == 'yes'
                                      ? 'Stroller Friendly'
                                      : stop.strollerAccess == 'partial'
                                          ? 'Partial Stroller Access'
                                          : 'No Stroller Access',
                                ),
                              if (stop.childTicketInfo != null && stop.childTicketInfo!.isNotEmpty)
                                _buildFamilyInfoChip(
                                  icon: Icons.confirmation_number_outlined,
                                  label: stop.childTicketInfo!,
                                ),
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

  Widget _buildFamilyInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSoft),
          const SizedBox(width: 4),
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
    );
  }

  Widget _buildDietaryBadge(ItineraryStop stop) {
    final type = stop.dietaryType;
    final nameLower = stop.name.toLowerCase();
    final isFood = stop.type == 'food' ||
        nameLower.contains('restaurant') ||
        nameLower.contains('cafe') ||
        nameLower.contains('dhaba') ||
        nameLower.contains('bhojanalaya') ||
        nameLower.contains('sweets');

    if (type == null && !isFood) return const SizedBox.shrink();

    final effectiveType = type ?? DietaryFilterService.inferDietaryType('${stop.name} ${stop.description}');
    final label = FoodPreference.getLabel(effectiveType);
    final color = FoodPreference.getIndicatorColor(effectiveType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}


