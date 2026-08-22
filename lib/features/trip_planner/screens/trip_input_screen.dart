import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/location_service.dart';

class TripInputScreen extends StatefulWidget {
  const TripInputScreen({super.key});

  @override
  State<TripInputScreen> createState() => _TripInputScreenState();
}

class _TripInputScreenState extends State<TripInputScreen> {
  final _geminiService = GeminiService();
  final _locationService = LocationService();
  final _cityController = TextEditingController();

  int _days = 2;
  String _interests = 'Culture, Food, Heritage';
  bool _isLoading = false;

  final List<String> _commonInterests = [
    'Culture',
    'Food',
    'Heritage',
    'Nature',
    'Shopping',
    'Adventure',
    'Temples',
    'Photography',
  ];
  
  final Set<String> _selectedInterests = {'Culture', 'Food', 'Heritage'};

  @override
  void initState() {
    super.initState();
    _loadCurrentCity();
  }

  Future<void> _loadCurrentCity() async {
    try {
      final city = await _locationService.getCurrentCity();
      if (mounted && _cityController.text.isEmpty) {
        _cityController.text = city;
      }
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null && extra['city'] != null) {
        _cityController.text = extra['city'];
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        if (_selectedInterests.length > 1) {
          _selectedInterests.remove(interest);
        }
      } else {
        _selectedInterests.add(interest);
      }
      _interests = _selectedInterests.join(', ');
    });
  }

  Future<void> _generateItinerary() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a destination city'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prompt = '''
Create a detailed, day-by-day $_days-day travel itinerary for $city, India.
Focus on these interests: $_interests.
Format the response using Markdown. 
Include timing, exact places to visit, and local food recommendations.
''';
      final result = await _geminiService.generateText(prompt);

      if (mounted) {
        setState(() => _isLoading = false);
        context.push('/itinerary', extra: {
          'city': city,
          'days': _days,
          'itinerary': result,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate itinerary: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Plan Your Trip'),
        backgroundColor: AppColors.bg,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Design Your Perfect Journey',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us where and what you love, and our AI will craft a custom itinerary.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSoft,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Destination
                  _buildSectionLabel(Icons.location_on, 'Destination'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Jaipur, Varanasi, Goa',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Duration
                  _buildSectionLabel(Icons.calendar_today, 'Duration'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppTokens.shadow(level: 1),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$_days Days',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDeep,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.brandSoft,
                                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                              ),
                              child: const Text(
                                'Recommended: 2-5 days',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.brand,
                            inactiveTrackColor: AppColors.border,
                            thumbColor: AppColors.brand,
                            overlayColor: AppColors.brand.withOpacity(0.12),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _days.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _days.toString(),
                            onChanged: (val) => setState(() => _days = val.toInt()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Interests
                  _buildSectionLabel(Icons.favorite_border, 'Your Interests'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: _commonInterests.map((interest) {
                      final isSelected = _selectedInterests.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        onSelected: (_) => _toggleInterest(interest),
                        selectedColor: AppColors.brand,
                        backgroundColor: AppColors.card,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.text,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                          side: BorderSide(
                            color: isSelected ? AppColors.brand : AppColors.border,
                            width: AppTokens.borderMedium,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        showCheckmark: true,
                        checkmarkColor: Colors.white,
                      ),
                    }).toList(),
                  ),
                  const SizedBox(height: 48),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.cherryGradient,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        boxShadow: AppTokens.coloredShadow(AppColors.brand, level: 2),
                      ),
                      child: ElevatedButton(
                        onPressed: _generateItinerary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.auto_awesome, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Generate Itinerary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brand, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.cherryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTokens.coloredShadow(AppColors.brand, level: 2),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Crafting your magic itinerary...',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Analyzing best routes, foods, and spots.',
            style: TextStyle(color: AppColors.textSoft),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              color: AppColors.brand,
              backgroundColor: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}
