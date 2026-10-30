import '../../models/chat_message_model.dart';
import '../translation_service.dart';
import 'candidate_source.dart';
import 'intent_parser.dart';
import 'itinerary_editor.dart';

class LocalChatAssistant {
  final CandidateSource _candidateSource = CandidateSource();
  final TranslationService _translationService = TranslationService();

  Future<ChatMessageModel> handleMessage({
    required String userMessage,
    required Map<String, dynamic> currentItinerary,
    bool isMultiDay = false,
  }) async {
    final now = DateTime.now();
    final messageId = now.millisecondsSinceEpoch.toString();

    // 1. Extract current stop names and city/coordinates
    final currentStopNames = <String>[];
    double originLat = 26.9124; // Jaipur fallback
    double originLon = 75.7873;
    String city = currentItinerary['city'] as String? ?? 'Local Area';

    if (isMultiDay) {
      final days = (currentItinerary['days'] as List? ?? []);
      for (final day in days) {
        if (day is Map) {
          final stops = (day['stops'] as List? ?? []);
          for (final s in stops) {
            if (s is Map && s['name'] is String) {
              currentStopNames.add(s['name'] as String);
              if (s['latitude'] is num && s['longitude'] is num) {
                originLat = (s['latitude'] as num).toDouble();
                originLon = (s['longitude'] as num).toDouble();
              }
            }
          }
        }
      }
    } else {
      final stops = (currentItinerary['stops'] as List? ?? []);
      for (final s in stops) {
        if (s is Map && s['name'] is String) {
          currentStopNames.add(s['name'] as String);
          if (s['latitude'] is num && s['longitude'] is num) {
            originLat = (s['latitude'] as num).toDouble();
            originLon = (s['longitude'] as num).toDouble();
          }
        }
      }
    }

    // 2. Parse Intent
    final intent = IntentParser.parse(
      message: userMessage,
      currentStopNames: currentStopNames,
    );

    // 3. Dispatch based on intent
    switch (intent.type) {
      case LocalChatIntentType.help:
        return ChatMessageModel(
          id: messageId,
          role: 'assistant',
          content: _buildHelpMessage(),
        );

      case LocalChatIntentType.addFood:
        return await _handleAddFood(
          messageId: messageId,
          currentItinerary: currentItinerary,
          isMultiDay: isMultiDay,
          city: city,
          latitude: originLat,
          longitude: originLon,
          currentStopNames: currentStopNames,
          targetDayNumber: intent.targetDayNumber,
        );

      case LocalChatIntentType.removeStop:
        if (intent.isAmbiguous || intent.targetStopIndex == null) {
          return ChatMessageModel(
            id: messageId,
            role: 'assistant',
            content: '[Offline Mode] ${intent.ambiguityReason ?? "Which stop would you like to remove? Please name the place."}',
          );
        }
        return _handleRemoveStop(
          messageId: messageId,
          currentItinerary: currentItinerary,
          isMultiDay: isMultiDay,
          targetStopIndex: intent.targetStopIndex!,
          targetDayNumber: intent.targetDayNumber,
        );

      case LocalChatIntentType.replaceStop:
        if (intent.isAmbiguous || intent.targetStopIndex == null) {
          return ChatMessageModel(
            id: messageId,
            role: 'assistant',
            content: '[Offline Mode] ${intent.ambiguityReason ?? "Which stop would you like to replace? Please specify the place name."}',
          );
        }
        return await _handleReplaceStop(
          messageId: messageId,
          currentItinerary: currentItinerary,
          isMultiDay: isMultiDay,
          city: city,
          latitude: originLat,
          longitude: originLon,
          targetStopIndex: intent.targetStopIndex!,
          currentStopNames: currentStopNames,
          targetDayNumber: intent.targetDayNumber,
        );

      case LocalChatIntentType.lessTime:
        final edit = ItineraryEditor.lessTime(
          currentItineraryMap: currentItinerary,
          isMultiDay: isMultiDay,
          targetDayNumber: intent.targetDayNumber,
        );
        return ChatMessageModel(
          id: messageId,
          role: 'assistant',
          content: '[Offline Mode] ${edit.message}',
          updatedItinerary: edit.updatedItinerary,
        );

      case LocalChatIntentType.moreRelaxed:
        final edit = ItineraryEditor.moreRelaxed(
          currentItineraryMap: currentItinerary,
          isMultiDay: isMultiDay,
          targetDayNumber: intent.targetDayNumber,
        );
        return ChatMessageModel(
          id: messageId,
          role: 'assistant',
          content: '[Offline Mode] ${edit.message}',
          updatedItinerary: edit.updatedItinerary,
        );

      case LocalChatIntentType.nearestService:
        return await _handleNearestService(
          messageId: messageId,
          latitude: originLat,
          longitude: originLon,
          serviceType: intent.serviceType ?? ServiceType.hospital,
        );

      case LocalChatIntentType.translateCached:
        return await _handleTranslateCached(
          messageId: messageId,
          text: intent.translateText ?? userMessage,
          targetLang: intent.targetLanguage ?? 'hi',
        );

      case LocalChatIntentType.queryInfo:
        return _handleQueryInfo(
          messageId: messageId,
          userMessage: userMessage,
          currentItinerary: currentItinerary,
          isMultiDay: isMultiDay,
          intent: intent,
        );

      case LocalChatIntentType.unknown:

        return ChatMessageModel(
          id: messageId,
          role: 'assistant',
          content: '[Offline Mode] I could not understand that request. Here are the actions you can take while offline:\n\n'
              '• Add a food stop: "Add food stop" or "Mujhe khana khana hai"\n'
              '• Remove a place: "Remove stop 2" or "Hawa Mahal hata do"\n'
              '• Replace a place: "Replace last stop" or "Dusra place dikhao"\n'
              '• Adjust pace: "Make it more relaxed" or "I have less time"\n'
              '• Find emergency help: "Nearest hospital" or "Police station"',
        );
    }
  }

