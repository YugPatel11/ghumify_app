import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

class PopularCities extends StatelessWidget {
  const PopularCities({super.key});

  static const List<_CityData> _cities = [
    _CityData('Jaipur', 'The Pink City', '🏰', AppColors.cherryGradient),
    _CityData('Varanasi', 'The Spiritual Capital', '🛕', AppColors.saffronGradient),
    _CityData('Udaipur', 'City of Lakes', '🏞️', AppColors.indigoGradient),
    _CityData('Indore', 'Food Capital of India', '🍜', AppColors.tealGradient),
    _CityData('Goa', 'Beach Paradise', '🏖️', AppColors.sunsetGradient),
    _CityData('Agra', 'City of Taj', '🕌', AppColors.roseGradient),
    _CityData('Delhi', 'Heart of India', '🏛️', AppColors.saffronGradient),
    _CityData('Mumbai', 'City of Dreams', '🌆', AppColors.indigoGradient),
    _CityData('Rishikesh', 'Yoga Capital', '🧘', AppColors.forestGradient),
    _CityData('Mysore', 'City of Palaces', '👑', AppColors.cherryGradient),
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
              margin: EdgeInsets.only(right: index < _cities.length - 1 ? AppTokens.md : 0),
              decoration: BoxDecoration(
                gradient: city.gradient,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                boxShadow: AppTokens.coloredShadow(city.gradient.colors.first, level: 1),
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
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          city.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
  final LinearGradient gradient;

  const _CityData(this.name, this.subtitle, this.emoji, this.gradient);
}
