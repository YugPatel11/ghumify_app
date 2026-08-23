import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/image_resolver.dart';

class PopularCities extends StatelessWidget {
  const PopularCities({super.key});

  static const List<_CityData> _cities = [
    _CityData('Jaipur', 'The Pink City'),
    _CityData('Paris', 'City of Love'),
    _CityData('Dubai', 'Desert Oasis'),
    _CityData('Varanasi', 'The Spiritual Capital'),
    _CityData('Agra', 'City of Taj'),
    _CityData('Delhi', 'Heart of India'),
    _CityData('Mumbai', 'City of Dreams'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280, // Taller for premium image display
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _cities.length,
        itemBuilder: (context, index) {
          final city = _cities[index];
          final imageUrl = ImageResolver.getHeroImage(city.name);

          return GestureDetector(
            onTap: () {
              context.push('/plan-trip', extra: {'city': city.name});
            },
            child: Container(
              width: 200, // Wider for hero imagery
              margin: EdgeInsets.only(right: index < _cities.length - 1 ? AppTokens.md : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                boxShadow: AppTokens.shadow(level: 2),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  // Gradient overlay for text readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0.95),
                          ],
                          stops: const [0.4, 0.7, 1.0],
                        ),
                      ),
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
                            color: AppColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          city.subtitle,
                          style: TextStyle(
                            color: AppColors.textSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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

  const _CityData(this.name, this.subtitle);
}

