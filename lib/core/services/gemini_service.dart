import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/api_keys.dart';
import '../models/itinerary_model.dart';
import '../models/weather_model.dart';
import '../models/place_model.dart';

/// Service for generating AI-powered itineraries using Google Gemini
class GeminiService {
  int _currentKeyIndex = 0;

  GeminiService();

  /// Helper to execute a Generative AI call with automatic API key rotation on failure
  Future<String> _executeWithFailover(String prompt) async {
    for (int i = 0; i < ApiKeys.geminiApiKeys.length; i++) {
      try {
        final apiKey = ApiKeys.geminiApiKeys[_currentKeyIndex];
        if (apiKey.startsWith('YOUR_GEMINI_')) {
          throw Exception('API key not configured.');
        }

        final model = GenerativeModel(
          model: 'gemini-2.5-pro',
          apiKey: apiKey,
        );

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        
        if (response.text != null) {
          return response.text!;
        }
      } catch (e) {
        print('Gemini API key $_currentKeyIndex failed: $e');
        // Rotate to the next key
        _currentKeyIndex = (_currentKeyIndex + 1) % ApiKeys.geminiApiKeys.length;
      }
    }
    throw GeminiException('All Gemini API keys failed.');
  }

  /// Generate a complete itinerary based on user inputs
  Future<ItineraryModel> generateItinerary({
    required String userId,
    required String city,
    required String date,
    required String startTime,
    required String endTime,
    required List<String> interests,
    required String travelMode,
    required String pace,
    WeatherModel? weather,
    List<PlaceModel>? knownPlaces,
  }) async {
    final prompt = _buildItineraryPrompt(
      city: city,
      date: date,
      startTime: startTime,
      endTime: endTime,
      interests: interests,
      travelMode: travelMode,
      pace: pace,
      weather: weather,
      knownPlaces: knownPlaces,
    );

    try {
      final responseText = await _executeWithFailover(prompt);
      return _parseItineraryResponse(
        responseText: responseText,
        userId: userId,
        city: city,
        date: date,
        startTime: startTime,
        endTime: endTime,
        interests: interests,
        travelMode: travelMode,
        pace: pace,
        weather: weather,
      );
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiException('Failed to generate itinerary: $e');
    }
  }

  /// Build a structured prompt for itinerary generation
  String _buildItineraryPrompt({
    required String city,
    required String date,
    required String startTime,
    required String endTime,
    required List<String> interests,
    required String travelMode,
    required String pace,
    WeatherModel? weather,
    List<PlaceModel>? knownPlaces,
  }) {
    final interestStr = interests.join(', ');
    final paceDesc = pace == 'relaxed'
        ? 'relaxed (more time at each stop, longer breaks)'
        : pace == 'fast'
            ? 'fast-paced (maximize places visited)'
            : 'moderate (balanced between exploring and resting)';

    String weatherContext = '';
    if (weather != null) {
      weatherContext = '''
WEATHER CONDITIONS for $city today:
- Temperature: ${weather.temperatureDisplay} (feels like ${weather.feelsLike.round()}°C)
- Condition: ${weather.conditionDescription}
- Humidity: ${weather.humidity}%
- Wind: ${weather.windSpeed} m/s
${weather.isRainy ? '⚠️ Rain expected — prefer indoor activities or covered areas.' : ''}
${weather.isHot ? '⚠️ Very hot — schedule outdoor activities for early morning or evening.' : ''}
''';
    }

    String placesContext = '';
    if (knownPlaces != null && knownPlaces.isNotEmpty) {
      placesContext = '''
KNOWN PLACES in $city (use these real places with accurate coordinates):
${knownPlaces.map((p) => '- ${p.name} (${p.category}) at [${p.latitude}, ${p.longitude}]${p.rating != null ? ' Rating: ${p.rating}' : ''}').join('\n')}
''';
    }

    return '''
You are a travel planning expert for Indian cities. Generate a detailed, time-boxed travel itinerary.

INPUTS:
- City: $city
- Date: $date
- Available time: $startTime to $endTime
- Interests: $interestStr
- Travel mode: $travelMode
- Pace: $paceDesc

$weatherContext
$placesContext

RULES:
1. Create a sequential, time-boxed itinerary from $startTime to $endTime.
2. Include travel time between stops (realistic for $travelMode in $city).
3. Include famous tourist places, local food spots, and markets based on interests.
4. Account for opening hours of places.
5. Add tips for each stop (best photo spots, must-try items, cultural etiquette).
6. Suggest what to carry based on weather and place types.
7. Give the full itinerary as JSON in this EXACT format:

{
  "aiSummary": "Brief overview of the day plan in 2-3 sentences",
  "stops": [
    {
      "name": "Place Name",
      "type": "place|food|market|travel|break",
      "startTime": "HH:MM",
      "endTime": "HH:MM",
      "durationMinutes": 90,
      "latitude": 22.7196,
      "longitude": 75.8577,
      "description": "What to see/do here",
      "travelMode": "driving",
      "travelMinutes": 15,
      "tips": ["Tip 1", "Tip 2"]
    }
  ],
  "whatToCarry": ["Item 1", "Item 2", "Item 3"],
  "weatherSummary": "Brief weather note for the day"
}

IMPORTANT:
- Use REAL places, REAL coordinates, and REAL food items famous in $city.
- Do NOT invent fictional places.
- Include at least one local food recommendation.
- Travel time between stops should be realistic.
- Output ONLY valid JSON, no markdown formatting, no code blocks.
''';
  }

