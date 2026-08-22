import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';

class PopularCities extends StatelessWidget {
  const PopularCities({super.key});

  static const List<_CityData> _cities = [
    _CityData('Jaipur', 'The Pink City', '🏰', [Color(0xFFE91E63), Color(0xFFC2185B)]),
    _CityData('Varanasi', 'The Spiritual Capital', '🛕', [Color(0xFFFF9800), Color(0xFFE65100)]),
    _CityData('Udaipur', 'City of Lakes', '🏞️', [Color(0xFF2196F3), Color(0xFF0D47A1)]),
    _CityData('Indore', 'Food Capital of India', '🍜', [Color(0xFF4CAF50), Color(0xFF1B5E20)]),
    _CityData('Goa', 'Beach Paradise', '🏖️', [Color(0xFF00BCD4), Color(0xFF006064)]),
    _CityData('Agra', 'City of Taj', '🕌', [Color(0xFF9C27B0), Color(0xFF4A148C)]),
    _CityData('Delhi', 'Heart of India', '🏛️', [Color(0xFF795548), Color(0xFF3E2723)]),
    _CityData('Mumbai', 'City of Dreams', '🌆', [Color(0xFF607D8B), Color(0xFF263238)]),
    _CityData('Rishikesh', 'Yoga Capital', '🧘', [Color(0xFF8BC34A), Color(0xFF33691E)]),
    _CityData('Mysore', 'City of Palaces', '👑', [Color(0xFFFFEB3B), Color(0xFFF57F17)]),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _cities.length,
        itemBuilder: (context, index) {
          final city = _cities[index];
          return GestureDetector(
            onTap: () {
              context.push('/plan-trip', extra: {'city': city.name});
            },
            child: Container(
              width: 130,
              margin: EdgeInsets.only(right: index < _cities.length - 1 ? 12 : 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: city.gradientColors,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: city.gradientColors.first.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background emoji
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Text(
                      city.emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                  // Content
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          city.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CityData {
  final String name;
  final String subtitle;
  final String emoji;
  final List<Color> gradientColors;

  const _CityData(this.name, this.subtitle, this.emoji, this.gradientColors);
}
