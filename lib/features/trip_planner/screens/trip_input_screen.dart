import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/widgets/premium_background.dart';
import '../../../core/widgets/premium_card.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null && extra['city'] != null) {
        _cityController.text = extra['city'] as String;
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final city = await _locationService.getCurrentCity();
      _cityController.text = city;
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

  void _generateItinerary() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one interest', style: TextStyle(color: Colors.white))),
      );
      return;
    }

    final data = {
      'city': _cityController.text.trim(),
      'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      'interests': _selectedInterests.toList(),
      'travelMode': _travelMode,
      'pace': _pace,
      'date': DateTime.now().toString().split(' ').first,
    };

    context.push('/itinerary', extra: data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Design Your Journey'),
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
        imageUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?q=80&w=2000&auto=format&fit=crop', // Taj Mahal archway
        imageHeight: 500,
        overlayOpacity: 0.4,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.xl, AppTokens.lg, AppTokens.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Where to next?',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: AppTokens.sm),
                  Text(
                    'Let our AI curate the perfect itinerary tailored exclusively for you.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                  ),
                  const SizedBox(height: AppTokens.xl),

                  // ── Form Card ──
                  PremiumCard(
                    padding: const EdgeInsets.all(AppTokens.xl),
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
                                style: Theme.of(context).textTheme.titleLarge,
                                decoration: const InputDecoration(
                                  hintText: 'Enter city name',
                                  prefixIcon: Icon(Icons.location_city),
                                ),
                                onChanged: _searchCity,
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
                                color: AppColors.brandSoft,
                                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                              ),
                              child: IconButton(
                                onPressed: _isDetectingLocation ? null : _detectLocation,
                                icon: _isDetectingLocation
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(
                                        Icons.my_location,
                                        color: AppColors.brand,
                                      ),
                                tooltip: 'Use GPS location',
                              ),
                            ),
                          ],
                        ),

                        if (_showSuggestions) ...[
                          const SizedBox(height: AppTokens.xs),
                          Material(
                            color: AppColors.cardAlt,
                            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                            clipBehavior: Clip.antiAlias,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: _citySuggestions.length.clamp(0, 5),
                              itemBuilder: (context, index) {
                                final suggestion = _citySuggestions[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on_outlined, size: 20),
                                  title: Text(
                                    suggestion['description'] ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  onTap: () {
                                    final desc = suggestion['description'] ?? '';
                                    _cityController.text = desc.split(',').first.trim();
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
                              child: Icon(Icons.arrow_forward, color: AppColors.border),
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
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
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
                              backgroundColor: AppColors.bg,
                              selectedColor: AppColors.text,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.text,
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
                              backgroundColor: AppColors.text, // Charcoal black for ultimate premium feel
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                            ),
                            icon: const Icon(Icons.auto_awesome, size: 20),
                            label: const Text('Craft My Itinerary'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textMuted,
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
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: Theme.of(context).textTheme.titleLarge,
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
            color: isSelected ? AppColors.brandSoft : AppColors.cardAlt,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: isSelected ? AppColors.brand : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: isSelected ? AppColors.brand : AppColors.textSoft),
              const SizedBox(height: AppTokens.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.brand : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
