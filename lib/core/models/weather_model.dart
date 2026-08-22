/// Weather data model from OpenWeatherMap API
class WeatherModel {
  final String city;
  final double temperature; // Celsius
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final String condition; // "Clear", "Clouds", "Rain", etc.
  final String conditionDescription; // "clear sky", "broken clouds", etc.
  final String iconCode; // "01d", "02n", etc.
  final double windSpeed; // m/s
  final int? visibility; // meters
  final DateTime timestamp;
  final DateTime? sunrise;
  final DateTime? sunset;

  WeatherModel({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.condition,
    required this.conditionDescription,
    required this.iconCode,
    required this.windSpeed,
    this.visibility,
    required this.timestamp,
    this.sunrise,
    this.sunset,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final weather = json['weather']?[0] ?? {};
    final main = json['main'] ?? {};
    final wind = json['wind'] ?? {};
    final sys = json['sys'] ?? {};

    return WeatherModel(
      city: json['name'] ?? '',
      temperature: (main['temp'] ?? 0).toDouble(),
      feelsLike: (main['feels_like'] ?? 0).toDouble(),
      tempMin: (main['temp_min'] ?? 0).toDouble(),
      tempMax: (main['temp_max'] ?? 0).toDouble(),
      humidity: main['humidity'] ?? 0,
      condition: weather['main'] ?? 'Unknown',
      conditionDescription: weather['description'] ?? '',
      iconCode: weather['icon'] ?? '01d',
      windSpeed: (wind['speed'] ?? 0).toDouble(),
      visibility: json['visibility'],
      timestamp: json['dt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000)
          : DateTime.now(),
      sunrise: sys['sunrise'] != null
          ? DateTime.fromMillisecondsSinceEpoch(sys['sunrise'] * 1000)
          : null,
      sunset: sys['sunset'] != null
          ? DateTime.fromMillisecondsSinceEpoch(sys['sunset'] * 1000)
          : null,
    );
  }

  String get iconUrl =>
      'https://openweathermap.org/img/wn/${iconCode}@2x.png';

  String get temperatureDisplay => '${temperature.round()}°C';

  bool get isRainy =>
      condition == 'Rain' ||
      condition == 'Drizzle' ||
      condition == 'Thunderstorm';

  bool get isHot => temperature > 35;

  bool get isCold => temperature < 15;

  bool get isWindy => windSpeed > 10;
}

/// 5-day forecast model
class ForecastModel {
  final String city;
  final List<WeatherModel> hourly;

  ForecastModel({
    required this.city,
    required this.hourly,
  });

  factory ForecastModel.fromJson(Map<String, dynamic> json) {
    final list = json['list'] as List? ?? [];
    final city = json['city']?['name'] ?? '';

    return ForecastModel(
      city: city,
      hourly: list.map((item) {
        final data = item as Map<String, dynamic>;
        data['name'] = city;
        return WeatherModel.fromJson(data);
      }).toList(),
    );
  }

  /// Get forecast for a specific date
  List<WeatherModel> forDate(DateTime date) {
    return hourly.where((w) {
      return w.timestamp.year == date.year &&
          w.timestamp.month == date.month &&
          w.timestamp.day == date.day;
    }).toList();
  }

  /// Get the weather summary for today
  WeatherModel? get today {
    final now = DateTime.now();
    final todayWeather = forDate(now);
    return todayWeather.isNotEmpty ? todayWeather.first : null;
  }
}
