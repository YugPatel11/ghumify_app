import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/utils/image_resolver.dart';

class TripInputScreen extends StatefulWidget {
  const TripInputScreen({super.key});

  @override
  State<TripInputScreen> createState() => _TripInputScreenState();
}

class _TripInputScreenState extends State<TripInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _locationService = LocationService();
  final _placesService = PlacesService();

  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String _travelMode = 'driving';
  String _pace = 'moderate';
  final Set<String> _selectedInterests = {'Famous Places', 'Local Food'};
  bool _isDetectingLocation = false;
  List<Map<String, String>> _citySuggestions = [];
  bool _showSuggestions = false;
  String _heroImage = ImageResolver.getHeroImage('India');

  // Date range for multi-day trips
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int get _numberOfDays => _endDate.difference(_startDate).inDays + 1;
  bool get _isMultiDay => _numberOfDays > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null && extra['city'] != null) {
        _cityController.text = extra['city'] as String;
        _updateHeroImage(extra['city'] as String);
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _updateHeroImage(String city) {
    if (city.trim().length > 2) {
      setState(() {
        _heroImage = ImageResolver.getHeroImage(city.trim());
      });
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final city = await _locationService.getCurrentCity();
      _cityController.text = city;
      _updateHeroImage(city);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not detect location: $e')),
        );
      }
    }
    setState(() => _isDetectingLocation = false);
  }

  Future<void> _searchCity(String query) async {
    if (query.length < 2) {
      setState(() {
        _citySuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final suggestions = await _placesService.autocomplete(query);
    setState(() {
      _citySuggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    return ((endMinutes - startMinutes) / 60).round().clamp(1, 24);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.brand,
                  onPrimary: Colors.white,
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

  void _generateItinerary() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one interest', style: TextStyle(color: Colors.white))),
      );
      return;
    }

    final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    if (_isMultiDay) {
      // Multi-day route
      final data = {
        'city': _cityController.text.trim(),
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'interests': _selectedInterests.toList(),
        'travelMode': _travelMode,
        'pace': _pace,
        'startDate': _startDate.toString().split(' ').first,
        'endDate': _endDate.toString().split(' ').first,
        'numberOfDays': _numberOfDays,
      };
      context.push('/multi-day-itinerary', extra: data);
    } else {
      // Single-day route
      final data = {
        'city': _cityController.text.trim(),
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'interests': _selectedInterests.toList(),
        'travelMode': _travelMode,
        'pace': _pace,
        'date': _startDate.toString().split(' ').first,
      };
      context.push('/itinerary', extra: data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Design Your Journey'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassWhiteLight,
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.text),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // ── Dynamic Background ──
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: Image.network(
                _heroImage,
                key: ValueKey<String>(_heroImage),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          // Gradient Overlay
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

          // ── Content ──
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.md, AppTokens.lg, AppTokens.xxl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Where to next?',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppColors.text,
                            fontSize: 48,
                          ),
                    ),
                    const SizedBox(height: AppTokens.sm),
                    Text(
                      'Let our AI curate the perfect itinerary tailored exclusively for you.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSoft,
                          ),
                    ),
                    const SizedBox(height: AppTokens.xl),

                    // ── Glassmorphism Form Container ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(AppTokens.xl),
                          decoration: BoxDecoration(
                            color: AppColors.glassWhite,
                            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // City Input
                              _buildSectionLabel('Destination'),
                              const SizedBox(height: AppTokens.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cityController,
                                      style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w600),
                                      decoration: InputDecoration(
                                        hintText: 'Enter city name',
                                        hintStyle: TextStyle(color: AppColors.textMuted),
                                        prefixIcon: Icon(Icons.location_city, color: AppColors.textSoft),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.6),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                                          borderSide: BorderSide(color: AppColors.borderGlass),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                                          borderSide: BorderSide(color: AppColors.borderGlass),
                                        ),
                                      ),
                                      onChanged: _searchCity,
                                      onFieldSubmitted: (val) {
                                        _updateHeroImage(val);
                                      },
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter a city';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppTokens.sm),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.brandDeep,
                                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                                    ),
                                    child: IconButton(
                                      onPressed: _isDetectingLocation ? null : _detectLocation,
                                      icon: _isDetectingLocation
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(
                                              Icons.my_location,
                                              color: Colors.white,
                                            ),
                                      tooltip: 'Use GPS location',
                                    ),
                                  ),
                                ],
                              ),

                              if (_showSuggestions) ...[
                                const SizedBox(height: AppTokens.xs),
                                Material(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                                  clipBehavior: Clip.antiAlias,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: _citySuggestions.length.clamp(0, 5),
                                    itemBuilder: (context, index) {
                                      final suggestion = _citySuggestions[index];
                                      return ListTile(
                                        leading: const Icon(Icons.location_on_outlined, size: 20, color: AppColors.textSoft),
                                        title: Text(
                                          suggestion['description'] ?? '',
                                          style: const TextStyle(color: AppColors.text),
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

                              const SizedBox(height: AppTokens.lg),

                              // Time Range
                              _buildSectionLabel('Available Time'),
                              const SizedBox(height: AppTokens.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTimePicker(
                                      label: 'Start',
                                      time: _startTime,
                                      onTap: () => _pickTime(true),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: AppTokens.sm),
                                    child: Icon(Icons.arrow_forward, color: AppColors.textSoft),
                                  ),
                                  Expanded(
                                    child: _buildTimePicker(
                                      label: 'End',
                                      time: _endTime,
                                      onTap: () => _pickTime(false),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTokens.xs),
                              Text(
                                'Total Duration: $_durationHours hours',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),

                              const SizedBox(height: AppTokens.lg),

                              // Date Range
                              _buildSectionLabel(_isMultiDay ? 'Trip Dates' : 'Trip Date'),
                              const SizedBox(height: AppTokens.sm),
                              GestureDetector(
                                onTap: _pickDateRange,
                                child: Container(
                                  padding: const EdgeInsets.all(AppTokens.md),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                                    border: Border.all(color: AppColors.borderGlass),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textSoft),
                                      const SizedBox(width: AppTokens.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _isMultiDay
                                                  ? '${_formatDate(_startDate)} — ${_formatDate(_endDate)}'
                                                  : _formatDate(_startDate),
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.text,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _isMultiDay
                                                  ? '$_numberOfDays days'
                                                  : 'Single day trip',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSoft,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: AppTokens.lg),

                              // Interests
                              _buildSectionLabel('Interests'),
                              const SizedBox(height: AppTokens.sm),
                              Wrap(
                                spacing: AppTokens.sm,
                                runSpacing: AppTokens.sm,
                                children: AppConstants.interestTags.map((interest) {
                                  final isSelected = _selectedInterests.contains(interest);
                                  return FilterChip(
                                    label: Text(interest),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedInterests.add(interest);
                                        } else {
                                          _selectedInterests.remove(interest);
                                        }
                                      });
                                    },
                                    backgroundColor: Colors.white.withOpacity(0.6),
                                    selectedColor: AppColors.brand,
                                    checkmarkColor: Colors.white,
                                    side: BorderSide(
                                      color: isSelected ? AppColors.brand : AppColors.borderGlass,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: AppTokens.lg),

                              // Travel Mode
                              _buildSectionLabel('Travel Mode'),
                              const SizedBox(height: AppTokens.sm),
                              Row(
                                children: [
                                  _buildModeBox('Driving', 'driving', Icons.directions_car_outlined),
                                  const SizedBox(width: AppTokens.sm),
                                  _buildModeBox('Walking', 'walking', Icons.directions_walk_outlined),
                                  const SizedBox(width: AppTokens.sm),
                                  _buildModeBox('Transit', 'transit', Icons.directions_bus_outlined),
                                ],
                              ),

                              const SizedBox(height: AppTokens.lg),

                              // Pace
                              _buildSectionLabel('Pace'),
                              const SizedBox(height: AppTokens.sm),
                              Row(
                                children: [
                                  _buildModeBox('Relaxed', 'relaxed', Icons.spa_outlined, isPace: true),
                                  const SizedBox(width: AppTokens.sm),
                                  _buildModeBox('Moderate', 'moderate', Icons.hiking_outlined, isPace: true),
                                  const SizedBox(width: AppTokens.sm),
                                  _buildModeBox('Fast', 'fast', Icons.flash_on_outlined, isPace: true),
                                ],
                              ),
                              
                              const SizedBox(height: AppTokens.xl),

                              // Generate Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _generateItinerary,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    elevation: 5,
                                    shadowColor: AppColors.brand.withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                                    ),
                                  ),
                                  icon: const Icon(Icons.auto_awesome, size: 20),
                                  label: Text(
                                    _isMultiDay
                                      ? 'Craft $_numberOfDays-Day Itinerary'
                                      : 'Craft My Itinerary',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.xxl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSoft,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTokens.md),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSoft)),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBox(String label, String value, IconData icon, {bool isPace = false}) {
    final isSelected = isPace ? _pace == value : _travelMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isPace) {
              _pace = value;
            } else {
              _travelMode = value;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppTokens.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brand : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: isSelected ? AppColors.brand : AppColors.borderGlass,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: isSelected ? Colors.white : AppColors.textSoft),
              const SizedBox(height: AppTokens.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