  /// Parse the AI response into an ItineraryModel
  ItineraryModel _parseItineraryResponse({
    required String responseText,
    required String userId,
    required String city,
    required String date,
    required String startTime,
    required String endTime,
    required List<String> interests,
    required String travelMode,
    required String pace,
    WeatherModel? weather,
  }) {
    try {
      // Clean up the response — remove markdown code blocks if present
      String cleanJson = responseText.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final data = json.decode(cleanJson) as Map<String, dynamic>;

      final stops = (data['stops'] as List? ?? []).map((s) {
        return ItineraryStop.fromMap(s as Map<String, dynamic>);
      }).toList();

      // Calculate total duration
      int totalMinutes = 0;
      if (stops.isNotEmpty) {
        final first = _parseTime(stops.first.startTime);
        final last = _parseTime(stops.last.endTime);
        totalMinutes = last.difference(first).inMinutes;
      }

      return ItineraryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        city: city,
        date: date,
        startTime: startTime,
        endTime: endTime,
        totalDurationMinutes: totalMinutes,
        interests: interests,
        travelMode: travelMode,
        pace: pace,
        stops: stops,
        weatherSummary:
            data['weatherSummary'] as String? ?? weather?.conditionDescription,
        whatToCarry: List<String>.from(data['whatToCarry'] ?? []),
        aiSummary: data['aiSummary'] as String?,
      );
    } catch (e) {
      throw GeminiException('Failed to parse itinerary response: $e\nResponse was: $responseText');
    }
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// Generate place history/description using Gemini
  Future<String> generatePlaceHistory({
    required String placeName,
    required String city,
  }) async {
    final prompt = 'Write a concise, engaging historical and cultural description (around 60-80 words) for $placeName in $city. Make it sound like a premium travel magazine feature.';
    try {
      return await _executeWithFailover(prompt);
    } catch (e) {
      return 'Editorial information is currently unavailable due to an error: $e';
    }
  }

  /// Generate "What to Carry" suggestions based on context
  Future<List<String>> generateCarrySuggestions({
    required String city,
    required List<String> placeTypes,
    WeatherModel? weather,
    required String timeOfDay, // morning, afternoon, evening
  }) async {
    final prompt = 'List exactly 5 short, emoji-prefixed items to carry for a trip to $city during the $timeOfDay. Weather is ${weather?.conditionDescription ?? "unknown"}. Places visiting: ${placeTypes.join(", ")}. Return only the 5 lines of text, no other formatting.';
    try {
      final response = await _executeWithFailover(prompt);
      return response.split('\n').where((line) => line.trim().isNotEmpty).take(5).toList();
    } catch (e) {
      return [
        '📱 Fully charged phone',
        '💧 Water bottle',
        '💰 Some cash',
        '🧴 Sunscreen',
        '🎒 Comfortable backpack',
      ];
    }
  }
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => message;
}
