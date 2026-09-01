import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/weather_model.dart';

/// Clean weather card matching the Figma design system
class WeatherCard extends StatelessWidget {
  final WeatherModel? weather;
  final bool isLoading;
  final String? city;

  const WeatherCard({
    super.key,
    this.weather,
    this.isLoading = false,
    this.city,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(AppTokens.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            ),
            SizedBox(width: AppTokens.md),
            Text(
              'Loading weather...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (weather == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: AppTokens.coloredShadow(AppColors.brand, level: 1),
      ),
      child: Row(
        children: [
          // Weather Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Center(
              child: Text(
                _getWeatherEmoji(weather!.condition),
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city ?? 'Current Location',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  weather!.conditionDescription,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${weather!.temperature.round()}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.water_drop, size: 12, color: Colors.white.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text(
                    '${weather!.humidity}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getWeatherEmoji(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
      case 'drizzle':
        return '🌧️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'haze':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }
}
