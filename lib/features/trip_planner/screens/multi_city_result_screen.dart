import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/city_stay_model.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/models/multi_city_trip_model.dart';
import '../../../core/models/travel_leg_model.dart';
import '../../../core/models/transport_option_model.dart';
import '../../../core/models/travelers_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/transport_service.dart';
import '../../../core/utils/image_resolver.dart';
import '../widgets/travel_leg_card.dart';
import '../widgets/transport_options_sheet.dart';
import '../widgets/nearby_services_section.dart';

/// Screen displaying the complete, connected multi-city journey
class MultiCityResultScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const MultiCityResultScreen({super.key, this.tripData});

  @override
  State<MultiCityResultScreen> createState() => _MultiCityResultScreenState();
}

class _MultiCityResultScreenState extends State<MultiCityResultScreen>
    with SingleTickerProviderStateMixin {
  final GeminiService _geminiService = GeminiService();
  final TransportService _transportService = TransportService();

  MultiCityTripModel? _trip;
  bool _isLoading = true;
  String? _error;
  String _loadingMessage = 'Connecting your multi-city route...';
  double _loadingProgress = 0.0;
  bool _isSaved = false;
  bool _isSaving = false;

  // Active City view index (-1 means "Entire Route")
  int _selectedCityTab = -1;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _initializeOrGenerateTrip();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeOrGenerateTrip() async {
    if (widget.tripData == null) {
      setState(() {
        _error = 'No multi-city trip details provided.';
        _isLoading = false;
      });
      return;
    }

    final data = widget.tripData!;

    // Check if pre-existing saved trip model is passed
    if (data.containsKey('trip') && data['trip'] is MultiCityTripModel) {
      setState(() {
        _trip = data['trip'] as MultiCityTripModel;
        _isLoading = false;
        _isSaved = true;
      });
      _animController.forward();
      return;
    }

    try {
      final user = context.read<AuthProvider>().user;
      final userId = user?.uid ?? 'guest_traveler';

      // Parse cities
      final rawCities = (data['cities'] as List? ?? [])
          .map((c) => c is CityStayModel
              ? c
              : CityStayModel.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList();

      if (rawCities.length < 2) {
        throw Exception('At least 2 cities are required for a multi-city trip.');
      }

      final isRoundTrip = data['isRoundTrip'] as bool? ?? false;
      final startDate = data['startDate'] != null
          ? DateTime.tryParse(data['startDate'].toString()) ?? DateTime.now()
          : DateTime.now();
      final endDate = data['endDate'] != null
          ? DateTime.tryParse(data['endDate'].toString()) ?? DateTime.now().add(const Duration(days: 4))
          : DateTime.now().add(const Duration(days: 4));

      final interests = List<String>.from(data['interests'] ?? ['Famous Places', 'Local Food']);
      final travelMode = data['travelMode'] as String? ?? 'driving';
      final pace = data['pace'] as String? ?? 'moderate';
      final foodPreference = data['foodPreference'] as String? ?? 'all';
      final budget = (data['budget'] as num?)?.toInt();

      final travelersData = data['travelers'] is Map<String, dynamic>
          ? TravelersModel.fromMap(data['travelers'] as Map<String, dynamic>)
          : (data['travelers'] is TravelersModel
              ? data['travelers'] as TravelersModel
              : const TravelersModel(adults: 1, minors: 0));

      setState(() {
        _loadingMessage = 'Calculating routes and inter-city transit...';
        _loadingProgress = 0.15;
      });

      // 1. Generate travel legs between consecutive cities
      final legs = _transportService.generateLegsForCircuit(
        cities: rawCities,
        isRoundTrip: isRoundTrip,
        travelers: travelersData,
      );

      // 2. Generate multi-city itinerary days via AI
      final generatedTrip = await _geminiService.generateMultiCityItinerary(
        userId: userId,
        cities: rawCities,
        legs: legs,
        startDate: startDate,
        endDate: endDate,
        interests: interests,
        travelMode: travelMode,
        pace: pace,
        travelers: travelersData,
        foodPreference: foodPreference,
        isRoundTrip: isRoundTrip,
        budget: budget,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _loadingMessage = status;
              _loadingProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _trip = generatedTrip;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to craft multi-city journey: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openTransportSheet(int legIndex) {
    if (_trip == null || legIndex >= _trip!.legs.length) return;
    final leg = _trip!.legs[legIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransportOptionsSheet(
        leg: leg,
        onOptionSelected: (newOption) {
          final updatedLegs = List<TravelLegModel>.from(_trip!.legs);
          updatedLegs[legIndex] = leg.copyWith(selectedOption: newOption);
          setState(() {
            _trip = _trip!.copyWith(
              legs: updatedLegs,
              estimatedTravelCost: updatedLegs.fold<int>(
                0,
                (sum, l) => sum + l.selectedOption.estimatedTotalCost,
              ),
            );
          });
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  Future<void> _refreshTravelInfo() async {
    if (_trip == null) return;
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing inter-city fares & timings...'),
        duration: Duration(seconds: 1),
      ),
    );

    final refreshedLegs = _transportService.generateLegsForCircuit(
      cities: _trip!.cities,
      isRoundTrip: _trip!.isRoundTrip,
      travelers: _trip!.travelers,
    );

    setState(() {
      _trip = _trip!.copyWith(
        legs: refreshedLegs,
        updatedAt: DateTime.now(),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Updated ${refreshedLegs.length} travel legs. Total travel: ₹${_trip!.estimatedTravelCost}',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _saveTrip() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save your trip.')),
      );
      return;
    }

    if (_trip == null) return;
    setState(() => _isSaving = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection(AppConstants.itinerariesCollection)
          .doc(_trip!.id);

      final payload = _trip!.toMap();
      payload['isSaved'] = true;
      payload['userId'] = user.uid;
      payload['tripType'] = 'multi_city';

      await docRef.set(payload, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Multi-city trip saved to My Trips!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save trip: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _shareTrip() {
    if (_trip == null) return;
    final summary =
        'Ghumify Multi-City Trip: ${_trip!.routeSummary}\n'
        'Duration: ${_trip!.totalDays} Days\n'
        'Cities: ${_trip!.cities.map((c) => c.name).join(', ')}\n'
        'Travel legs: ${_trip!.legs.length}\n'
        'Estimated Transit Cost: ₹${_trip!.estimatedTravelCost}\n'
        'Planned with Ghumify';

    Clipboard.setData(ClipboardData(text: summary));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip summary copied to clipboard!'),
        backgroundColor: AppColors.brandDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null || _trip == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildRouteOverview()),
          SliverToBoxAdapter(child: _buildCityTabBar()),
          SliverToBoxAdapter(child: _buildCostSummaryCard()),
          ..._buildTimelineSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomSheet: _buildBottomActionBar(),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SLIVER APP BAR
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildSliverAppBar() {
    final firstCity = _trip!.cities.first;
    final heroImg = ImageResolver.getHeroImage(firstCity.name);

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.brandDeep,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh travel info',
          onPressed: _refreshTravelInfo,
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded, color: Colors.white),
          tooltip: 'Share itinerary',
          onPressed: _shareTrip,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: 14),
        title: Text(
          _trip!.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              heroImg,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppColors.brandDeep),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    AppColors.brandDeep.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 48,
              left: AppTokens.lg,
              right: AppTokens.lg,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    child: const Text(
                      'MULTI-CITY EXPEDITION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_trip!.isRoundTrip)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.loop_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Circuit',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ROUTE OVERVIEW BANNER
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildRouteOverview() {
    return Container(
      margin: const EdgeInsets.all(AppTokens.md),
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTokens.shadow(level: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatChip(
                icon: Icons.location_city_rounded,
                label: '${_trip!.cities.length} Cities',
                color: AppColors.brand,
              ),
              _buildStatChip(
                icon: Icons.calendar_today_rounded,
                label: '${_trip!.totalDays} Days',
                color: AppColors.accent,
              ),
              _buildStatChip(
                icon: Icons.route_rounded,
                label: '${_trip!.totalDistanceKm.toStringAsFixed(0)} km',
                color: const Color(0xFF6366F1),
              ),
              _buildStatChip(
                icon: Icons.currency_rupee_rounded,
                label: '₹${_trip!.estimatedTravelCost}',
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.lg),

          // Route visualization line
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_trip!.cities.length, (i) {
                final city = _trip!.cities[i];
                final isLast = i == _trip!.cities.length - 1;
                final leg = i < _trip!.legs.length ? _trip!.legs[i] : null;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // City Node
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: i == 0
                              ? AppColors.brandDeep
                              : isLast
                                  ? AppColors.accent
                                  : AppColors.brand,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          city.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          '${city.stayDays}d',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Inter-city connector
                    if (!isLast && leg != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 2,
                                  color: AppColors.border,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.bg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Icon(
                                    leg.selectedOption.modeIcon,
                                    size: 13,
                                    color: AppColors.brand,
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 2,
                                  color: AppColors.border,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${leg.distanceKm.toStringAsFixed(0)}km',
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CITY TAB BAR / SWITCHER
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildCityTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTokens.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "All Route" Pill
            _buildTabPill(
              title: 'Entire Route',
              isSelected: _selectedCityTab == -1,
              onTap: () => setState(() => _selectedCityTab = -1),
            ),
            const SizedBox(width: 8),

            // Individual City Pills
            ...List.generate(_trip!.cities.length, (index) {
              final city = _trip!.cities[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildTabPill(
                  title: city.name,
                  badge: '${city.stayDays}d',
                  isSelected: _selectedCityTab == index,
                  onTap: () => setState(() => _selectedCityTab = index),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required String title,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandDeep : Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: isSelected ? AppColors.brandDeep : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.brandDeep.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.brand,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // COST SUMMARY CARD
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildCostSummaryCard() {
    final travelers = _trip!.travelers;
    final totalTransit = _trip!.estimatedTravelCost;
    final perPerson = travelers.totalCount > 0
        ? (totalTransit / travelers.totalCount).round()
        : totalTransit;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppTokens.md, AppTokens.md, AppTokens.md, 0),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.brandDeep),
                  SizedBox(width: 6),
                  Text(
                    'Inter-City Travel Cost',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: const Text(
                  'Estimated',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Group Total (${travelers.summary}):',
                style: const TextStyle(fontSize: 13, color: AppColors.textSoft),
              ),
              Text(
                '₹$totalTransit',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          if (travelers.totalCount > 1) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Avg. per traveler:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSoft),
                ),
                Text(
                  '₹$perPerson',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TIMELINE SLIVERS
  // ═════════════════════════════════════════════════════════════════════════
  List<Widget> _buildTimelineSlivers() {
    final List<Widget> slivers = [];

    // Filter cities based on selected tab
    final citiesToRender = _selectedCityTab == -1
        ? _trip!.cities
        : [_trip!.cities[_selectedCityTab]];

    for (int idx = 0; idx < citiesToRender.length; idx++) {
      final city = citiesToRender[idx];
      final actualIndex = _selectedCityTab == -1 ? idx : _selectedCityTab;

      // 1. If Entire Route and not first city, render the incoming TravelLegCard
      if (_selectedCityTab == -1 && actualIndex > 0 && actualIndex - 1 < _trip!.legs.length) {
        final leg = _trip!.legs[actualIndex - 1];
        slivers.add(
          SliverToBoxAdapter(
            child: TravelLegCard(
              leg: leg,
              onTapChangeOption: () => _openTransportSheet(actualIndex - 1),
            ),
          ),
        );
      }

      // 2. City Destination Header
      slivers.add(
        SliverToBoxAdapter(
          child: _buildCitySectionHeader(city, actualIndex),
        ),
      );

      // 3. Days belonging to this city
      final cityDays = _trip!.days
          .where((d) => d.city.toLowerCase() == city.name.toLowerCase())
          .toList();

      for (final day in cityDays) {
        slivers.add(
          SliverToBoxAdapter(
            child: _buildDayHeader(day),
          ),
        );

        slivers.add(
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, stopIndex) {
                final stop = day.stops[stopIndex];
                final isLast = stopIndex == day.stops.length - 1;
                return _buildStopItem(stop, isLast);
              },
              childCount: day.stops.length,
            ),
          ),
        );
      }

      // 4. Lazy Nearby Safety Section for this city
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: AppTokens.md),
            child: NearbyServicesSection(
              latitude: city.latitude,
              longitude: city.longitude,
              locationName: city.name,
              canRefresh: true,
              isSavedMode: _isSaved,
            ),
          ),
        ),
      );
    }

    // 5. If Round Trip return leg in Entire Route view
    if (_selectedCityTab == -1 &&
        _trip!.isRoundTrip &&
        _trip!.legs.length == _trip!.cities.length) {
      final returnLeg = _trip!.legs.last;
      slivers.add(
        SliverToBoxAdapter(
          child: TravelLegCard(
            leg: returnLeg,
            onTapChangeOption: () => _openTransportSheet(_trip!.legs.length - 1),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildCitySectionHeader(CityStayModel city, int index) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTokens.md, AppTokens.lg, AppTokens.md, AppTokens.sm),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: Image.asset(
              city.heroImage,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 52,
                height: 52,
                color: AppColors.brandSoft,
                child: const Icon(Icons.location_city, color: AppColors.brand),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brandDeep,
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      ),
                      child: Text(
                        'CITY ${index + 1}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${city.stayDays} ${city.stayDays == 1 ? "Day" : "Days"} Stay',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  city.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${city.arrivalDate} to ${city.departureDate}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(ItineraryModel day) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTokens.md, AppTokens.md, AppTokens.md, 4),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Day ${day.dayNumber} · ${day.city}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.brandDeep,
            ),
          ),
          Text(
            day.date,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopItem(ItineraryStop stop, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: AppColors.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.sm),

            // Stop content card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: AppTokens.md),
                padding: const EdgeInsets.all(AppTokens.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppTokens.shadow(level: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                          ),
                          child: Text(
                            '${stop.startTime} - ${stop.endTime}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandDeep,
                            ),
                          ),
                        ),
                        if (stop.isKidFriendly == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                            ),
                            child: const Text(
                              'Child-Friendly',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stop.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSoft,
                        height: 1.4,
                      ),
                    ),
                    if (stop.tips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: stop.tips.map((tip) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                            ),
                            child: Text(
                              '💡 $tip',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSoft,
                              ),
                            ),
                          );
                        }).toList(),
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

  // ═════════════════════════════════════════════════════════════════════════
  // BOTTOM ACTION BAR
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.only(
        left: AppTokens.lg,
        right: AppTokens.lg,
        top: AppTokens.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppTokens.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppTokens.shadow(level: 3),
      ),
      child: Row(
        children: [
          // Save / Saved Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving || _isSaved ? null : _saveTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? AppColors.success : AppColors.brandDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded),
              label: Text(
                _isSaved ? 'Trip Saved' : 'Save Multi-City Trip',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // LOADING STATE
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.hub_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(height: AppTokens.xl),
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppTokens.md),
              SizedBox(
                width: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.sm),
              const Text(
                'Connecting cities, transit options & local safety',
                style: TextStyle(fontSize: 12, color: AppColors.textSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ERROR STATE
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Multi-City Expedition'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.error),
              const SizedBox(height: AppTokens.md),
              Text(
                _error ?? 'An unexpected error occurred.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppTokens.lg),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _initializeOrGenerateTrip();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry Route Planning'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
