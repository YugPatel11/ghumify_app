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

      case LocalChatIntentType.unknown:
      default:
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
}

