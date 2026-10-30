import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/place_suggestion_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/utils/image_resolver.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/food_preferences.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../widgets/craft_header.dart';
import '../widgets/craft_loading_dialog.dart';
import '../widgets/craft_selector_card.dart';
import '../widgets/craft_step_indicator.dart';
import '../widgets/food_preference_selector.dart';
import '../../../core/models/travelers_model.dart';
import '../widgets/travelers_selector.dart';
import '../../../core/models/city_stay_model.dart';
import '../widgets/multi_city_route_builder.dart';

class TripInputScreen extends StatefulWidget {
  const TripInputScreen({super.key});

  @override
  State<TripInputScreen> createState() => _TripInputScreenState();
}

class _TripInputScreenState extends State<TripInputScreen>
    with TickerProviderStateMixin {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  final _cityController = TextEditingController();
  final _ageController = TextEditingController();
  final _budgetController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final _locationService = LocationService();
  final _placesService = PlacesService();

  int _currentStep = 0;
  static const int _totalSteps = 4;

  static const List<String> _stepLabels = [
    'Where & When',
    'Style & Pace',
    'Group & Budget',
    'Passions & Review',
  ];

  static const List<String> _popularCities = [
    'Jaipur',
    'Goa',
    'Agra',
    'Mumbai',
    'Delhi',
    'Varanasi',
    'Udaipur',
    'Kerala',
  ];

  // Timing & Pace State
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 30);
  String _travelMode = 'driving';
  String _pace = 'moderate';

  // Interests State
  final Set<String> _selectedInterests = {
    'Famous Places',
    'Local Food',
    'Heritage & History',
  };

  // Group & Budget State
  int _travelers = 1;
  TravelersModel _travelersModel = const TravelersModel(adults: 1, minors: 0);

  // Multi-day Date State
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  late DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  int get _numberOfDays => _endDate.difference(_startDate).inDays + 1;
  bool get _isMultiDay => _numberOfDays > 1;

  // Multi-City State
  bool _isMultiCity = false;
  List<CityStayModel> _multiCities = [];
  bool _isRoundTrip = false;

  void _enableMultiCityMode() {
    HapticFeedback.selectionClick();
    final currentCity = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : 'Jaipur';
    _cityController.text = currentCity;

    final stay1 = CityStayModel(
      id: 'city_0',
      name: currentCity,
      stateOrRegion: 'India',
      country: 'India',
      latitude: _selectedLatitude ?? 26.9124,
      longitude: _selectedLongitude ?? 75.7873,
      stayDays: 2,
      arrivalDate: _startDate,
      departureDate: _startDate.add(const Duration(days: 2)),
      heroImage: _heroImage,
    );

    final secondCityName = currentCity.toLowerCase() == 'udaipur' ? 'Jodhpur' : 'Udaipur';
    final stay2 = CityStayModel(
      id: 'city_1',
      name: secondCityName,
      stateOrRegion: 'Rajasthan',
      country: 'India',
      latitude: currentCity.toLowerCase() == 'udaipur' ? 26.2389 : 24.5854,
      longitude: currentCity.toLowerCase() == 'udaipur' ? 73.0243 : 73.7125,
      stayDays: 2,
      arrivalDate: _startDate.add(const Duration(days: 2)),
      departureDate: _startDate.add(const Duration(days: 4)),
      heroImage: ImageResolver.getHeroImage(secondCityName),
    );

    setState(() {
      _isMultiCity = true;
      _multiCities = [stay1, stay2];
      _endDate = _startDate.add(const Duration(days: 4));
      _showSuggestions = false;
    });
  }

  // Autocomplete, Debounce & Hero State
  bool _isDetectingLocation = false;
  bool _isSearchingPlaces = false;
  List<PlaceSuggestion> _placeSuggestions = [];
  bool _showSuggestions = false;
  String _heroImage = ImageResolver.getHeroImage('Jaipur');
  Timer? _searchDebounceTimer;
  int _searchGenerationToken = 0;
  final List<String> _recentSearches = [];
  double? _selectedLatitude;
  double? _selectedLongitude;

  @override
  void initState() {
    super.initState();

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        if (_cityController.text.trim().isEmpty) {
          _showRecentAndPopular();
        } else if (_placeSuggestions.isNotEmpty) {
          setState(() => _showSuggestions = true);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null && extra['city'] != null) {
        final initialCity = extra['city'] as String;
        _cityController.text = initialCity;
        _updateHeroImage(initialCity);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _updateHeroImage(String city) {
    if (city.trim().length >= 2) {
      setState(() {
        _heroImage = ImageResolver.getHeroImage(city.trim());
      });
    }
  }

  Future<void> _detectLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _isDetectingLocation = true);
    try {
      final city = await _locationService.getCurrentCity();
      if (city.isNotEmpty) {
        _cityController.text = city;
        _updateHeroImage(city);
        _addRecentSearch(city);
        setState(() => _showSuggestions = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not detect location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  void _onSearchQueryChanged(String query) {
    _updateHeroImage(query);

    _searchDebounceTimer?.cancel();
    final clean = query.trim();

    if (clean.length < 2) {
      if (clean.isEmpty && _searchFocusNode.hasFocus) {
        _showRecentAndPopular();
      } else {
        setState(() {
          _placeSuggestions = [];
          _showSuggestions = false;
          _isSearchingPlaces = false;
        });
      }
      return;
    }

    setState(() {
      _isSearchingPlaces = true;
      _showSuggestions = true;
    });

    final currentToken = ++_searchGenerationToken;

    // Debounce by 300 ms to avoid spamming endpoints
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _placesService.searchPlaceSuggestions(clean);
        if (!mounted || currentToken != _searchGenerationToken) return;

        setState(() {
          _placeSuggestions = results;
          _isSearchingPlaces = false;
          _showSuggestions = true;
        });
      } catch (_) {
        if (!mounted || currentToken != _searchGenerationToken) return;
        setState(() {
          _isSearchingPlaces = false;
        });
      }
    });
  }

  void _showRecentAndPopular() {
    setState(() {
      _showSuggestions = true;
      _isSearchingPlaces = false;
      _placeSuggestions = _popularCities.map((c) => PlaceSuggestion(
        name: c,
        secondaryText: 'Popular destination in India',
        fullDescription: '$c, India',
        placeId: 'popular_${c.toLowerCase()}',
        type: 'city',
      )).toList();
    });
  }

  void _addRecentSearch(String place) {
    final trimmed = place.trim();
    if (trimmed.isEmpty) return;
    _recentSearches.remove(trimmed);
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > 5) {
      _recentSearches.removeLast();
    }
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    HapticFeedback.selectionClick();
    _cityController.text = suggestion.name;
    _updateHeroImage(suggestion.name);
    _addRecentSearch(suggestion.name);

    setState(() {
      _selectedLatitude = suggestion.latitude;
      _selectedLongitude = suggestion.longitude;
      _showSuggestions = false;
    });

    _searchFocusNode.unfocus();
  }

  Future<void> _pickTime(bool isStart) async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.brandDeep,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  int get _durationHours {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final diff = endMinutes - startMinutes;
    if (diff <= 0) return 4;
    return (diff / 60).round().clamp(1, 24);
  }

  Future<void> _pickDateRange() async {
    HapticFeedback.selectionClick();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.brandDeep,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  secondary: AppColors.accent,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _applyDurationPreset(int days) {
    HapticFeedback.selectionClick();
    setState(() {
      _endDate = _startDate.add(Duration(days: days - 1));
    });
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    // Validate Step 0 (Destination)
    if (_currentStep == 0) {
      if (_isMultiCity) {
        if (_multiCities.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add at least 2 cities for a multi-city trip.'),
              backgroundColor: AppColors.brandDeep,
            ),
          );
          return;
        }
      } else {
        if (!_formKeyStep1.currentState!.validate()) return;
        setState(() => _showSuggestions = false);
        _searchFocusNode.unfocus();
      }
    }

    // Validate Step 2 (Group & Budget)
    if (_currentStep == 2) {
      if (!_formKeyStep3.currentState!.validate()) return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _generateItinerary();
    }
  }

  void _prevStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  void _generateItinerary() {
    if (_selectedInterests.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one interest before proceeding.'),
          backgroundColor: AppColors.brandDeep,
        ),
      );
      return;
    }

    final cityTrimmed = _cityController.text.trim();
    final startTimeStr =
        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr =
        '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    // Launch Cinematic AI Synthesis Loading Dialog
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.brandDeep,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CraftLoadingDialog(destination: cityTrimmed);
      },
    );

    // Maintain 3-second synthesis delay, then route per contract
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      final foodPref = context.read<AppSettingsProvider>().foodPreference;

      if (_isMultiCity) {
        final totalDays = _multiCities.fold<int>(0, (s, c) => s + c.stayDays);
        final data = {
          'cities': _multiCities.map((c) => c.toMap()).toList(),
          'isRoundTrip': _isRoundTrip,
          'startDate': _startDate.toIso8601String(),
          'endDate': _endDate.toIso8601String(),
          'totalDays': totalDays,
          'interests': _selectedInterests.toList(),
          'travelMode': _travelMode,
          'pace': _pace,
          'travelers': _travelersModel.toMap(),
          'foodPreference': foodPref,
          'budget': int.tryParse(_budgetController.text),
        };
        context.pushReplacement('/multi-city-itinerary', extra: data);
      } else if (_isMultiDay) {
        final data = {
          'city': cityTrimmed,
          'startTime': startTimeStr,
          'endTime': endTimeStr,
          'interests': _selectedInterests.toList(),
          'travelMode': _travelMode,
          'pace': _pace,
          'startDate': _startDate.toString().split(' ').first,
          'endDate': _endDate.toString().split(' ').first,
          'numberOfDays': _numberOfDays,
          'age': int.tryParse(_ageController.text),
          'budget': int.tryParse(_budgetController.text),
          'travelers': _travelers,
          'adults': _travelersModel.adults,
          'minors': _travelersModel.minors,
          'minorAgeBands': _travelersModel.minorAgeBands,
          'travelersSummary': _travelersModel.summary,
          'foodPreference': foodPref,
          if (_selectedLatitude != null) 'latitude': _selectedLatitude,
          if (_selectedLongitude != null) 'longitude': _selectedLongitude,
        };
        context.pushReplacement('/multi-day-itinerary', extra: data);
      } else {
        final data = {
          'city': cityTrimmed,
          'startTime': startTimeStr,
          'endTime': endTimeStr,
          'interests': _selectedInterests.toList(),
          'travelMode': _travelMode,
          'pace': _pace,
          'date': _startDate.toString().split(' ').first,
          'age': int.tryParse(_ageController.text),
          'budget': int.tryParse(_budgetController.text),
          'travelers': _travelers,
          'adults': _travelersModel.adults,
          'minors': _travelersModel.minors,
          'minorAgeBands': _travelersModel.minorAgeBands,
          'travelersSummary': _travelersModel.summary,
          'foodPreference': foodPref,
          if (_selectedLatitude != null) 'latitude': _selectedLatitude,
          if (_selectedLongitude != null) 'longitude': _selectedLongitude,
        };
        context.pushReplacement('/itinerary', extra: data);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_showSuggestions) {
          setState(() => _showSuggestions = false);
        }
        _searchFocusNode.unfocus();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            // Dynamic Parallax Header with Glass Controls
            CraftHeader(
              heroImageUrl: _heroImage,
              destinationName: _cityController.text.trim(),
              onBack: _prevStep,
            ),

            // Stepper Indicator
            CraftStepIndicator(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
              stepLabels: _stepLabels,
              onStepTapped: (index) {
                setState(() => _currentStep = index);
              },
            ),

            // Scrollable Step Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildStepView(key: ValueKey<int>(_currentStep)),
              ),
            ),
          ],
        ),

        // Floating Bottom Action Bar
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: EdgeInsets.only(
        left: AppTokens.lg,
        right: AppTokens.lg,
        top: AppTokens.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppTokens.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: AppTokens.shadow(level: 2),
      ),
      child: Row(
        children: [
          // Secondary Back Button if on later steps
          if (_currentStep > 0) ...[
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSoft,
                side: const BorderSide(color: AppColors.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            const SizedBox(width: AppTokens.sm),
          ],

          // Primary Continue / Craft Action
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                gradient: isLastStep
                    ? const LinearGradient(
                        colors: [Color(0xFF0F2361), Color(0xFF1A3685)],
                      )
                    : null,
                boxShadow: isLastStep
                    ? [
                        BoxShadow(
                          color: AppColors.brandDeep.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isLastStep ? Colors.transparent : AppColors.brandDeep,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLastStep ? 'Craft My Itinerary' : 'Continue',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLastStep
                          ? Icons.auto_awesome
                          : Icons.arrow_forward_rounded,
                      size: 18,
                      color: isLastStep ? AppColors.accentLight : Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepView({required Key key}) {
    switch (_currentStep) {
      case 0:
        return _buildStep1DestinationDates(key: key);
      case 1:
        return _buildStep2StyleAndPace(key: key);
      case 2:
        return _buildStep3GroupAndBudget(key: key);
      case 3:
        return _buildStep4InterestsAndLaunch(key: key);
      default:
        return const SizedBox.shrink();
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 1: DESTINATION & DATES ("Where & When")
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildStep1DestinationDates({required Key key}) {
    if (_isMultiCity) {
      return SingleChildScrollView(
        key: key,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.lg,
          vertical: AppTokens.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-City Route',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Build your route and configure city stays.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSoft),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isMultiCity = false);
                  },
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text(
                    'Single City',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.md),
            MultiCityRouteBuilder(
              cities: _multiCities,
              onCitiesChanged: (updated) {
                setState(() {
                  _multiCities = updated;
                  final totalDays = _multiCities.fold<int>(0, (s, c) => s + c.stayDays);
                  _endDate = _startDate.add(Duration(days: totalDays > 0 ? totalDays - 1 : 1));
                });
              },
              isRoundTrip: _isRoundTrip,
              onRoundTripChanged: (val) {
                setState(() => _isRoundTrip = val);
              },
              startDate: _startDate,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.lg,
        vertical: AppTokens.md,
      ),
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline & Description
            const Text(
              'Where is your journey taking you?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select any city in India or search your destination.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: AppTokens.md),

            // Destination Search Bar
            Stack(
              alignment: Alignment.centerRight,
              children: [
                TextFormField(
                  controller: _cityController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Jaipur, Rajasthan',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.brand,
                      size: 22,
                    ),
                    suffixIcon: _cityController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textSoft,
                            ),
                            onPressed: () {
                              _cityController.clear();
                              _onSearchQueryChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      borderSide: const BorderSide(
                        color: AppColors.brand,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: _onSearchQueryChanged,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Destination is required'
                      : null,
                ),
              ],
            ),

            // Smart Autocomplete Suggestions Dropdown
            if (_showSuggestions) ...[
              const SizedBox(height: 6),
              _buildSuggestionsDropdown(),
            ],

            const SizedBox(height: AppTokens.sm),

            // GPS Auto-detect Button
            InkWell(
              onTap: _isDetectingLocation ? null : _detectLocation,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isDetectingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.brand),
                            ),
                          )
                        : const Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: AppColors.brand,
                          ),
                    const SizedBox(width: 6),
                    Text(
                      _isDetectingLocation
                          ? 'Locating your current city...'
                          : 'Use my current location',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTokens.md),

            // Popular Destinations Chips
            const Text(
              'POPULAR DESTINATIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popularCities.map((city) {
                final isSelected =
                    _cityController.text.trim().toLowerCase() ==
                        city.toLowerCase();
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _cityController.text = city;
                    _updateHeroImage(city);
                    _addRecentSearch(city);
                    setState(() => _showSuggestions = false);
                    _searchFocusNode.unfocus();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.brand : Colors.white,
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : AppColors.border,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.brand.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      city,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textSoft,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppTokens.md),

            // Multi-city banner / button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTokens.md),
              decoration: BoxDecoration(
                color: AppColors.brandSoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppTokens.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visiting multiple cities?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Add 2 to 8 cities with inter-city transit.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _enableMultiCityMode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandDeep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      ),
                    ),
                    child: const Text(
                      'Add City',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.xl),

            // Trip Duration Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TRIP DATES & DURATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textSoft,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                  child: Text(
                    '$_numberOfDays ${_numberOfDays == 1 ? "Day" : "Days"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentDeep,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sm),

            // Quick Duration Preset Buttons
            Row(
              children: [
                _buildDurationChip(label: '1 Day', days: 1),
                const SizedBox(width: 6),
                _buildDurationChip(label: '2 Days', days: 2),
                const SizedBox(width: 6),
                _buildDurationChip(label: '3 Days', days: 3),
                const SizedBox(width: 6),
                _buildDurationChip(label: '5 Days', days: 5),
              ],
            ),

            const SizedBox(height: AppTokens.sm),

            // Interactive Calendar Picker Card
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.all(AppTokens.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppTokens.shadow(level: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusSm),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.brandDeep,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppTokens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isMultiDay
                                ? '${_formatDate(_startDate)}  →  ${_formatDate(_endDate)}'
                                : _formatDate(_startDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isMultiDay
                                ? 'Multi-day itinerary spanning $_numberOfDays days'
                                : 'Single-day city exploration',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar_outlined,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTokens.xl),

            // Daily Active Hours Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DAILY ACTIVE HOURS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textSoft,
                  ),
                ),
                Text(
                  '$_durationHours hours / day',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sm),

            Row(
              children: [
                Expanded(
                  child: _buildTimeBox(
                    label: 'Start Exploring',
                    time: _startTime,
                    icon: Icons.wb_sunny_outlined,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: AppTokens.md),
                Expanded(
                  child: _buildTimeBox(
                    label: 'Wrap Up By',
                    time: _endTime,
                    icon: Icons.nightlight_outlined,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsDropdown() {
    final query = _cityController.text.trim();

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTokens.shadow(level: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSearchingPlaces)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation(AppColors.brand),
              ),

            if (_placeSuggestions.isEmpty && !_isSearchingPlaces && query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No destinations found matching "$query".\nTry another spelling or pick a popular city.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSoft, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _placeSuggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (context, index) {
                    final suggestion = _placeSuggestions[index];
                    return InkWell(
                      onTap: () => _selectSuggestion(suggestion),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.brandSoft,
                                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                              ),
                              child: Icon(
                                suggestion.iconData,
                                size: 18,
                                color: AppColors.brandDeep,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHighlightedText(suggestion.name, query),
                                  const SizedBox(height: 2),
                                  Text(
                                    suggestion.secondaryText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSoft,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                              ),
                              child: Text(
                                suggestion.typeLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex < 0) {
      return Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.text, fontSize: 14),
        children: [
          if (matchIndex > 0)
            TextSpan(
              text: text.substring(0, matchIndex),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + query.length),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.brand,
            ),
          ),
          if (matchIndex + query.length < text.length)
            TextSpan(
              text: text.substring(matchIndex + query.length),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  Widget _buildDurationChip({required String label, required int days}) {
    final isSelected = _numberOfDays == days;

    return Expanded(
      child: GestureDetector(
        onTap: () => _applyDurationPreset(days),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandDeep : Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(
              color: isSelected ? AppColors.brandDeep : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBox({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.md,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTokens.shadow(level: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.textSoft),
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
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 2: STYLE & PACE ("How You Move")
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildStep2StyleAndPace({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.lg,
        vertical: AppTokens.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How do you like to explore?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'We tune transit times and sightseeing density to your pace.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: AppTokens.lg),

          const Text(
            'PRIMARY TRANSPORT MODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: AppTokens.sm),

          CraftSelectorCard(
            title: 'Driving / Cab',
            subtitle: 'Best for seamless city travel, AC comfort, and longer distances.',
            icon: Icons.directions_car_rounded,
            badge: 'Most Popular',
            isSelected: _travelMode == 'driving',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _travelMode = 'driving');
            },
          ),
          const SizedBox(height: AppTokens.sm),

          CraftSelectorCard(
            title: 'Walking & Strolling',
            subtitle:
                'Ideal for historic old-town lanes, heritage walks, and vibrant bazaars.',
            icon: Icons.directions_walk_rounded,
            badge: 'Scenic',
            isSelected: _travelMode == 'walking',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _travelMode = 'walking');
            },
          ),
          const SizedBox(height: AppTokens.sm),

          CraftSelectorCard(
            title: 'Public Transit & Metro',
            subtitle:
                'Fast metro lines, local buses, and budget-friendly city travel.',
            icon: Icons.directions_transit_rounded,
            badge: 'Budget',
            isSelected: _travelMode == 'transit',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _travelMode = 'transit');
            },
          ),

          const SizedBox(height: AppTokens.xl),

          const Text(
            'PREFERRED PACE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: AppTokens.sm),

          CraftSelectorCard(
            title: 'Relaxed & Unrushed',
            subtitle: '2–3 spots per day with ample leisure, cafe visits, and rest.',
            icon: Icons.spa_rounded,
            badge: 'Leisurely',
            isSelected: _pace == 'relaxed',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _pace = 'relaxed');
            },
          ),
          const SizedBox(height: AppTokens.sm),

          CraftSelectorCard(
            title: 'Moderate & Balanced',
            subtitle: '4–5 key attractions with a balanced mix of culture, food, and sightseeing.',
            icon: Icons.hiking_rounded,
            badge: 'Recommended',
            isSelected: _pace == 'moderate',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _pace = 'moderate');
            },
          ),
          const SizedBox(height: AppTokens.sm),

          CraftSelectorCard(
            title: 'Fast & Action-Packed',
            subtitle: '6+ attractions per day for maximum coverage and energetic sightseeing.',
            icon: Icons.flash_on_rounded,
            badge: 'High Energy',
            isSelected: _pace == 'fast',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _pace = 'fast');
            },
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 3: GROUP & BUDGET ("Who & Resources")
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildStep3GroupAndBudget({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.lg,
        vertical: AppTokens.md,
      ),
      child: Form(
        key: _formKeyStep3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Who is traveling with you?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'We tailor recommendations, tickets, and group logistics accordingly.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: AppTokens.lg),

            TravelersSelector(
              initialValue: _travelersModel,
              onChanged: (updated) {
                setState(() {
                  _travelersModel = updated;
                  _travelers = updated.totalCount;
                });
              },
            ),

            const SizedBox(height: AppTokens.xl),

            const Text(
              'TRAVELER AGE (OPTIONAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Helps us recommend age-appropriate activities, walks, and venues.',
              style: TextStyle(fontSize: 12, color: AppColors.textSoft),
            ),
            const SizedBox(height: AppTokens.sm),

            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 26',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.cake_outlined,
                  color: AppColors.brand,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(
                    color: AppColors.brand,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final age = int.tryParse(value);
                  if (age == null || age < 1 || age > 120) {
                    return 'Please enter a valid age';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: AppTokens.xl),

            const Text(
              'ESTIMATED IN-CITY BUDGET (INR ₹)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Estimated spend for food, entry tickets, and activities (excluding hotels).',
              style: TextStyle(fontSize: 12, color: AppColors.textSoft),
            ),
            const SizedBox(height: AppTokens.sm),

            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 8000',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(
                    color: AppColors.brand,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final budget = int.tryParse(value);
                  if (budget == null || budget < 0) {
                    return 'Please enter a valid amount';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: AppTokens.sm),

            // Quick Budget Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBudgetPresetChip('₹3,000 (Saver)', '3000'),
                _buildBudgetPresetChip('₹8,000 (Standard)', '8000'),
                _buildBudgetPresetChip('₹15,000 (Comfort)', '15000'),
                _buildBudgetPresetChip('₹25,000+ (Luxury)', '25000'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupPreset({required String label, required int count}) {
    final isSelected = _travelers == count;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _travelers = count);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandDeep : Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(
              color: isSelected ? AppColors.brandDeep : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetPresetChip(String label, String amount) {
    final isSelected = _budgetController.text == amount;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _budgetController.text = amount);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSoft,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 4: PASSIONS & LAUNCH ("What You Love & Review")
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildStep4InterestsAndLaunch({required Key key}) {
    final cityName = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : 'Your Destination';

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.lg,
        vertical: AppTokens.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'What excites you most?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.4,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedInterests.isEmpty
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Text(
                  '${_selectedInterests.length} selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _selectedInterests.isEmpty
                        ? AppColors.error
                        : AppColors.brandDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select your travel interests. Please choose at least one.',
            style: TextStyle(fontSize: 13, color: AppColors.textSoft),
          ),
          const SizedBox(height: AppTokens.lg),

          // Categorized Interest Chips
          _buildInterestCategory(
            title: 'HERITAGE & CULTURE',
            tags: [
              'Famous Places',
              'Heritage & History',
              'Temples & Spirituality',
              'Cultural Experiences',
            ],
          ),
          const SizedBox(height: AppTokens.md),

          _buildInterestCategory(
            title: 'FOOD, FLAVORS & SHOPPING',
            tags: [
              'Local Food',
              'Street Food',
              'Markets & Shopping',
            ],
          ),
          const SizedBox(height: AppTokens.md),

          _buildInterestCategory(
            title: 'OUTDOOR & EXPERIENCES',
            tags: [
              'Nature & Parks',
              'Adventure',
              'Photography',
              'Hidden Gems',
              'Family Friendly',
            ],
          ),

          const SizedBox(height: AppTokens.xl),

          // Food Preference Selector
          Container(
            padding: const EdgeInsets.all(AppTokens.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppTokens.shadow(level: 1),
            ),
            child: const FoodPreferenceSelector(
              showHeader: true,
              isCompact: true,
            ),
          ),

          const SizedBox(height: AppTokens.xl),

          // Itinerary Summary Preview Card (Live Review)
          const Text(
            'ITINERARY SUMMARY PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: AppTokens.sm),

          Container(
            padding: const EdgeInsets.all(AppTokens.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppTokens.shadow(level: 2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppTokens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isMultiCity
                                ? _multiCities.map((c) => c.name).join(' → ') + (_isRoundTrip ? ' → ${_multiCities.first.name}' : '')
                                : cityName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isMultiCity
                                ? '${_multiCities.fold<int>(0, (s, c) => s + c.stayDays)} Days (${_multiCities.length} Cities) · Transit included'
                                : (_isMultiDay
                                    ? '$_numberOfDays Days (${_formatDate(_startDate)} - ${_formatDate(_endDate)})'
                                    : '1 Day (${_formatDate(_startDate)})'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDossierItem(
                      icon: Icons.timer_outlined,
                      label: 'Active Hours',
                      value: '${_startTime.format(context)} - ${_endTime.format(context)}',
                    ),
                    _buildDossierItem(
                      icon: _travelMode == 'driving'
                          ? Icons.directions_car_outlined
                          : _travelMode == 'walking'
                              ? Icons.directions_walk_outlined
                              : Icons.directions_transit_outlined,
                      label: 'Mode & Pace',
                      value:
                          '${_travelMode.toUpperCase()} • ${_pace.toUpperCase()}',
                    ),
                    _buildDossierItem(
                      icon: _travelersModel.hasMinors
                          ? Icons.family_restroom_outlined
                          : Icons.person_outline,
                      label: 'Travelers',
                      value: _travelersModel.compactBadge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 10),
                Consumer<AppSettingsProvider>(
                  builder: (context, settings, _) {
                    final pref = settings.foodPreference;
                    final label = FoodPreference.getLabel(pref);
                    final dotColor = FoodPreference.getIndicatorColor(pref);
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Dietary Plan: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Food filtered for $label',
                          style: TextStyle(
                            fontSize: 11,
                            color: dotColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.lg),
        ],
      ),
    );
  }

  Widget _buildInterestCategory({
    required String title,
    required List<String> tags,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppColors.textSoft,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = _selectedInterests.contains(tag);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isSelected) {
                    _selectedInterests.remove(tag);
                  } else {
                    _selectedInterests.add(tag);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brand : Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  border: Border.all(
                    color: isSelected ? AppColors.brand : AppColors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconForInterest(tag),
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textSoft,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDossierItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  IconData _getIconForInterest(String interest) {
    switch (interest.toLowerCase()) {
      case 'famous places':
        return Icons.account_balance_rounded;
      case 'heritage & history':
        return Icons.history_edu_rounded;
      case 'temples & spirituality':
        return Icons.temple_hindu_rounded;
      case 'local food':
        return Icons.restaurant_rounded;
      case 'street food':
        return Icons.fastfood_rounded;
      case 'markets & shopping':
        return Icons.shopping_bag_rounded;
      case 'nature & parks':
        return Icons.park_rounded;
      case 'cultural experiences':
        return Icons.theater_comedy_rounded;
      case 'adventure':
        return Icons.paragliding_rounded;
      case 'hidden gems':
        return Icons.diamond_outlined;
      case 'photography':
        return Icons.camera_alt_rounded;
      case 'family friendly':
        return Icons.family_restroom_rounded;
      default:
        return Icons.star_border_rounded;
    }
  }
}
