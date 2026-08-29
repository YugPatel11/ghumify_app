import 'dart:convert';
import 'gemini_rest_client.dart';
import '../models/itinerary_model.dart';
import '../models/multi_day_itinerary_model.dart';
import '../models/weather_model.dart';
import '../models/place_model.dart';
import '../models/chat_message_model.dart';

/// Service for generating AI-powered itineraries and handling chat using Google Gemini.
///
/// Uses [GeminiRestClient] for direct REST API calls with multi-model
/// support, automatic key rotation, and model fallback.
class GeminiService {
  final GeminiRestClient _client = GeminiRestClient();

  GeminiService();

  // ═══════════════════════════════════════════════════════
  // SINGLE-DAY ITINERARY
  // ═══════════════════════════════════════════════════════

  /// Generate a complete single-day itinerary based on user inputs
  Future<ItineraryModel> generateItinerary({
    required String userId,
    required String city,
    required String date,
    required String startTime,
    required String endTime,
    required List<String> interests,
    required String travelMode,
    required String pace,
    int? age,
    int? travelers,
    int? budget,
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
      age: age,
      travelers: travelers,
      budget: budget,
      weather: weather,
      knownPlaces: knownPlaces,
    );

    try {
      final responseText = await _client.generateContent(
        prompt: prompt,
        taskType: GeminiTaskType.complexPlanning,
      );
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
        age: age,
        travelers: travelers,
        budget: budget,
        weather: weather,
      );
    } catch (e) {
      if (e is GeminiRestException) rethrow;
      throw GeminiRestException('Failed to generate itinerary: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // MULTI-DAY ITINERARY
  // ═══════════════════════════════════════════════════════

  /// Generate a complete multi-day itinerary
  Future<MultiDayItineraryModel> generateMultiDayItinerary({
    required String userId,
    required String city,
    required String startDate,
    required String endDate,
    required int numberOfDays,
    required String dailyStartTime,
    required String dailyEndTime,
    required List<String> interests,
    required String travelMode,
    required String pace,
    int? age,
    int? travelers,
    int? budget,
    WeatherModel? weather,
    List<PlaceModel>? knownPlaces,
  }) async {
    final prompt = _buildMultiDayPrompt(
      city: city,
      startDate: startDate,
      endDate: endDate,
      numberOfDays: numberOfDays,
      dailyStartTime: dailyStartTime,
      dailyEndTime: dailyEndTime,
      interests: interests,
      travelMode: travelMode,
      pace: pace,
      age: age,
      travelers: travelers,
      budget: budget,
      weather: weather,
      knownPlaces: knownPlaces,
    );

    try {
      final responseText = await _client.generateContent(
        prompt: prompt,
        taskType: GeminiTaskType.complexPlanning,
      );
      return _parseMultiDayResponse(
        responseText: responseText,
        userId: userId,
        city: city,
        startDate: startDate,
        endDate: endDate,
        numberOfDays: numberOfDays,
        dailyStartTime: dailyStartTime,
        dailyEndTime: dailyEndTime,
        interests: interests,
        travelMode: travelMode,
        pace: pace,
        age: age,
        travelers: travelers,
        budget: budget,
        weather: weather,
      );
    } catch (e) {
      if (e is GeminiRestException) rethrow;
      throw GeminiRestException('Failed to generate multi-day itinerary: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // AI CHAT
  // ═══════════════════════════════════════════════════════

  /// Chat about an itinerary — can return text or a modified itinerary.
  ///
  /// [currentItinerary] is the JSON representation of the current itinerary.
  /// [chatHistory] is the list of previous messages in the conversation.
  /// [userMessage] is the new message from the user.
  ///
  /// Returns a [ChatMessageModel] with either text content or an updated itinerary.
  Future<ChatMessageModel> chatAboutItinerary({
    required String userMessage,
    required Map<String, dynamic> currentItinerary,
    required List<ChatMessageModel> chatHistory,
    bool isMultiDay = false,
  }) async {
    final prompt = _buildChatPrompt(
      userMessage: userMessage,
      currentItinerary: currentItinerary,
      isMultiDay: isMultiDay,
    );

    // Build conversation history for context
    final conversationHistory = chatHistory
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'content': m.content,
            })
        .toList();

    try {
      final responseText = await _client.generateContent(
        prompt: prompt,
        taskType: _isModificationRequest(userMessage)
            ? GeminiTaskType.fastModification
            : GeminiTaskType.chat,
        conversationHistory:
            conversationHistory.isNotEmpty ? conversationHistory : null,
      );

      // Try to parse as JSON (modified itinerary)
      Map<String, dynamic>? updatedItinerary;
      String textContent = responseText;

      try {
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

        // Check if response contains JSON itinerary data
        if (cleanJson.startsWith('{') &&
            (cleanJson.contains('"stops"') || cleanJson.contains('"days"'))) {
          final parsed = json.decode(cleanJson) as Map<String, dynamic>;
          updatedItinerary = parsed;
          textContent = parsed['chatMessage'] as String? ??
              parsed['aiSummary'] as String? ??
              'I\'ve updated your itinerary based on your request.';
        }
      } catch (_) {
        // Not JSON — treat as plain text response
      }

      return ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: textContent,
        updatedItinerary: updatedItinerary,
      );
    } catch (e) {
      String errorMessage;
      if (e is GeminiRestException) {
        errorMessage = 'The AI service is temporarily unavailable. Please try again in a moment.\n\nDetails: ${e.message}';
      } else if (e.toString().contains('TimeoutException') || e.toString().contains('SocketException')) {
        errorMessage = 'Could not reach the AI service. Please check your internet connection and try again.';
      } else {
        errorMessage = 'Sorry, something went wrong. Please try again. \nDebug: $e';
      }
      return ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: errorMessage,
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════

  /// Generate place history/description using Gemini
  Future<String> generatePlaceHistory({
    required String placeName,
    required String city,
  }) async {
    final prompt =
        'Write a concise, engaging historical and cultural description (around 60-80 words) for $placeName in $city. Make it sound like a premium travel magazine feature.';
    try {
      return await _client.generateContent(
        prompt: prompt,
        taskType: GeminiTaskType.placeInfo,
      );
    } catch (e) {
      return 'Editorial information is currently unavailable due to an error: $e';
    }
  }

  /// Generate "What to Carry" suggestions based on context
  Future<List<String>> generateCarrySuggestions({
    required String city,
    required List<String> placeTypes,
    WeatherModel? weather,
    required String timeOfDay,
  }) async {
    final prompt =
        'List exactly 5 short, emoji-prefixed items to carry for a trip to $city during the $timeOfDay. Weather is ${weather?.conditionDescription ?? "unknown"}. Places visiting: ${placeTypes.join(", ")}. Return only the 5 lines of text, no other formatting.';
    try {
      final response = await _client.generateContent(
        prompt: prompt,
        taskType: GeminiTaskType.generalQuestion,
      );
      return response
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .take(5)
          .toList();
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

  // ═══════════════════════════════════════════════════════
  // PROMPT BUILDERS
  // ═══════════════════════════════════════════════════════

  /// Check if a user message is requesting a modification
  bool _isModificationRequest(String message) {
    final modKeywords = [
      'replace',
      'remove',
      'add',
      'change',
      'swap',
      'adjust',
      'modify',
      'update',
      'delete',
      'less',
      'more',
      'relaxed',
      'packed',
      'shorter',
      'longer',
    ];
    final lower = message.toLowerCase();
    return modKeywords.any((k) => lower.contains(k));
  }

  /// Build single-day itinerary prompt
  String _buildItineraryPrompt({
    required String city,
    required String date,
    required String startTime,
    required String endTime,
    required List<String> interests,
    required String travelMode,
    required String pace,
    int? age,
    int? travelers,
    int? budget,
    WeatherModel? weather,
    List<PlaceModel>? knownPlaces,
  }) {
    final interestStr = interests.join(', ');
    final paceDesc = pace == 'relaxed'
        ? 'relaxed (more time at each stop, longer breaks)'
        : pace == 'fast'
            ? 'fast-paced (maximize places visited)'
            : 'moderate (balanced between exploring and resting)';

    String ageGroupContext = '';
    if (age != null) {
      if (age < 26) {
        ageGroupContext = 'The traveler is $age years old. Prioritize energetic, adventurous, instagrammable spots, local trends, and nightlife if appropriate, but still respect their explicit interests.';
      } else if (age < 50) {
        ageGroupContext = 'The traveler is $age years old. Balance adventure with cultural experiences and relaxation based on their interests.';
      } else {
        ageGroupContext = 'The traveler is $age years old. Prioritize comfort, scenic beauty, heritage, and easily accessible places, but still respect their explicit interests.';
      }
    }

    String budgetContext = '';
    if (budget != null && budget > 0) {
      budgetContext = 'BUDGET CONSTRAINT: The user has a total budget of ₹$budget for in-city expenses (food, transport, activities) for ${travelers ?? 1} traveler(s). You MUST estimate costs realistically and ensure the total estimated cost strictly stays within this budget. Recommend free/cheap activities if the budget is low.';
    }

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
${travelers != null ? '- Travelers: $travelers' : ''}

$ageGroupContext
$budgetContext

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
      "estimatedCost": 250,
      "tips": ["Tip 1", "Tip 2"]
    }
  ],
  "expenseSummary": {
    "food": 1000,
    "transport": 500,
    "activities": 1500,
    "other": 200,
    "total": 3200
  },
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

  /// Build multi-day itinerary prompt
  String _buildMultiDayPrompt({
    required String city,
    required String startDate,
    required String endDate,
    required int numberOfDays,
    required String dailyStartTime,
    required String dailyEndTime,
    required List<String> interests,
    required String travelMode,
    required String pace,
    int? age,
    int? travelers,
    int? budget,
    WeatherModel? weather,
    List<PlaceModel>? knownPlaces,
  }) {
    final interestStr = interests.join(', ');
    final paceDesc = pace == 'relaxed'
        ? 'relaxed (more time at each stop, longer breaks)'
        : pace == 'fast'
            ? 'fast-paced (maximize places visited)'
            : 'moderate (balanced between exploring and resting)';

    String ageGroupContext = '';
    if (age != null) {
      if (age < 26) {
        ageGroupContext = 'The traveler is $age years old. Prioritize energetic, adventurous, instagrammable spots, local trends, and nightlife if appropriate, but still respect their explicit interests.';
      } else if (age < 50) {
        ageGroupContext = 'The traveler is $age years old. Balance adventure with cultural experiences and relaxation based on their interests.';
      } else {
        ageGroupContext = 'The traveler is $age years old. Prioritize comfort, scenic beauty, heritage, and easily accessible places, but still respect their explicit interests.';
      }
    }

    String budgetContext = '';
    if (budget != null && budget > 0) {
      budgetContext = 'BUDGET CONSTRAINT: The user has a total budget of ₹$budget for in-city expenses (food, transport, activities) for ${travelers ?? 1} traveler(s) for the ENTIRE $numberOfDays-day trip. You MUST estimate costs realistically and ensure the total estimated cost strictly stays within this budget. Distribute the budget wisely across the days. Recommend free/cheap activities if the budget is low.';
    }

    String weatherContext = '';
    if (weather != null) {
      weatherContext = '''
WEATHER CONDITIONS for $city:
- Temperature: ${weather.temperatureDisplay} (feels like ${weather.feelsLike.round()}°C)
- Condition: ${weather.conditionDescription}
- Humidity: ${weather.humidity}%
${weather.isRainy ? '⚠️ Rain expected — prefer indoor activities.' : ''}
${weather.isHot ? '⚠️ Very hot — plan outdoor activities carefully.' : ''}
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
You are a travel planning expert for Indian cities. Generate a detailed $numberOfDays-DAY travel itinerary.

INPUTS:
- City: $city
- Dates: $startDate to $endDate ($numberOfDays days)
- Daily available time: $dailyStartTime to $dailyEndTime
- Interests: $interestStr
- Travel mode: $travelMode
- Pace: $paceDesc
${travelers != null ? '- Travelers: $travelers' : ''}

$ageGroupContext
$budgetContext

$weatherContext
$placesContext

MULTI-DAY PLANNING RULES:
1. Distribute places intelligently across $numberOfDays days — do NOT dump everything in Day 1.
2. Group nearby attractions together on the same day to minimize travel.
3. Avoid unnecessary backtracking — plan a logical geographic flow each day.
4. Each day should have a clear theme or area focus (e.g., "Day 1: Old City Heritage", "Day 2: Markets & Street Food").
5. Include realistic travel time between stops for $travelMode.
6. Include meal breaks (lunch + snack) each day at local food spots.
7. Account for opening hours — temples may close at noon, markets open late.
8. Pace: $paceDesc. Keep a reasonable number of stops per day.
9. Include practical tips for each stop.
10. Save the best sunset/evening activity for the end of each day.

OUTPUT FORMAT (ONLY valid JSON, no markdown, no code blocks):

{
  "overallSummary": "2-3 sentence overview of the entire trip",
  "weatherSummary": "Brief weather note",
  "whatToCarry": ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"],
  "overallExpenseSummary": {
    "food": 3000,
    "transport": 1500,
    "activities": 2500,
    "other": 500,
    "total": 7500
  },
  "days": [
    {
      "dayNumber": 1,
      "date": "$startDate",
      "aiSummary": "Theme/focus for this day in 1-2 sentences",
      "expenseSummary": {
        "food": 1000,
        "transport": 500,
        "activities": 1000,
        "other": 200,
        "total": 2700
      },
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
          "travelMode": "$travelMode",
          "travelMinutes": 15,
          "estimatedCost": 250,
          "tips": ["Tip 1", "Tip 2"]
        }
      ]
    }
  ]
}

IMPORTANT:
- Use REAL places, REAL coordinates, and REAL food items famous in $city.
- Do NOT invent fictional places.
- Each day MUST have unique stops — do NOT repeat places across days.
- Include at least one local food recommendation per day.
- Output ONLY valid JSON.
''';
  }

  /// Build chat prompt with itinerary context
  String _buildChatPrompt({
    required String userMessage,
    required Map<String, dynamic> currentItinerary,
    required bool isMultiDay,
  }) {
    final itineraryJson = json.encode(currentItinerary);

    return '''
You are a smart travel assistant for the Ghumify app. The user is viewing their ${isMultiDay ? 'multi-day' : 'single-day'} itinerary and has a question or request.

CURRENT ITINERARY:
$itineraryJson

USER MESSAGE: "$userMessage"

INSTRUCTIONS:
1. If the user is asking a QUESTION (e.g., "Is this too packed?", "What should I eat?"), respond with helpful text.
2. If the user is requesting a CHANGE (e.g., "Replace this place", "Remove activity X", "Add a food stop", "Make Day 2 more relaxed"), respond with the FULL MODIFIED ITINERARY as JSON in the exact same format as above, with an added "chatMessage" field explaining what you changed.
3. When modifying, keep all unchanged stops as-is. Only modify what the user asked for.
4. Recalculate times if you add/remove/reorder stops.
5. Use REAL places with REAL coordinates — never invent fictional places.
6. Be conversational and helpful in your text responses.

If responding with text only, just write your response as plain text.
If responding with a modified itinerary, output ONLY valid JSON (no markdown, no code blocks).
''';
  }

  // ═══════════════════════════════════════════════════════
  // PARSERS
  // ═══════════════════════════════════════════════════════

  /// Parse single-day itinerary response
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
    int? age,
    int? travelers,
    int? budget,
    WeatherModel? weather,
  }) {
    try {
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

      int totalMinutes = 0;
      if (stops.isNotEmpty) {
        final first = _parseTime(stops.first.startTime);
        final last = _parseTime(stops.last.endTime);
        totalMinutes = last.difference(first).inMinutes;
      }

      final expenseSummary = data['expenseSummary'] as Map<String, dynamic>?;
      final estimatedTotalCost = expenseSummary?['total'] as int?;
      int? remainingBudget;
      if (budget != null && budget > 0 && estimatedTotalCost != null) {
        remainingBudget = budget - estimatedTotalCost;
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
        age: age,
        travelers: travelers,
        budget: budget,
        currency: 'INR',
        estimatedTotalCost: estimatedTotalCost,
        remainingBudget: remainingBudget,
        expenseSummary: expenseSummary,
      );
    } catch (e) {
      throw GeminiRestException(
          'Failed to parse itinerary response: $e\nResponse was: $responseText');
    }
  }

  /// Parse multi-day itinerary response
  MultiDayItineraryModel _parseMultiDayResponse({
    required String responseText,
    required String userId,
    required String city,
    required String startDate,
    required String endDate,
    required int numberOfDays,
    required String dailyStartTime,
    required String dailyEndTime,
    required List<String> interests,
    required String travelMode,
    required String pace,
    int? age,
    int? travelers,
    int? budget,
    WeatherModel? weather,
  }) {
    try {
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

      final days = (data['days'] as List? ?? []).map((dayData) {
        final d = dayData as Map<String, dynamic>;
        final stops = (d['stops'] as List? ?? []).map((s) {
          return ItineraryStop.fromMap(s as Map<String, dynamic>);
        }).toList();

        final dayNumber = d['dayNumber'] as int? ?? 1;
        final dayDate = d['date'] as String? ?? startDate;

        int totalMinutes = 0;
        if (stops.isNotEmpty) {
          final first = _parseTime(stops.first.startTime);
          final last = _parseTime(stops.last.endTime);
          totalMinutes = last.difference(first).inMinutes;
        }

        final expenseSummary = d['expenseSummary'] as Map<String, dynamic>?;
        final estimatedTotalCost = expenseSummary?['total'] as int?;

        return ItineraryModel(
          id: '${DateTime.now().millisecondsSinceEpoch}_day$dayNumber',
          userId: userId,
          city: city,
          date: dayDate,
          startTime: dailyStartTime,
          endTime: dailyEndTime,
          totalDurationMinutes: totalMinutes,
          interests: interests,
          travelMode: travelMode,
          pace: pace,
          stops: stops,
          aiSummary: d['aiSummary'] as String?,
          dayNumber: dayNumber,
          expenseSummary: expenseSummary,
          estimatedTotalCost: estimatedTotalCost,
        );
      }).toList();

      final overallExpenseSummary = data['overallExpenseSummary'] as Map<String, dynamic>?;
      final estimatedTotalCost = overallExpenseSummary?['total'] as int?;
      int? remainingBudget;
      if (budget != null && budget > 0 && estimatedTotalCost != null) {
        remainingBudget = budget - estimatedTotalCost;
      }

      return MultiDayItineraryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        city: city,
        startDate: startDate,
        endDate: endDate,
        numberOfDays: numberOfDays,
        dailyStartTime: dailyStartTime,
        dailyEndTime: dailyEndTime,
        interests: interests,
        travelMode: travelMode,
        pace: pace,
        days: days,
        overallSummary: data['overallSummary'] as String?,
        weatherSummary:
            data['weatherSummary'] as String? ?? weather?.conditionDescription,
        whatToCarry: List<String>.from(data['whatToCarry'] ?? []),
        age: age,
        travelers: travelers,
        budget: budget,
        currency: 'INR',
        estimatedTotalCost: estimatedTotalCost,
        remainingBudget: remainingBudget,
        overallExpenseSummary: overallExpenseSummary,
      );
    } catch (e) {
      throw GeminiRestException(
          'Failed to parse multi-day itinerary: $e\nResponse was: $responseText');
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
}
