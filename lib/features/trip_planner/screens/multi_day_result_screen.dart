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
import '../../../core/models/multi_day_itinerary_model.dart';
import '../../../core/models/travelers_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/models/place_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/image_resolver.dart';
import '../widgets/itinerary_chat_sheet.dart';
import '../widgets/nearby_services_section.dart';
import '../widgets/meal_suggestion_card.dart';
import '../widgets/itinerary_stop_card.dart';
import '../../../core/constants/meal_config.dart';
import '../../../core/models/meal_suggestion_model.dart';
import '../../../core/services/restaurant_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/route_proximity_optimizer.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final RestaurantService _restaurantService = RestaurantService();
  final LocationService _locationService = LocationService();

  MultiDayItineraryModel? _itinerary;
  bool _isLoading = true;
  String? _error;
  String _loadingMessage = 'Planning your adventure...';
  late AnimationController _animController;
  TabController? _tabController;
  late String _heroImage;
  late String _cityName;
  int? _expandedStopIndex;
  final Map<int, List<ItineraryStop>> _previousDayStopsBeforeReorder = {};

  // Lazy Day Meal Suggestions state (keyed by dayNumber)
  final Map<int, List<MealSuggestionModel>> _dayLunchSuggestions = {};
  final Map<int, List<MealSuggestionModel>> _dayDinnerSuggestions = {};
  final Map<int, bool> _dayIsLoadingLunch = {};
  final Map<int, bool> _dayIsLoadingDinner = {};
  final Map<int, String?> _dayLunchError = {};
  final Map<int, String?> _dayDinnerError = {};
  final Map<int, String?> _dayLunchAnchor = {};
  final Map<int, String?> _dayDinnerAnchor = {};
  final Map<int, DateTime?> _dayLastUpdated = {};
  final Map<int, String?> _dayAddedLunch = {};
  final Map<int, String?> _dayAddedDinner = {};
  final Set<int> _initializedDays = {};

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
        age: age,
        travelers: travelersData.totalCount,
        budget: budget,
        weather: weather,
        knownPlaces: knownPlaces.take(20).toList(),
        foodPreference: foodPreference,
        travelersData: travelersData,
      );

      setState(() => _loadingMessage = 'Optimizing routes by proximity...');
      final startPoint = await _locationService.resolveStartPoint(
        city: city,
        userPickedLat: data['startLatitude'] as double?,
        userPickedLng: data['startLongitude'] as double?,
        userPickedLabel: data['startPointLabel'] as String?,
        hotelLat: data['hotelLatitude'] as double?,
        hotelLng: data['hotelLongitude'] as double?,
        hotelLabel: data['hotelName'] as String?,
      );

      final optimizedDays = <ItineraryModel>[];
      for (final day in itinerary.days) {
        final optResult = RouteProximityOptimizer.optimizeStopsProximity(
          stops: day.stops,
          startLat: startPoint.latitude,
          startLng: startPoint.longitude,
          startPointLabel: startPoint.label,
          travelMode: travelMode,
          pace: pace,
          travelers: travelersData,
          dayStartTime: startTime,
          dayEndTime: endTime,
        );
        optimizedDays.add(day.copyWith(
          stops: optResult.orderedStops,
          routeStartPointInfo: optResult.startPointMessage,
        ));
      }

      final optimizedItinerary = itinerary.copyWith(days: optimizedDays);

      setState(() => _loadingMessage = 'Finalizing details...');
      await Future.delayed(const Duration(milliseconds: 300));

      _tabController = TabController(
        length: optimizedItinerary.days.length,
        vsync: this,
      );

      setState(() {
        _itinerary = optimizedItinerary;
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

  void _initDayMealSuggestions(ItineraryModel day) {
    final dayNum = day.dayNumber;
    if (_initializedDays.contains(dayNum)) return;
    _initializedDays.add(dayNum);

    for (final stop in day.stops) {
      if (stop.type == 'food') {
        if (MealConfig.isWithinLunchWindow(stop.startTime)) {
          _dayAddedLunch[dayNum] = stop.name;
        } else if (MealConfig.isWithinDinnerWindow(stop.startTime)) {
          _dayAddedDinner[dayNum] = stop.name;
        }
      }
    }

    if (day.mealSuggestions != null && day.mealSuggestions!.isNotEmpty) {
      final ms = day.mealSuggestions!;
      setState(() {
        _dayLunchSuggestions[dayNum] = ms.lunchSuggestions;
        _dayDinnerSuggestions[dayNum] = ms.dinnerSuggestions;
        _dayLunchAnchor[dayNum] = ms.lunchAnchorName;
        _dayDinnerAnchor[dayNum] = ms.dinnerAnchorName;
        _dayLastUpdated[dayNum] = ms.lastUpdated;
      });
    } else {
      _fetchDayMealSuggestions(dayNum, day);
    }
  }

  Future<void> _fetchDayMealSuggestions(
    int dayNumber,
    ItineraryModel day, {
    bool force = false,
    String? mealType,
  }) async {
    final fetchLunch = mealType == null || mealType == MealConfig.lunch;
    final fetchDinner = mealType == null || mealType == MealConfig.dinner;

    if (fetchLunch) {
      setState(() {
        _dayIsLoadingLunch[dayNumber] = true;
        _dayLunchError[dayNumber] = null;
      });
    }
    if (fetchDinner) {
      setState(() {
        _dayIsLoadingDinner[dayNumber] = true;
        _dayDinnerError[dayNumber] = null;
      });
    }

    // 1. Fetch Lunch
    if (fetchLunch) {
      try {
        final lunchAnchor = RestaurantService.findMealAnchorPoint(
          stops: day.stops,
          mealType: MealConfig.lunch,
        );

        if (lunchAnchor != null) {
          _dayLunchAnchor[dayNumber] = lunchAnchor.name;
          final results = await _restaurantService.getMealSuggestions(
            latitude: lunchAnchor.latitude,
            longitude: lunchAnchor.longitude,
            mealType: MealConfig.lunch,
            foodPreference: day.foodPreference,
            travelers: day.travelersModel,
            anchorStopName: lunchAnchor.name,
            forceRefresh: force,
          );
          if (mounted) {
            setState(() {
              _dayLunchSuggestions[dayNumber] = results;
              _dayIsLoadingLunch[dayNumber] = false;
              _dayLastUpdated[dayNumber] = DateTime.now();
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _dayIsLoadingLunch[dayNumber] = false;
              _dayLunchError[dayNumber] = 'No stops with coordinates found for lunch.';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _dayIsLoadingLunch[dayNumber] = false;
            _dayLunchError[dayNumber] = 'Could not load lunch suggestions: $e';
          });
        }
      }
    }

    // 2. Fetch Dinner
    if (fetchDinner) {
      try {
        final dinnerAnchor = RestaurantService.findMealAnchorPoint(
          stops: day.stops,
          mealType: MealConfig.dinner,
        );

        if (dinnerAnchor != null) {
          _dayDinnerAnchor[dayNumber] = dinnerAnchor.name;
          final results = await _restaurantService.getMealSuggestions(
            latitude: dinnerAnchor.latitude,
            longitude: dinnerAnchor.longitude,
            mealType: MealConfig.dinner,
            foodPreference: day.foodPreference,
            travelers: day.travelersModel,
            anchorStopName: dinnerAnchor.name,
            forceRefresh: force,
          );
          if (mounted) {
            setState(() {
              _dayDinnerSuggestions[dayNumber] = results;
              _dayIsLoadingDinner[dayNumber] = false;
              _dayLastUpdated[dayNumber] = DateTime.now();
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _dayIsLoadingDinner[dayNumber] = false;
              _dayDinnerError[dayNumber] = 'No stops with coordinates found for dinner.';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _dayIsLoadingDinner[dayNumber] = false;
            _dayDinnerError[dayNumber] = 'Could not load dinner suggestions: $e';
          });
        }
      }
    }

    // Update container in day model and overall itinerary
    if (mounted && _itinerary != null) {
      final updatedSuggestions = DayMealSuggestions(
        lunchSuggestions: _dayLunchSuggestions[dayNumber] ?? [],
        dinnerSuggestions: _dayDinnerSuggestions[dayNumber] ?? [],
        lunchAnchorName: _dayLunchAnchor[dayNumber],
        dinnerAnchorName: _dayDinnerAnchor[dayNumber],
        lastUpdated: DateTime.now(),
      );

      final updatedDays = _itinerary!.days.map((d) {
        if (d.dayNumber == dayNumber) {
          return d.copyWith(mealSuggestions: updatedSuggestions);
        }
        return d;
      }).toList();

      setState(() {
        _itinerary = _itinerary!.copyWith(days: updatedDays);
      });
      _syncMultiDayItineraryIfSaved();
    }
  }

  void _onAddMealToDayItinerary(
    int dayNumber,
    MealSuggestionModel restaurant,
    String mealType,
  ) {
    if (_itinerary == null) return;
    final dayIdx = _itinerary!.days.indexWhere((d) => d.dayNumber == dayNumber);
    if (dayIdx == -1) return;

    final targetDay = _itinerary!.days[dayIdx];
    final isLunch = mealType == MealConfig.lunch;
    final hasMinors = targetDay.isFamilyFriendly;
    final targetStartTime = isLunch
        ? MealConfig.lunchDefaultTime
        : (hasMinors ? MealConfig.dinnerEarlyDefaultTime : MealConfig.dinnerDefaultTime);
    final duration = isLunch
        ? MealConfig.lunchDefaultDurationMinutes
        : MealConfig.dinnerDefaultDurationMinutes;
    final targetEndTime = MealConfig.minutesToTime(
        MealConfig.timeToMinutes(targetStartTime) + duration);

    final newMealStop = ItineraryStop(
      name: restaurant.name,
      type: 'food',
      startTime: targetStartTime,
      endTime: targetEndTime,
      durationMinutes: duration,
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
      dietaryType: restaurant.dietaryType,
      description: '${restaurant.cuisine} • ${restaurant.suggestedReason}',
      tips: [
        if (restaurant.openingHours != null) 'Hours: ${restaurant.openingHours}',
        'Please check opening hours and menu before visiting.',
        if (targetDay.foodPreference == FoodPreference.jain)
          'Please confirm Jain preparation with the restaurant.',
      ],
      isKidFriendly: restaurant.isKidFriendly,
    );

    final currentStops = List<ItineraryStop>.from(targetDay.stops);
    int existingIdx = -1;
    for (int i = 0; i < currentStops.length; i++) {
      final s = currentStops[i];
      final inWindow = isLunch
          ? MealConfig.isWithinLunchWindow(s.startTime)
          : MealConfig.isWithinDinnerWindow(s.startTime);
      if (inWindow &&
          (s.type == 'food' ||
              s.name == restaurant.name ||
              (isLunch && s.name == _dayAddedLunch[dayNumber]) ||
              (!isLunch && s.name == _dayAddedDinner[dayNumber]))) {
        existingIdx = i;
        break;
      }
    }

    if (existingIdx >= 0) {
      currentStops[existingIdx] = newMealStop;
    } else {
      final targetMins = MealConfig.timeToMinutes(targetStartTime);
      int insertIdx = currentStops.length;
      for (int i = 0; i < currentStops.length; i++) {
        if (MealConfig.timeToMinutes(currentStops[i].startTime) > targetMins) {
          insertIdx = i;
          break;
        }
      }
      currentStops.insert(insertIdx, newMealStop);
    }

    final updatedDays = List<ItineraryModel>.from(_itinerary!.days);
    updatedDays[dayIdx] = targetDay.copyWith(stops: currentStops);

    setState(() {
      if (isLunch) {
        _dayAddedLunch[dayNumber] = restaurant.name;
      } else {
        _dayAddedDinner[dayNumber] = restaurant.name;
      }
      _itinerary = _itinerary!.copyWith(days: updatedDays);
    });

    _syncMultiDayItineraryIfSaved();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${restaurant.name}" to Day $dayNumber!'),
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () => _onRemoveMealFromDayItinerary(dayNumber, mealType),
        ),
      ),
    );
  }

  void _onRemoveMealFromDayItinerary(int dayNumber, String mealType) {
    if (_itinerary == null) return;
    final dayIdx = _itinerary!.days.indexWhere((d) => d.dayNumber == dayNumber);
    if (dayIdx == -1) return;

    final targetDay = _itinerary!.days[dayIdx];
    final isLunch = mealType == MealConfig.lunch;
    final targetName = isLunch ? _dayAddedLunch[dayNumber] : _dayAddedDinner[dayNumber];
    if (targetName == null) return;

    final currentStops = List<ItineraryStop>.from(targetDay.stops);
    currentStops.removeWhere((s) =>
        s.name == targetName ||
        (s.type == 'food' &&
            (isLunch
                ? MealConfig.isWithinLunchWindow(s.startTime)
                : MealConfig.isWithinDinnerWindow(s.startTime))));

    final updatedDays = List<ItineraryModel>.from(_itinerary!.days);
    updatedDays[dayIdx] = targetDay.copyWith(stops: currentStops);

    setState(() {
      if (isLunch) {
        _dayAddedLunch[dayNumber] = null;
      } else {
        _dayAddedDinner[dayNumber] = null;
      }
      _itinerary = _itinerary!.copyWith(days: updatedDays);
    });

    _syncMultiDayItineraryIfSaved();
  }

  Future<void> _syncMultiDayItineraryIfSaved() async {
    if (_itinerary != null && _itinerary!.isSaved) {
      try {
        await FirebaseFirestore.instance
            .collection(AppConstants.itinerariesCollection)
            .doc(_itinerary!.id)
            .set(_itinerary!.toFirestore(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Widget _buildDayLunchCard(ItineraryModel day) {
    final dayNum = day.dayNumber;
    return MealSuggestionCard(
      mealType: MealConfig.lunch,
      anchorStopName: _dayLunchAnchor[dayNum],
      suggestions: _dayLunchSuggestions[dayNum] ?? [],
      isLoading: _dayIsLoadingLunch[dayNum] == true,
      errorMessage: _dayLunchError[dayNum],
      foodPreference: day.foodPreference,
      isSavedMode: _itinerary?.isSaved == true,
      lastUpdated: _dayLastUpdated[dayNum],
      isAddedToItinerary: _dayAddedLunch[dayNum] != null,
      addedRestaurantName: _dayAddedLunch[dayNum],
      onRefresh: () => _fetchDayMealSuggestions(dayNum, day, force: true, mealType: MealConfig.lunch),
      onAddToItinerary: (restaurant) => _onAddMealToDayItinerary(dayNum, restaurant, MealConfig.lunch),
      onRemoveFromItinerary: () => _onRemoveMealFromDayItinerary(dayNum, MealConfig.lunch),
    );
  }

  Widget _buildDayDinnerCard(ItineraryModel day) {
    final dayNum = day.dayNumber;
    return MealSuggestionCard(
      mealType: MealConfig.dinner,
      anchorStopName: _dayDinnerAnchor[dayNum],
      suggestions: _dayDinnerSuggestions[dayNum] ?? [],
      isLoading: _dayIsLoadingDinner[dayNum] == true,
      errorMessage: _dayDinnerError[dayNum],
      foodPreference: day.foodPreference,
      isSavedMode: _itinerary?.isSaved == true,
      lastUpdated: _dayLastUpdated[dayNum],
      isAddedToItinerary: _dayAddedDinner[dayNum] != null,
      addedRestaurantName: _dayAddedDinner[dayNum],
      onRefresh: () => _fetchDayMealSuggestions(dayNum, day, force: true, mealType: MealConfig.dinner),
      onAddToItinerary: (restaurant) => _onAddMealToDayItinerary(dayNum, restaurant, MealConfig.dinner),
      onRemoveFromItinerary: () => _onRemoveMealFromDayItinerary(dayNum, MealConfig.dinner),
    );
  }

  List<Widget> _buildDayTimelineWidgets(ItineraryModel day, MultiDayItineraryModel overall) {
    final widgets = <Widget>[];

    // Add route starting point info and reorder button at top
    widgets.add(_buildDayRouteStartBanner(day));

    final stops = day.stops;

    int lunchInsertIndex = -1;
    int dinnerInsertIndex = -1;

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final startMins = MealConfig.timeToMinutes(stop.startTime);
      final isLunchTime = startMins >= MealConfig.timeToMinutes(MealConfig.lunchStartTime);
      final isDinnerTime = startMins >= MealConfig.timeToMinutes(MealConfig.dinnerStartTime);

      if (lunchInsertIndex == -1 && isLunchTime) {
        lunchInsertIndex = i;
      }
      if (dinnerInsertIndex == -1 && isDinnerTime) {
        dinnerInsertIndex = i;
      }
    }

    if (lunchInsertIndex == -1) {
      lunchInsertIndex = (stops.length / 2).floor();
    }
    if (dinnerInsertIndex == -1) {
      dinnerInsertIndex = stops.length;
    }

    bool lunchInserted = false;
    bool dinnerInserted = false;

    for (int i = 0; i < stops.length; i++) {
      if (i == lunchInsertIndex && !lunchInserted) {
        widgets.add(_buildDayLunchCard(day));
        lunchInserted = true;
      }
      if (i == dinnerInsertIndex && !dinnerInserted) {
        widgets.add(_buildDayDinnerCard(day));
        dinnerInserted = true;
      }

      final isLast = (i == stops.length - 1) && lunchInserted && dinnerInserted;
      widgets.add(_buildStopCard(stops[i], isLast, i, day));
    }

    if (!lunchInserted) {
      widgets.add(_buildDayLunchCard(day));
      lunchInserted = true;
    }
    if (!dinnerInserted) {
      widgets.add(_buildDayDinnerCard(day));
      dinnerInserted = true;
    }

    return widgets;
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
    _initDayMealSuggestions(day);
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

        // ── Timeline with Stops & Meal Suggestions ──
        Builder(
          builder: (context) {
            final timelineWidgets = _buildDayTimelineWidgets(day, overall);
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => timelineWidgets[index],
                childCount: timelineWidgets.length,
              ),
            );
          },
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

        // ── Nearby Safety (Hospitals & Police Stations) ──
        if (day.dayNumber == 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.lg, 0, AppTokens.lg, 0),
              child: NearbyServicesSection(
                latitude: day.stops.isNotEmpty ? day.stops.first.latitude : null,
                longitude: day.stops.isNotEmpty ? day.stops.first.longitude : null,
                locationName: _itinerary?.city,
                initialServices: _itinerary?.nearbySafetyServices,
                isSavedMode: _itinerary?.isSaved ?? false,
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

  Widget _buildStopCard(ItineraryStop stop, bool isLast, int index, [ItineraryModel? day]) {
    return ItineraryStopCard(
      index: index,
      stop: stop,
      isLast: isLast,
      isExpanded: _expandedStopIndex == index,
      cityName: day?.city ?? _itinerary?.city,
      onToggleExpand: () {
        setState(() {
          _expandedStopIndex = (_expandedStopIndex == index) ? null : index;
        });
      },
      onPinToggle: day != null ? () => _togglePinStop(day, index) : null,
    );
  }

  /// Day route starting point banner with "Re-order by nearest" button
  Widget _buildDayRouteStartBanner(ItineraryModel day) {
    final startMsg = day.routeStartPointInfo ?? 'Route starts from ${day.city} center';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.navigation_rounded, size: 14, color: AppColors.brand),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      startMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.alt_route_rounded, size: 14),
              label: Text(
                'Re-order',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.brand,
              ),
              onPressed: () => _reorderByNearest(day),
            ),
          ],
        ),
      ),
    );
  }

  /// Reorder day stops by nearest
  Future<void> _reorderByNearest(ItineraryModel day) async {
    if (_itinerary == null || day.stops.isEmpty) return;

    final startPoint = await _locationService.resolveStartPoint(
      city: day.city,
    );

    final optResult = RouteProximityOptimizer.optimizeStopsProximity(
      stops: day.stops,
      startLat: startPoint.latitude,
      startLng: startPoint.longitude,
      startPointLabel: startPoint.label,
      travelMode: day.travelMode,
      pace: day.pace,
      travelers: day.travelersModel,
      dayStartTime: day.startTime,
      dayEndTime: day.endTime,
    );

    final dayIdx = _itinerary!.days.indexWhere((d) => d.dayNumber == day.dayNumber);
    if (dayIdx == -1) return;

    _previousDayStopsBeforeReorder[day.dayNumber] = List<ItineraryStop>.from(day.stops);

    final updatedDays = List<ItineraryModel>.from(_itinerary!.days);
    updatedDays[dayIdx] = day.copyWith(
      stops: optResult.orderedStops,
      routeStartPointInfo: optResult.startPointMessage,
      isManuallyOrdered: false,
    );

    setState(() {
      _itinerary = _itinerary!.copyWith(days: updatedDays);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Day ${day.dayNumber}: Re-ordered by nearest (${optResult.startPointMessage})',
            style: GoogleFonts.outfit(),
          ),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.amber,
            onPressed: () => _undoReorder(day.dayNumber),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Restore previous stop order for a day
  void _undoReorder(int dayNumber) {
    final previous = _previousDayStopsBeforeReorder[dayNumber];
    if (previous == null || _itinerary == null) return;

    final dayIdx = _itinerary!.days.indexWhere((d) => d.dayNumber == dayNumber);
    if (dayIdx == -1) return;

    final updatedDays = List<ItineraryModel>.from(_itinerary!.days);
    final target = updatedDays[dayIdx];
    updatedDays[dayIdx] = target.copyWith(
      stops: previous,
      isManuallyOrdered: true,
    );

    setState(() {
      _itinerary = _itinerary!.copyWith(days: updatedDays);
      _previousDayStopsBeforeReorder.remove(dayNumber);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Day $dayNumber: Restored previous stop order', style: GoogleFonts.outfit()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Toggle pin for an individual day stop
  void _togglePinStop(ItineraryModel day, int index) {
    if (_itinerary == null || index < 0 || index >= day.stops.length) return;
    final dayIdx = _itinerary!.days.indexWhere((d) => d.dayNumber == day.dayNumber);
    if (dayIdx == -1) return;

    final currentStops = List<ItineraryStop>.from(day.stops);
    final target = currentStops[index];
    final updatedPin = !target.isPinned;
    currentStops[index] = target.copyWith(
      isPinned: updatedPin,
      isAnchored: updatedPin,
    );

    final updatedDays = List<ItineraryModel>.from(_itinerary!.days);
    updatedDays[dayIdx] = day.copyWith(stops: currentStops);

    setState(() {
      _itinerary = _itinerary!.copyWith(days: updatedDays);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedPin ? 'Pinned "${target.name}" to fixed position' : 'Unpinned "${target.name}"',
          style: GoogleFonts.outfit(),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
