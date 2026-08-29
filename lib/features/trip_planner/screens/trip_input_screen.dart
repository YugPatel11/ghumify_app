import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/utils/image_resolver.dart';
import '../../../core/widgets/selectable_chip.dart';

class TripInputScreen extends StatefulWidget {
  const TripInputScreen({super.key});

  @override
  State<TripInputScreen> createState() => _TripInputScreenState();
}

class _TripInputScreenState extends State<TripInputScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _locationService = LocationService();
  final _placesService = PlacesService();

  int _currentStep = 0;
  static const int _totalSteps = 4;
  late AnimationController _progressController;

  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String _travelMode = 'driving';
  String _pace = 'moderate';
  final Set<String> _selectedInterests = {'Famous Places', 'Local Food'};
  bool _isDetectingLocation = false;
  List<Map<String, String>> _citySuggestions = [];
  bool _showSuggestions = false;
  String _heroImage = ImageResolver.getHeroImage('India');

  // New fields
  final _ageController = TextEditingController();
  final _budgetController = TextEditingController();
  int _travelers = 1;

  // Date range for multi-day trips
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int get _numberOfDays => _endDate.difference(_startDate).inDays + 1;
  bool get _isMultiDay => _numberOfDays > 1;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _updateProgress();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null && extra['city'] != null) {
        _cityController.text = extra['city'] as String;
        _updateHeroImage(extra['city'] as String);
      }
    });
  }

  void _updateProgress() {
    _progressController.animateTo((_currentStep + 1) / _totalSteps, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _ageController.dispose();
    _budgetController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _updateProgress();
    } else {
      _generateItinerary();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _updateProgress();
    } else {
      context.pop();
    }
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
                  primary: AppColors.brandDeep,
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
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one interest', style: TextStyle(color: Colors.white))),
      );
      return;
    }

    // Show crafting loading state
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.brandDeep,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _CraftingLoadingState();
      },
    );

    final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    // Simulate crafting time, then route
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      if (_isMultiDay) {
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
          'age': int.tryParse(_ageController.text),
          'budget': int.tryParse(_budgetController.text),
          'travelers': _travelers,
        };
        context.pushReplacement('/multi-day-itinerary', extra: data);
      } else {
        final data = {
          'city': _cityController.text.trim(),
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
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Craft Itinerary'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.text),
          ),
          onPressed: _prevStep,
        ),
      ),
      body: Column(
        children: [
          // Dynamic Header Image
          SizedBox(
            height: 240,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: Image.network(
                    _heroImage,
                    key: ValueKey<String>(_heroImage),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.bg],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _progressController.value,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        minHeight: 4,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildCurrentStep(key: ValueKey<int>(_currentStep)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.lg),
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandDeep,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
              elevation: 0,
            ),
            child: Text(
              _currentStep == _totalSteps - 1 ? 'Craft My Itinerary' : 'Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep({required Key key}) {
    switch (_currentStep) {
      case 0: return _buildStep1Destination(key: key);
      case 1: return _buildStep2Interests(key: key);
      case 2: return _buildStep3Pace(key: key);
      case 3: return _buildStep4Details(key: key);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Destination({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(AppTokens.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where to?',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: AppTokens.md),
            // City Input
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'City name',
                      prefixIcon: const Icon(Icons.location_city, color: AppColors.textSoft),
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
                    ),
                    onChanged: _searchCity,
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: AppTokens.sm),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardAlt,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: _isDetectingLocation ? null : _detectLocation,
                    icon: _isDetectingLocation
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, color: AppColors.textSoft),
                  ),
                ),
              ],
            ),
            if (_showSuggestions) ...[
              const SizedBox(height: AppTokens.xs),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppTokens.radiusMd), border: Border.all(color: AppColors.border)),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _citySuggestions.length.clamp(0, 4),
                  itemBuilder: (context, index) {
                    final suggestion = _citySuggestions[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSoft),
                      title: Text(suggestion['description'] ?? '', style: const TextStyle(color: AppColors.text, fontSize: 14)),
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
            const SizedBox(height: AppTokens.xl),
            
            Text(
              'When?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: AppTokens.md),
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.all(AppTokens.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.brandDeep),
                    const SizedBox(width: AppTokens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isMultiDay ? '${_formatDate(_startDate)} — ${_formatDate(_endDate)}' : _formatDate(_startDate),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isMultiDay ? '$_numberOfDays days trip' : 'Single day trip',
                            style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.xl),
            
            Text(
              'Daily Hours',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: AppTokens.md),
            Row(
              children: [
                Expanded(child: _buildTimePicker(label: 'Start Time', time: _startTime, onTap: () => _pickTime(true))),
                const SizedBox(width: AppTokens.md),
                Expanded(child: _buildTimePicker(label: 'End Time', time: _endTime, onTap: () => _pickTime(false))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Interests({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(AppTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you love?',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: AppTokens.sm),
          Text(
            'Select what you want to experience on this trip.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSoft),
          ),
          const SizedBox(height: AppTokens.xl),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppConstants.interestTags.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return SelectableChip(
                label: interest,
                icon: _getIconForInterest(interest),
                isSelected: isSelected,
                activeColor: AppColors.brandDeep,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedInterests.remove(interest);
                    } else {
                      _selectedInterests.add(interest);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Pace({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(AppTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Travel details',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: AppTokens.xl),
          
          Text('HOW DO YOU WANT TO GET AROUND?', style: _sectionHeaderStyle()),
          const SizedBox(height: AppTokens.md),
          Row(
            children: [
              _buildSelectorBox('Driving', 'driving', Icons.directions_car, _travelMode == 'driving', (v) => setState(() => _travelMode = v)),
              const SizedBox(width: AppTokens.sm),
              _buildSelectorBox('Walking', 'walking', Icons.directions_walk, _travelMode == 'walking', (v) => setState(() => _travelMode = v)),
              const SizedBox(width: AppTokens.sm),
              _buildSelectorBox('Transit', 'transit', Icons.directions_transit, _travelMode == 'transit', (v) => setState(() => _travelMode = v)),
            ],
          ),
          
          const SizedBox(height: AppTokens.xxl),
          
          Text('PREFERRED PACE?', style: _sectionHeaderStyle()),
          const SizedBox(height: AppTokens.md),
          Row(
            children: [
              _buildSelectorBox('Relaxed', 'relaxed', Icons.spa, _pace == 'relaxed', (v) => setState(() => _pace = v)),
              const SizedBox(width: AppTokens.sm),
              _buildSelectorBox('Moderate', 'moderate', Icons.hiking, _pace == 'moderate', (v) => setState(() => _pace = v)),
              const SizedBox(width: AppTokens.sm),
              _buildSelectorBox('Fast', 'fast', Icons.flash_on, _pace == 'fast', (v) => setState(() => _pace = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Details({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(AppTokens.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A few details',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: AppTokens.xl),
            
            Text('HOW MANY TRAVELERS?', style: _sectionHeaderStyle()),
            const SizedBox(height: AppTokens.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: AppTokens.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Travelers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSoft),
                        onPressed: () {
                          if (_travelers > 1) setState(() => _travelers--);
                        },
                      ),
                      Text('$_travelers', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.brandDeep),
                        onPressed: () {
                          if (_travelers < 20) setState(() => _travelers++);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.xxl),

            Text('YOUR AGE?', style: _sectionHeaderStyle()),
            const SizedBox(height: AppTokens.sm),
            const Text('Helps us recommend age-appropriate activities and experiences.', style: TextStyle(fontSize: 13, color: AppColors.textSoft)),
            const SizedBox(height: AppTokens.md),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. 25',
                prefixIcon: const Icon(Icons.cake, color: AppColors.textSoft),
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
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final age = int.tryParse(value);
                  if (age == null || age < 1 || age > 120) return 'Invalid age';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTokens.xxl),

            Text('TOTAL BUDGET? (IN-CITY EXPENSES)', style: _sectionHeaderStyle()),
            const SizedBox(height: AppTokens.sm),
            const Text('Enter budget in INR (₹) for hotels, food, and activities. Leave blank if flexible.', style: TextStyle(fontSize: 13, color: AppColors.textSoft)),
            const SizedBox(height: AppTokens.md),
            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. 10000',
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600),
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
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final budget = int.tryParse(value);
                  if (budget == null || budget < 0) return 'Invalid budget';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _sectionHeaderStyle() {
    return const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.textSoft);
  }

  Widget _buildSelectorBox(String label, String value, IconData icon, bool isSelected, Function(String) onSelect) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandDeep : Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: isSelected ? AppColors.brandDeep : AppColors.border),
            boxShadow: isSelected ? [BoxShadow(color: AppColors.brandDeep.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: isSelected ? Colors.white : AppColors.textSoft),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  Widget _buildTimePicker({required String label, required TimeOfDay time, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTokens.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSoft, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(time.format(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
  
  IconData _getIconForInterest(String interest) {
    switch (interest.toLowerCase()) {
      case 'famous places': return Icons.account_balance;
      case 'local food': return Icons.restaurant;
      case 'shopping': return Icons.shopping_bag;
      case 'nature': return Icons.park;
      case 'culture': return Icons.theater_comedy;
      case 'temples': return Icons.temple_hindu;
      case 'adventure': return Icons.paragliding;
      case 'photography': return Icons.camera_alt;
      case 'nightlife': return Icons.nightlife;
      case 'history': return Icons.history_edu;
      default: return Icons.star_border;
    }
  }
}

class _CraftingLoadingState extends StatefulWidget {
  const _CraftingLoadingState();
  @override
  State<_CraftingLoadingState> createState() => _CraftingLoadingStateState();
}

class _CraftingLoadingStateState extends State<_CraftingLoadingState> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandDeep,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _controller,
              child: const Icon(Icons.explore_outlined, size: 64, color: AppColors.accent),
            ),
            const SizedBox(height: 32),
            const Text(
              'Crafting your\nperfect journey...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'Analyzing millions of possibilities',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
