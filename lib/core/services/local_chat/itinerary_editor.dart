import 'dart:math' as math;
import '../../models/itinerary_model.dart';
import '../../models/multi_day_itinerary_model.dart';
import '../../models/place_model.dart';

class ItineraryEditResult {
  final bool success;
  final Map<String, dynamic>? updatedItinerary;
  final String message;

  const ItineraryEditResult({
    required this.success,
    this.updatedItinerary,
    required this.message,
  });
}

class ItineraryEditor {
  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371; // Earth radius in km
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLon = (lon2 - lon1) * math.pi / 180.0;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static int estimateTravelMinutes(double distKm, String mode) {
    if (distKm <= 0.05) return 5;
    switch (mode.toLowerCase()) {
      case 'walking':
        return (distKm / 4.5 * 60).round().clamp(5, 120);
      case 'transit':
        return (distKm / 18.0 * 60 + 8).round().clamp(10, 180);
      case 'driving':
      default:
        return (distKm / 25.0 * 60 + 5).round().clamp(5, 180);
    }
  }

  static int timeToMinutes(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return 540; // 09:00 default
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String minutesToTime(int mins) {
    final normalized = mins.clamp(0, 1439);
    final h = normalized ~/ 60;
    final m = normalized % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Recalculates all sequential start/end times and travel durations
  static List<ItineraryStop>? resequenceStops({
    required List<ItineraryStop> stops,
    required String dayStartTime,
    required String dayEndTime,
    required String travelMode,
  }) {
    if (stops.isEmpty) return [];

    final startLimit = timeToMinutes(dayStartTime);
    final endLimit = timeToMinutes(dayEndTime);
    int currentMins = startLimit;

    final resequenced = <ItineraryStop>[];

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      int travelMins = 0;

      if (i > 0) {
        final prev = stops[i - 1];
        if (prev.latitude != null &&
            prev.longitude != null &&
            stop.latitude != null &&
            stop.longitude != null) {
          final dist = haversineKm(
            prev.latitude!,
            prev.longitude!,
            stop.latitude!,
            stop.longitude!,
          );
          travelMins = estimateTravelMinutes(dist, travelMode);
        } else {
          travelMins = stop.travelMinutes ?? 15;
        }
      }

      currentMins += travelMins;
      final stopStart = currentMins;
      final int stopEnd = stopStart + (math.max(15, stop.durationMinutes) as num).toInt();

      resequenced.add(ItineraryStop(
        name: stop.name,
        type: stop.type,
        placeId: stop.placeId,
        startTime: minutesToTime(stopStart),
        endTime: minutesToTime(stopEnd),
        durationMinutes: stop.durationMinutes,
        latitude: stop.latitude,
        longitude: stop.longitude,
        description: stop.description,
        photoUrl: stop.photoUrl,
        travelMode: travelMode,
        travelMinutes: travelMins,
        tips: stop.tips,
        estimatedCost: stop.estimatedCost,
      ));

      currentMins = stopEnd;
    }

    // Boundary invariant check: never allow itinerary to exceed dayEndTime
    if (currentMins > endLimit) {
      return null; // Exceeds day boundary
    }

    return resequenced;
  }

  /// Recomputes expenses strictly from real estimatedCost fields
  static Map<String, dynamic> recomputeExpenseSummary(
    List<ItineraryStop> stops,
    Map<String, dynamic>? existingSummary,
  ) {
    int foodTotal = 0;
    int activitiesTotal = 0;
    int transportTotal = (existingSummary?['transport'] as num?)?.toInt() ?? (stops.length * 50);
    int otherTotal = (existingSummary?['other'] as num?)?.toInt() ?? 100;

    for (final s in stops) {
      final cost = s.estimatedCost ?? 0;
      if (s.type == 'food') {
        foodTotal += cost;
      } else {
        activitiesTotal += cost;
      }
    }

    final total = foodTotal + activitiesTotal + transportTotal + otherTotal;
    return {
      'food': foodTotal,
      'transport': transportTotal,
      'activities': activitiesTotal,
      'other': otherTotal,
      'total': total,
    };
  }

  // 1. ADD FOOD STOP
  static ItineraryEditResult addFoodStop({
    required Map<String, dynamic> currentItineraryMap,
    required PlaceModel foodCandidate,
    bool isMultiDay = false,
    int? targetDayNumber,
  }) {
    if (isMultiDay) {
      return _editMultiDay(
        currentItineraryMap,
        targetDayNumber,
        (day) => _addFoodStopToDay(day, foodCandidate),
      );
    } else {
      return _addFoodStopToDay(currentItineraryMap, foodCandidate);
    }
  }

  static ItineraryEditResult _addFoodStopToDay(
    Map<String, dynamic> dayMap,
    PlaceModel foodCandidate,
  ) {
    final rawStops = (dayMap['stops'] as List? ?? []);
    final stops = rawStops.map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>)).toList();