  String _buildHelpMessage() {
    return '[Offline Mode] Assistant is running locally. You can use these commands:\n\n'
        '• "Add food stop" — inserts a verified local dining spot\n'
        '• "Remove [place name]" — drops a stop and recalculates schedule\n'
        '• "Replace [place name]" — swaps for an alternative nearby attraction\n'
        '• "I have less time" — tightens visit durations\n'
        '• "Make it more relaxed" — spaces out your itinerary\n'
        '• "Nearest hospital / police" — locates closest essential services\n\n'
        'Tap "Apply Changes to Itinerary" after any modification to update your trip.';
  }

  Future<ChatMessageModel> _handleAddFood({
    required String messageId,
    required Map<String, dynamic> currentItinerary,
    required bool isMultiDay,
    required String city,
    required double latitude,
    required double longitude,
    required List<String> currentStopNames,
    int? targetDayNumber,
  }) async {
    final candidates = await _candidateSource.getFoodCandidates(
      latitude: latitude,
      longitude: longitude,
      city: city,
      excludedPlaceNames: currentStopNames,
    );

    if (candidates.isEmpty) {
      return ChatMessageModel(
        id: messageId,
        role: 'assistant',
        content: '[Offline Mode] No verified food places were found in local offline storage for this location. Your itinerary remains unchanged.',
      );
    }

    final chosen = candidates.first;
    final edit = ItineraryEditor.addFoodStop(
      currentItineraryMap: currentItinerary,
      foodCandidate: chosen,
      isMultiDay: isMultiDay,
      targetDayNumber: targetDayNumber,
    );

    return ChatMessageModel(
      id: messageId,
      role: 'assistant',
      content: '[Offline Mode] ${edit.message}',
      updatedItinerary: edit.updatedItinerary,
    );
  }

  ChatMessageModel _handleRemoveStop({
    required String messageId,
    required Map<String, dynamic> currentItinerary,
    required bool isMultiDay,
    required int targetStopIndex,
    int? targetDayNumber,
  }) {
    final edit = ItineraryEditor.removeStop(
      currentItineraryMap: currentItinerary,
      stopIndex: targetStopIndex,
      isMultiDay: isMultiDay,
      targetDayNumber: targetDayNumber,
    );

    return ChatMessageModel(
      id: messageId,
      role: 'assistant',
      content: '[Offline Mode] ${edit.message}',
      updatedItinerary: edit.updatedItinerary,
    );
  }

