import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/utils/image_resolver.dart';
import '../widgets/craft_header.dart';
import '../widgets/craft_loading_dialog.dart';
import '../widgets/craft_selector_card.dart';
import '../widgets/craft_step_indicator.dart';

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

  // Multi-day Date State
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  late DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  int get _numberOfDays => _endDate.difference(_startDate).inDays + 1;
  bool get _isMultiDay => _numberOfDays > 1;

  // Autocomplete & Hero State
  bool _isDetectingLocation = false;
  List<Map<String, String>> _citySuggestions = [];
  bool _showSuggestions = false;
  String _heroImage = ImageResolver.getHeroImage('Jaipur');

  @override
  void initState() {
    super.initState();

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

  Future<void> _searchCity(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _citySuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      final suggestions = await _placesService.autocomplete(query.trim());
      if (mounted) {
        setState(() {
          _citySuggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (_) {
      // Fallback silently if autocomplete service is throttled
    }
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
      if (!_formKeyStep1.currentState!.validate()) return;
      setState(() => _showSuggestions = false);
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
          content: Text('Please select at least one passion or interest'),
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

      if (_isMultiDay) {
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
        };
        context.pushReplacement('/itinerary', extra: data);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          color: AppColors.brandDeep.withOpacity(0.35),
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
                              setState(() => _showSuggestions = false);
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
                  onChanged: (val) {
                    _searchCity(val);
                    _updateHeroImage(val);
                  },
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Destination city is required'
                      : null,
                ),
              ],
            ),

            // Autocomplete Suggestions Overlay List
            if (_showSuggestions && _citySuggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppTokens.shadow(level: 2),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _citySuggestions.length.clamp(0, 4),
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (context, index) {
                    final suggestion = _citySuggestions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: AppColors.brand,
                      ),
                      title: Text(
                        suggestion['description'] ?? '',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        final desc = suggestion['description'] ?? '';
                        final cityName = desc.split(',').first.trim();
                        _cityController.text = cityName;
                        _updateHeroImage(cityName);
                        setState(() => _showSuggestions = false);
                      },
                    );
                  },
                ),
              ),
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

            // Quick City Presets
            const Text(
              'POPULAR INSPIRATIONS',
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
                    setState(() => _showSuggestions = false);
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
                                color: AppColors.brand.withOpacity(0.2),
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
                                : 'Single-day whirlwind exploration',
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
            'We tune transit times and spot densities to your rhythm.',
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
            subtitle: 'Best for seamless city hopping, AC comfort & distance.',
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
                'Immersive old-town alleys, heritage lanes & street bazaars.',
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
                'Fast metro lines, local buses & eco-friendly city travel.',
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
            subtitle: '2–3 spots a day. Plenty of cafe time, rest & soaking in.',
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
            subtitle: '4–5 key attractions. Ideal mix of culture, food & photo ops.',
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
            subtitle: '6+ attractions. Maximum coverage for energetic travelers.',
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
              'We tailor tickets, seating and recommendations to group scale.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: AppTokens.lg),

            const Text(
              'NUMBER OF TRAVELERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: AppTokens.sm),

            // Stepper Counter Card
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.md,
                vertical: AppTokens.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: AppColors.border),
                boxShadow: AppTokens.shadow(level: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.group_outlined,
                        color: AppColors.brand,
                        size: 22,
                      ),
                      const SizedBox(width: AppTokens.sm),
                      Text(
                        _travelers == 1
                            ? 'Solo Explorer'
                            : _travelers == 2
                                ? 'Duo / Couple'
                                : '$_travelers Travelers',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: AppColors.textSoft,
                        ),
                        onPressed: () {
                          if (_travelers > 1) {
                            HapticFeedback.selectionClick();
                            setState(() => _travelers--);
                          }
                        },
                      ),
                      Text(
                        '$_travelers',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandDeep,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: AppColors.brand,
                        ),
                        onPressed: () {
                          if (_travelers < 20) {
                            HapticFeedback.selectionClick();
                            setState(() => _travelers++);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.sm),

            // Quick Group Presets
            Row(
              children: [
                _buildGroupPreset(label: 'Solo (1)', count: 1),
                const SizedBox(width: 6),
                _buildGroupPreset(label: 'Couple (2)', count: 2),
                const SizedBox(width: 6),
                _buildGroupPreset(label: 'Family (4)', count: 4),
                const SizedBox(width: 6),
                _buildGroupPreset(label: 'Group (6+)', count: 6),
              ],
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
              'Helps adjust steep climbs, stairs, and night activity suitability.',
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
              'Approx. spend for food, entry tickets & activities (exclude hotels).',
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
  // STEP 4: PASSIONS & LAUNCH ("What You Love & Dossier")
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
                      ? AppColors.error.withOpacity(0.1)
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
            'Tap all that match your travel style. At least 1 is required.',
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

          // Trip Dossier Summary Card (Live Review)
          const Text(
            'TRIP DOSSIER PREVIEW',
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
                            cityName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isMultiDay
                                ? '$_numberOfDays Days (${_formatDate(_startDate)} - ${_formatDate(_endDate)})'
                                : '1 Day (${_formatDate(_startDate)})',
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
                      icon: Icons.person_outline,
                      label: 'Travelers',
                      value: '$_travelers People',
                    ),
                  ],
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
                            color: AppColors.brand.withOpacity(0.2),
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
