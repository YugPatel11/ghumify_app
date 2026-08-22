import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(weather!.condition),
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getGradientColors(weather!.condition).first.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weather!.temperatureDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          weather!.conditionDescription,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildWeatherDetail(
                      Icons.water_drop_outlined,
                      '${weather!.humidity}%',
                    ),
                    const SizedBox(width: 16),
                    _buildWeatherDetail(
                      Icons.air,
                      '${weather!.windSpeed.toStringAsFixed(1)} m/s',
                    ),
                    const SizedBox(width: 16),
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
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return [const Color(0xFF4FC3F7), const Color(0xFF0288D1)];
      case 'clouds':
        return [const Color(0xFF78909C), const Color(0xFF546E7A)];
      case 'rain':
      case 'drizzle':
        return [const Color(0xFF5C6BC0), const Color(0xFF3949AB)];
      case 'thunderstorm':
        return [const Color(0xFF37474F), const Color(0xFF263238)];
      default:
        return [AppColors.secondaryBlue, AppColors.secondaryBlueDark];
    }
  }

  Widget _buildShimmer(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.neutral400),
          const SizedBox(width: 12),
          Text(
            'Weather data unavailable',
            style: TextStyle(color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }
}