  Future<ChatMessageModel> _handleReplaceStop({
    required String messageId,
    required Map<String, dynamic> currentItinerary,
    required bool isMultiDay,
    required String city,
    required double latitude,
    required double longitude,
    required int targetStopIndex,
    required List<String> currentStopNames,
    int? targetDayNumber,
  }) async {
    final candidates = await _candidateSource.getReplacementCandidates(
      latitude: latitude,
      longitude: longitude,
      city: city,
      category: 'heritage',
      excludedPlaceNames: currentStopNames,
    );

    if (candidates.isEmpty) {
      return ChatMessageModel(
        id: messageId,
        role: 'assistant',
        content: '[Offline Mode] No alternative verified attractions were found in local offline storage. Your schedule remains unchanged.',
      );
    }

    final chosen = candidates.first;
    final edit = ItineraryEditor.replaceStop(
      currentItineraryMap: currentItinerary,
      stopIndex: targetStopIndex,
      replacementCandidate: chosen,
      isMultiDay: isMultiDay,
      targetDayNumber: targetDayNumber,
    );

    return ChatMessageModel(
      id: messageId,
      role: 'assistant',
      content: '[Offline Mode] ${edit.message}',
      updatedItinerary: edit.updatedItinerary,
    );
  }

  Future<ChatMessageModel> _handleNearestService({
    required String messageId,
    required double latitude,
    required double longitude,
    required ServiceType serviceType,
  }) async {
    final services = await _candidateSource.getEmergencyServices(
      latitude: latitude,
      longitude: longitude,
      type: serviceType,
    );

    if (services.isEmpty) {
      return ChatMessageModel(
        id: messageId,
        role: 'assistant',
        content: '[Offline Mode] No verified ${serviceType.name} services were found in local offline storage near your stops.',
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('[Offline Mode] Nearest verified ${serviceType.name} services:');
    for (final s in services.take(3)) {
      final distStr = s.distanceKm != null ? ' (${s.distanceKm!.toStringAsFixed(1)} km)' : '';
      final addrStr = s.address != null && s.address!.isNotEmpty ? ' - ${s.address}' : '';
      buffer.writeln('• ${s.name}$distStr$addrStr');
    }

    return ChatMessageModel(
      id: messageId,
      role: 'assistant',
      content: buffer.toString().trim(),
    );
  }

  Future<ChatMessageModel> _handleTranslateCached({
    required String messageId,
    required String text,
    required String targetLang,
  }) async {
    try {
      final translated = await _translationService.translate(
        text: text,
        targetLanguage: targetLang,
      );
      return ChatMessageModel(
        id: messageId,
        role: 'assistant',
        content: '[Offline Mode] Translation: $translated',
      );
    } catch (_) {
      return ChatMessageModel(
        id: messageId,
        role: 'assistant',
        content: '[Offline Mode] The phrase "$text" is not available in local translation cache while offline.',
      );
    }
  }

  ChatMessageModel _handleQueryInfo({
    required String messageId,
    required String userMessage,
    required Map<String, dynamic> currentItinerary,
    required bool isMultiDay,
    required ParsedIntent intent,
  }) {
    final norm = IntentParser.normalize(userMessage);

    // Extract all stops
    final allStops = <Map<String, dynamic>>[];
    if (isMultiDay) {
      final days = (currentItinerary['days'] as List? ?? []);
      for (final day in days) {
        if (day is Map) {
          final stops = (day['stops'] as List? ?? []);
          for (final s in stops) {
            if (s is Map<String, dynamic>) allStops.add(s);
          }
        }
      }
    } else {
      final stops = (currentItinerary['stops'] as List? ?? []);
      for (final s in stops) {
        if (s is Map<String, dynamic>) allStops.add(s);
      }
    }

    // 1. Photo spots / camera / view
    if (norm.contains('photo') || norm.contains('camera') || norm.contains('view') || norm.contains('sunset') || norm.contains('spot')) {
      final photoStops = allStops.where((s) {
        final type = (s['type'] as String? ?? '').toLowerCase();
        final tips = (s['tips'] as List? ?? []).join(' ').toLowerCase();
        return type == 'monument' || type == 'nature' || tips.contains('photo') || tips.contains('view') || tips.contains('sunset');
      }).toList();

      final listToUse = photoStops.isNotEmpty ? photoStops : allStops;
      final buffer = StringBuffer('[Offline Mode] Top scenic & photo spots in your itinerary:\n\n');
      for (final s in listToUse.take(3)) {
        final name = s['name'] ?? 'Attraction';
        final tips = (s['tips'] as List? ?? []).where((t) => t.toString().toLowerCase().contains('photo') || t.toString().toLowerCase().contains('view')).toList();
        final tipText = tips.isNotEmpty ? tips.first : 'Great vantage point for photography.';
        buffer.writeln('📸 **$name**: $tipText');
      }
      return ChatMessageModel(id: messageId, role: 'assistant', content: buffer.toString().trim());
    }

    // 2. What to carry / pack / bring
    if (norm.contains('pack') || norm.contains('carry') || norm.contains('bring') || norm.contains('bag')) {
      final carry = (currentItinerary['whatToCarry'] as List? ?? []).map((e) => e.toString()).toList();
      final items = carry.isNotEmpty ? carry : [
        '💧 Water bottle',
        '📱 Fully charged phone & offline maps',
        '👟 Comfortable walking shoes',
        '🧴 Sunscreen / hat',
        '💵 Backup cash & ID card',
      ];
      final buffer = StringBuffer('[Offline Mode] Essential items to carry for your trip:\n\n');
      for (final item in items) {
        buffer.writeln('• $item');
      }
      return ChatMessageModel(id: messageId, role: 'assistant', content: buffer.toString().trim());
    }

    // 3. Specific place query by name or index
    if (intent.targetStopIndex != null && intent.targetStopIndex! >= 0 && intent.targetStopIndex! < allStops.length) {
      final s = allStops[intent.targetStopIndex!];
      final name = s['name'] ?? 'Stop';
      final desc = s['description'] ?? 'Popular attraction.';
      final start = s['startTime'] ?? '';
      final end = s['endTime'] ?? '';
      final cost = s['cost'] != null ? '₹${s['cost']}' : 'Free / Standard entry';
      final tips = (s['tips'] as List? ?? []).take(2).toList();

      final buffer = StringBuffer('[Offline Mode] **$name**\n\n');
      buffer.writeln('• **Time:** $start - $end');
      buffer.writeln('• **Estimated Cost:** $cost');
      buffer.writeln('• **About:** $desc');
      if (tips.isNotEmpty) {
        buffer.writeln('• **Tips:** ${tips.join("; ")}');
      }
      return ChatMessageModel(id: messageId, role: 'assistant', content: buffer.toString().trim());
    }

    // 4. Plan / schedule / overview / summary
    if (norm.contains('plan') || norm.contains('schedule') || norm.contains('overview') || norm.contains('summary') || norm.contains('today')) {
      final summary = currentItinerary['aiSummary'] as String? ?? currentItinerary['overallSummary'] as String? ?? 'Here is your planned schedule:';
      final buffer = StringBuffer('[Offline Mode] $summary\n\n');
      for (int i = 0; i < allStops.length; i++) {
        final s = allStops[i];
        final name = s['name'] ?? 'Stop ${i + 1}';
        final start = s['startTime'] ?? '';
        final end = s['endTime'] ?? '';
        buffer.writeln('${i + 1}. **$name** ($start - $end)');
      }
      return ChatMessageModel(id: messageId, role: 'assistant', content: buffer.toString().trim());
    }

    // Default query fallback: show general overview
    final cityName = currentItinerary['city'] as String? ?? 'your destination';
    return ChatMessageModel(
      id: messageId,
      role: 'assistant',
      content: '[Offline Mode] Exploring $cityName with ${allStops.length} stops planned. You can ask for:\n\n'
          '• "Best photo spots?"\n'
          '• "What to carry?"\n'
          '• "Add food stop"\n'
          '• "Replace [place name]"\n'
          '• "Make it more relaxed"',
    );
  }

}
