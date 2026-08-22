import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';
import '../constants/app_constants.dart';
import '../models/weather_model.dart';

/// Service for fetching weather data from OpenWeatherMap API
class WeatherService {
  static const String _baseUrl = AppConstants.weatherBaseUrl;
  static const String _apiKey = ApiKeys.openWeatherMapApiKey;

  /// Get current weather for a city
  Future<WeatherModel> getCurrentWeather(String city) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/weather?q=$city,IN&appid=$_apiKey&units=metric');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherModel.fromJson(data);
      } else {
        throw WeatherException(
          'Failed to fetch weather: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is WeatherException) rethrow;
      throw WeatherException('Network error fetching weather: $e');
    }
  }

  /// Get current weather by coordinates
  Future<WeatherModel> getCurrentWeatherByCoords(
      double lat, double lon) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherModel.fromJson(data);
      } else {
        throw WeatherException(
          'Failed to fetch weather: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is WeatherException) rethrow;
      throw WeatherException('Network error fetching weather: $e');
    }
  }

  /// Get 5-day forecast for a city
  Future<ForecastModel> getForecast(String city) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/forecast?q=$city,IN&appid=$_apiKey&units=metric');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ForecastModel.fromJson(data);
      } else {
        throw WeatherException(
          'Failed to fetch forecast: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is WeatherException) rethrow;
      throw WeatherException('Network error fetching forecast: $e');
    }
  }

  /// Get 5-day forecast by coordinates
  Future<ForecastModel> getForecastByCoords(double lat, double lon) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ForecastModel.fromJson(data);
      } else {
        throw WeatherException(
          'Failed to fetch forecast: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is WeatherException) rethrow;
      throw WeatherException('Network error fetching forecast: $e');
    }
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