    final dayStartTime = dayMap['startTime'] as String? ?? '09:00';
    final dayEndTime = dayMap['endTime'] as String? ?? '18:00';
    final travelMode = dayMap['travelMode'] as String? ?? 'driving';

    // Insert around lunch time or in the middle of stops
    final lunchMins = 13 * 60; // 1:00 PM
    int insertIndex = stops.length ~/ 2;

    for (int i = 0; i < stops.length; i++) {
      if (timeToMinutes(stops[i].startTime) >= lunchMins) {
        insertIndex = i;
        break;
      }
    }

    final newStop = ItineraryStop(
      name: foodCandidate.name,
      type: 'food',
      placeId: foodCandidate.id,
      startTime: '',
      endTime: '',
      durationMinutes: 45,
      latitude: foodCandidate.latitude,
      longitude: foodCandidate.longitude,
      description: foodCandidate.description.isNotEmpty ? foodCandidate.description : 'Dining stop at ${foodCandidate.name}',
      photoUrl: foodCandidate.thumbnailUrl ?? (foodCandidate.photoUrls.isNotEmpty ? foodCandidate.photoUrls.first : null),
      travelMode: travelMode,
      travelMinutes: 10,
      tips: ['Enjoy famous local specialties.'],
      estimatedCost: foodCandidate.entryFee?.toInt() ?? 250,
    );

    final modifiedStops = List<ItineraryStop>.from(stops)..insert(insertIndex, newStop);

    final resequenced = resequenceStops(
      stops: modifiedStops,
      dayStartTime: dayStartTime,
      dayEndTime: dayEndTime,
      travelMode: travelMode,
    );

    if (resequenced == null) {
      return ItineraryEditResult(
        success: false,
        message: 'Adding "${foodCandidate.name}" would extend your itinerary past $dayEndTime. Try removing an existing stop first.',
      );
    }

    final updatedMap = Map<String, dynamic>.from(dayMap);
    updatedMap['stops'] = resequenced.map((s) => s.toMap()).toList();
    final newExpenses = recomputeExpenseSummary(resequenced, dayMap['expenseSummary'] as Map<String, dynamic>?);
    updatedMap['expenseSummary'] = newExpenses;
    updatedMap['estimatedTotalCost'] = newExpenses['total'];
    final budget = dayMap['budget'] as int?;
    if (budget != null && budget > 0) {
      updatedMap['remainingBudget'] = budget - (newExpenses['total'] as int);
    }

