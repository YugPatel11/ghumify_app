import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/services/weather_service.dart';

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
      return _buildShimmer(context);
    }

    if (weather == null) {
      return _buildUnavailable(context);
    }

    final gradientColors = _getGradientColors(weather!.condition);

    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: AppTokens.coloredShadow(gradientColors.first, level: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      WeatherService.getWeatherEmoji(weather!.condition),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: AppTokens.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weather!.temperatureDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          weather!.conditionDescription,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.md),
                Row(
                  children: [
                    _buildWeatherDetail(
                      Icons.water_drop_outlined,
                      '${weather!.humidity}%',
                    ),
                    const SizedBox(width: AppTokens.lg),
                    _buildWeatherDetail(
                      Icons.air,
                      '${weather!.windSpeed.toStringAsFixed(1)} m/s',
                    ),
                    const SizedBox(width: AppTokens.lg),
                    _buildWeatherDetail(
                      Icons.thermostat_outlined,
                      'Feels ${weather!.feelsLike.round()}°',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return AppColors.premiumDarkGradient.colors.take(2).toList();
      case 'clouds':
        return const [Color(0xFF8CA5B7), Color(0xFF678196)];
      case 'rain':
      case 'drizzle':
        return const [Color(0xFF5D7BB2), Color(0xFF405D96)];
      case 'thunderstorm':
        return const [Color(0xFF4A4E69), Color(0xFF22223B)];
      default:
        return AppColors.tealGradient.colors.take(2).toList();
    }
  }

  Widget _buildShimmer(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.textMuted),
          const SizedBox(width: AppTokens.md),
          const Text(
            'Weather data unavailable',
            style: TextStyle(
              color: AppColors.textSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
