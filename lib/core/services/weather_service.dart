import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';
import '../constants/app_constants.dart';
import '../models/weather_model.dart';

/// Service for fetching weather data from OpenWeatherMap API
class WeatherService {
  static String get _baseUrl => AppConstants.weatherBaseUrl;
  static String get _apiKey => ApiKeys.openWeatherMapApiKey;

  /// Get current weather for a city
  Future<WeatherModel> getCurrentWeather(String city) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockWeather(city);
  }

  /// Get current weather by coordinates
  Future<WeatherModel> getCurrentWeatherByCoords(
      double lat, double lon) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockWeather('Mock City');
  }

  /// Get 5-day forecast for a city
  Future<ForecastModel> getForecast(String city) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockForecast(city);
  }

  /// Get 5-day forecast by coordinates
  Future<ForecastModel> getForecastByCoords(double lat, double lon) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockForecast('Mock City');
  }

  WeatherModel _getMockWeather(String city) {
    return WeatherModel(
      city: city,
      temperature: 28.5,
      feelsLike: 30.0,
      tempMin: 25.0,
      tempMax: 32.0,
      humidity: 65,
      condition: 'Clear',
      conditionDescription: 'clear sky',
      iconCode: '01d',
      windSpeed: 4.5,
      visibility: 10000,
      timestamp: DateTime.now(),
    );
  }

  ForecastModel _getMockForecast(String city) {
    final List<WeatherModel> hourly = [];
    final now = DateTime.now();
    for (int i = 0; i < 40; i++) {
      hourly.add(WeatherModel(
        city: city,
        temperature: 25.0 + (i % 5),
        feelsLike: 26.0 + (i % 5),
        tempMin: 24.0,
        tempMax: 30.0,
        humidity: 60 + (i % 10),
        condition: i % 3 == 0 ? 'Clouds' : 'Clear',
        conditionDescription: i % 3 == 0 ? 'broken clouds' : 'clear sky',
        iconCode: i % 3 == 0 ? '04d' : '01d',
        windSpeed: 3.0 + (i % 3),
        timestamp: now.add(Duration(hours: i * 3)),
      ));
    }
    return ForecastModel(city: city, hourly: hourly);
  }

  /// Generate weather-based suggestions for "What to Carry"
  List<String> getWeatherCarrySuggestions(WeatherModel weather) {
    final suggestions = <String>[];

    if (weather.isRainy) {
      suggestions.addAll([
        '☔ Umbrella or raincoat',
        '👟 Waterproof footwear',
        '🎒 Waterproof bag cover',
      ]);
    }

    if (weather.isHot) {
      suggestions.addAll([
        '🧴 Sunscreen (SPF 50+)',
        '🧢 Cap or hat',
        '💧 Water bottle (stay hydrated!)',
        '🕶️ Sunglasses',
      ]);
    }

    if (weather.isCold) {
      suggestions.addAll([
        '🧥 Warm jacket or sweater',
        '🧣 Scarf or muffler',
        '☕ Thermos with hot beverage',
      ]);
    }

    if (weather.isWindy) {
      suggestions.add('🧥 Windbreaker jacket');
    }

    if (weather.humidity > 80) {
      suggestions.addAll([
        '💧 Extra water',
        '🧻 Tissues or handkerchief',
      ]);
    }

    // Always recommend
    suggestions.addAll([
      '📱 Fully charged phone',
      '💰 Some cash for local vendors',
    ]);

    return suggestions;
  }

  /// Get weather icon emoji based on condition
  static String getWeatherEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
      case 'haze':
        return '🌫️';
      default:
        return '🌤️';
    }
  }
}

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);

  @override
  String toString() => message;
}