    return ItineraryEditResult(
      success: true,
      updatedItinerary: updatedMap,
      message: 'Added "${foodCandidate.name}" to your schedule.',
    );
  }

  // 2. REMOVE STOP
  static ItineraryEditResult removeStop({
    required Map<String, dynamic> currentItineraryMap,
    required int stopIndex,
    bool isMultiDay = false,
    int? targetDayNumber,
  }) {
    if (isMultiDay) {
      return _editMultiDay(
        currentItineraryMap,
        targetDayNumber,
        (day) => _removeStopFromDay(day, stopIndex),
      );
    } else {
      return _removeStopFromDay(currentItineraryMap, stopIndex);
    }
  }

  static ItineraryEditResult _removeStopFromDay(Map<String, dynamic> dayMap, int stopIndex) {
    final rawStops = (dayMap['stops'] as List? ?? []);
    final stops = rawStops.map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>)).toList();

    if (stopIndex < 0 || stopIndex >= stops.length) {
      return const ItineraryEditResult(
        success: false,
        message: 'Invalid stop selected for removal.',
      );
    }

    if (stops.length <= 1) {
      return const ItineraryEditResult(
        success: false,
        message: 'Cannot remove the only stop in the itinerary.',
      );
    }

    final removedName = stops[stopIndex].name;
    final modifiedStops = List<ItineraryStop>.from(stops)..removeAt(stopIndex);

    final dayStartTime = dayMap['startTime'] as String? ?? '09:00';
    final dayEndTime = dayMap['endTime'] as String? ?? '18:00';
    final travelMode = dayMap['travelMode'] as String? ?? 'driving';

    final resequenced = resequenceStops(
      stops: modifiedStops,
      dayStartTime: dayStartTime,
      dayEndTime: dayEndTime,
      travelMode: travelMode,
    ) ?? modifiedStops;

    final updatedMap = Map<String, dynamic>.from(dayMap);
    updatedMap['stops'] = resequenced.map((s) => s.toMap()).toList();
    final newExpenses = recomputeExpenseSummary(resequenced, dayMap['expenseSummary'] as Map<String, dynamic>?);
    updatedMap['expenseSummary'] = newExpenses;
    updatedMap['estimatedTotalCost'] = newExpenses['total'];

    return ItineraryEditResult(
      success: true,
      updatedItinerary: updatedMap,
      message: 'Removed "$removedName" from your itinerary and adjusted timings.',
    );
  }

  // 3. REPLACE STOP
  static ItineraryEditResult replaceStop({
    required Map<String, dynamic> currentItineraryMap,
    required int stopIndex,
    required PlaceModel replacementCandidate,
    bool isMultiDay = false,
    int? targetDayNumber,
  }) {
    if (isMultiDay) {
      return _editMultiDay(
        currentItineraryMap,
        targetDayNumber,
        (day) => _replaceStopInDay(day, stopIndex, replacementCandidate),
      );
    } else {
      return _replaceStopInDay(currentItineraryMap, stopIndex, replacementCandidate);
    }
  }

  static ItineraryEditResult _replaceStopInDay(
    Map<String, dynamic> dayMap,
    int stopIndex,
    PlaceModel replacementCandidate,
  ) {
    final rawStops = (dayMap['stops'] as List? ?? []);
    final stops = rawStops.map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>)).toList();

    if (stopIndex < 0 || stopIndex >= stops.length) {
      return const ItineraryEditResult(
        success: false,
        message: 'Could not find the target stop to replace.',
      );
    }

    final oldStop = stops[stopIndex];
    final dayStartTime = dayMap['startTime'] as String? ?? '09:00';
    final dayEndTime = dayMap['endTime'] as String? ?? '18:00';
    final travelMode = dayMap['travelMode'] as String? ?? 'driving';

    final newStop = ItineraryStop(
      name: replacementCandidate.name,
      type: replacementCandidate.category == 'food' ? 'food' : 'place',
      placeId: replacementCandidate.id,
      startTime: '',
      endTime: '',
      durationMinutes: oldStop.durationMinutes,
      latitude: replacementCandidate.latitude,
      longitude: replacementCandidate.longitude,
      description: replacementCandidate.description.isNotEmpty ? replacementCandidate.description : 'Visit ${replacementCandidate.name}',
      photoUrl: replacementCandidate.thumbnailUrl ?? (replacementCandidate.photoUrls.isNotEmpty ? replacementCandidate.photoUrls.first : null),
      travelMode: travelMode,
      travelMinutes: oldStop.travelMinutes,
      tips: ['Explore at your leisure.'],
      estimatedCost: replacementCandidate.entryFee?.toInt() ?? oldStop.estimatedCost,
    );

    final modifiedStops = List<ItineraryStop>.from(stops);
    modifiedStops[stopIndex] = newStop;

    final resequenced = resequenceStops(
      stops: modifiedStops,
      dayStartTime: dayStartTime,
      dayEndTime: dayEndTime,
      travelMode: travelMode,
    );

    if (resequenced == null) {
      return ItineraryEditResult(
        success: false,
        message: 'Replacing "${oldStop.name}" with "${replacementCandidate.name}" would exceed $dayEndTime due to travel distance.',
      );
    }

    final updatedMap = Map<String, dynamic>.from(dayMap);
    updatedMap['stops'] = resequenced.map((s) => s.toMap()).toList();
    final newExpenses = recomputeExpenseSummary(resequenced, dayMap['expenseSummary'] as Map<String, dynamic>?);
    updatedMap['expenseSummary'] = newExpenses;
    updatedMap['estimatedTotalCost'] = newExpenses['total'];

    return ItineraryEditResult(
      success: true,
      updatedItinerary: updatedMap,
      message: 'Replaced "${oldStop.name}" with "${replacementCandidate.name}".',
    );
  }

  // 4. LESS TIME (Shrink stop durations or drop last stop)
  static ItineraryEditResult lessTime({
    required Map<String, dynamic> currentItineraryMap,
    bool isMultiDay = false,
    int? targetDayNumber,
  }) {
    if (isMultiDay) {
      return _editMultiDay(currentItineraryMap, targetDayNumber, _shrinkDayTime);
    } else {
      return _shrinkDayTime(currentItineraryMap);
    }
  }

  static ItineraryEditResult _shrinkDayTime(Map<String, dynamic> dayMap) {
    final rawStops = (dayMap['stops'] as List? ?? []);
    final stops = rawStops.map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>)).toList();

    if (stops.isEmpty) {
      return const ItineraryEditResult(success: false, message: 'No stops to adjust.');
    }

    // Shrink durations by 25% (minimum 25 mins)
    final modified = stops.map((s) {
      final shrunken = (s.durationMinutes * 0.75).round().clamp(25, 180);
      return ItineraryStop(
        name: s.name,
        type: s.type,
        placeId: s.placeId,
        startTime: s.startTime,
        endTime: s.endTime,
        durationMinutes: shrunken,
        latitude: s.latitude,
        longitude: s.longitude,
        description: s.description,
        photoUrl: s.photoUrl,
        travelMode: s.travelMode,
        travelMinutes: s.travelMinutes,
        tips: s.tips,
        estimatedCost: s.estimatedCost,
      );
    }).toList();

    final dayStartTime = dayMap['startTime'] as String? ?? '09:00';
    final dayEndTime = dayMap['endTime'] as String? ?? '18:00';
    final travelMode = dayMap['travelMode'] as String? ?? 'driving';

    final resequenced = resequenceStops(
      stops: modified,
      dayStartTime: dayStartTime,
      dayEndTime: dayEndTime,
      travelMode: travelMode,
    ) ?? modified;

    final updatedMap = Map<String, dynamic>.from(dayMap);
    updatedMap['stops'] = resequenced.map((s) => s.toMap()).toList();
    updatedMap['pace'] = 'fast';

    return ItineraryEditResult(
      success: true,
      updatedItinerary: updatedMap,
      message: 'Shortened stop durations across your itinerary for a faster-paced schedule.',
    );
  }

  // 5. MORE RELAXED (Expand stop durations by 20% if within limit)
  static ItineraryEditResult moreRelaxed({
    required Map<String, dynamic> currentItineraryMap,
    bool isMultiDay = false,
    int? targetDayNumber,
  }) {
    if (isMultiDay) {
      return _editMultiDay(currentItineraryMap, targetDayNumber, _relaxDayPace);
    } else {
      return _relaxDayPace(currentItineraryMap);
    }
  }

  static ItineraryEditResult _relaxDayPace(Map<String, dynamic> dayMap) {
    final rawStops = (dayMap['stops'] as List? ?? []);
    final stops = rawStops.map((s) => ItineraryStop.fromMap(s as Map<String, dynamic>)).toList();

    if (stops.isEmpty) {
      return const ItineraryEditResult(success: false, message: 'No stops to adjust.');
    }

    final dayStartTime = dayMap['startTime'] as String? ?? '09:00';
    final dayEndTime = dayMap['endTime'] as String? ?? '18:00';
    final travelMode = dayMap['travelMode'] as String? ?? 'driving';

    // Try expanding duration by 20%
    var modified = stops.map((s) {
      final expanded = (s.durationMinutes * 1.25).round().clamp(30, 240);
      return ItineraryStop(
        name: s.name,
        type: s.type,
        placeId: s.placeId,
        startTime: s.startTime,
        endTime: s.endTime,
        durationMinutes: expanded,
        latitude: s.latitude,
        longitude: s.longitude,
        description: s.description,
        photoUrl: s.photoUrl,
        travelMode: s.travelMode,
        travelMinutes: s.travelMinutes,
        tips: s.tips,
        estimatedCost: s.estimatedCost,
      );
    }).toList();

    var resequenced = resequenceStops(
      stops: modified,
      dayStartTime: dayStartTime,
      dayEndTime: dayEndTime,
      travelMode: travelMode,
    );

    // If expanding all stops exceeds the day end time, drop the last stop so remaining stops are relaxed
    if (resequenced == null && modified.length > 2) {
      final droppedName = modified.removeLast().name;
      resequenced = resequenceStops(
        stops: modified,
        dayStartTime: dayStartTime,
        dayEndTime: dayEndTime,
        travelMode: travelMode,
      );
      if (resequenced != null) {
        final updatedMap = Map<String, dynamic>.from(dayMap);
        updatedMap['stops'] = resequenced.map((s) => s.toMap()).toList();
        updatedMap['pace'] = 'relaxed';
        return ItineraryEditResult(
          success: true,
          updatedItinerary: updatedMap,
          message: 'Made your schedule more relaxed by dropping "$droppedName" and giving you more time at each stop.',
        );
      }
    }

    if (resequenced == null) {
      return ItineraryEditResult(
        success: false,
        message: 'Cannot make current stops more relaxed without exceeding the $dayEndTime end time.',
      );
    }

    final updatedMap = Map<String, dynamic>.from(dayMap);
    updatedMap['stops'] = resequenced.map((s) => s.toMap()).toList();
    updatedMap['pace'] = 'relaxed';

    return ItineraryEditResult(
      success: true,
      updatedItinerary: updatedMap,
      message: 'Adjusted schedule to a relaxed pace with more breathing room at each stop.',
    );
  }

  // Helper for multi-day editing
  static ItineraryEditResult _editMultiDay(
    Map<String, dynamic> multiDayMap,
    int? targetDayNumber,
    ItineraryEditResult Function(Map<String, dynamic> dayMap) editor,
  ) {
    final daysRaw = (multiDayMap['days'] as List? ?? []);
    if (daysRaw.isEmpty) {
      return const ItineraryEditResult(success: false, message: 'No days found in trip.');
    }

    final dayIdx = targetDayNumber != null && targetDayNumber > 0 && targetDayNumber <= daysRaw.length
        ? targetDayNumber - 1
        : 0;

    final targetDayMap = Map<String, dynamic>.from(daysRaw[dayIdx] as Map);
    final result = editor(targetDayMap);

    if (!result.success || result.updatedItinerary == null) {
      return result;
    }

    final updatedDays = List<dynamic>.from(daysRaw);
    updatedDays[dayIdx] = result.updatedItinerary!;

    final updatedMultiDay = Map<String, dynamic>.from(multiDayMap);
    updatedMultiDay['days'] = updatedDays;

    return ItineraryEditResult(
      success: true,
      updatedItinerary: updatedMultiDay,
      message: '${result.message} (Applied to Day ${dayIdx + 1})',
    );
  }
}

