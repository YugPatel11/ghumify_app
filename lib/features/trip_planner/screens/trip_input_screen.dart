import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';

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
    // Check if city was passed via extra
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
        const SnackBar(content: Text('Please select at least one interest')),
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
      appBar: AppBar(
        title: const Text('Plan Your Trip'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // City Input
              Text('Where are you going?',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
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
                  const SizedBox(width: 12),
                  // GPS button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed:
                          _isDetectingLocation ? null : _detectLocation,
                      icon: _isDetectingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.my_location,
                              color: AppColors.primaryOrange,
                            ),
                      tooltip: 'Use GPS location',
                    ),
                  ),
                ],
              ),

              // City suggestions
              if (_showSuggestions)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _citySuggestions.length.clamp(0, 5),
                    itemBuilder: (context, index) {
                      final suggestion = _citySuggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            size: 20),
                        title: Text(
                          suggestion['description'] ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        dense: true,
                        onTap: () {
                          final desc = suggestion['description'] ?? '';
                          _cityController.text =
                              desc.split(',').first.trim();
                          setState(() => _showSuggestions = false);
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 28),

              // Time Range
              Text('Available Time',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
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
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward, color: AppColors.neutral400),
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
              const SizedBox(height: 8),
              Text(
                '⏱️ Total: $_durationHours hours',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w500,
                    ),
              ),

              const SizedBox(height: 28),

              // Interests
              Text('What interests you?',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                    selectedColor: AppColors.primaryOrange.withOpacity(0.2),
                    checkmarkColor: AppColors.primaryOrange,
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Travel Mode
              Text('Travel Mode',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildModeChip('🚗 Driving', 'driving'),
                  const SizedBox(width: 8),
                  _buildModeChip('🚶 Walking', 'walking'),
                  const SizedBox(width: 8),
                  _buildModeChip('🚌 Transit', 'transit'),
                ],
              ),

              const SizedBox(height: 28),

              // Pace
              Text('Pace Preference',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildModeChip('🐢 Relaxed', 'relaxed', isPace: true),
                  const SizedBox(width: 8),
                  _buildModeChip('🚶 Moderate', 'moderate', isPace: true),
                  const SizedBox(width: 8),
                  _buildModeChip('🏃 Fast', 'fast', isPace: true),
                ],
              ),

              const SizedBox(height: 40),

              // Generate Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _generateItinerary,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Itinerary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 20, color: AppColors.primaryOrange),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  time.format(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(String label, String value, {bool isPace = false}) {
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryOrange.withOpacity(0.15)
                : Theme.of(context).inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryOrange
                  : AppColors.neutral200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.primaryOrange
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
