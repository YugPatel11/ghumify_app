import 'dart:math';
import '../models/itinerary_model.dart';
import '../models/travelers_model.dart';

/// Pure, testable result container for route proximity optimization.
class RouteOptimizationResult {
  final List<ItineraryStop> orderedStops;
  final String startPointMessage;
  final double totalDistanceKm;
  final int totalTravelMinutes;
  final bool hasDistanceWarning;
  final String? distanceWarningNote;
  final List<ItineraryStop> overflowStops;

  const RouteOptimizationResult({
    required this.orderedStops,
    required this.startPointMessage,
    required this.totalDistanceKm,
    required this.totalTravelMinutes,
    this.hasDistanceWarning = false,
    this.distanceWarningNote,
    this.overflowStops = const [],
  });
}

/// Pure, testable route proximity optimizer.
///
/// Implements Nearest-Neighbor ordering based on geographic proximity.
/// IMPORTANT:
/// 1. Distance measure: Straight-line distance using spherical Haversine formula
///    multiplied by a 1.25 urban road-winding factor for realistic street navigation.
/// 2. Ties are broken deterministically by alphabetical place name.
/// 3. Anchored stops (meals, travel legs, meeting points, pinned stops) remain fixed.
/// 4. Opening hours: stops are verified against opening hours when present; closed places
///    are shifted after open alternatives.
/// 5. Time slots and durations are recalculated sequentially.
class RouteProximityOptimizer {
  static const double earthRadiusKm = 6371.0;
  static const double roadWindingFactor = 1.25;

  /// Default urban travel speeds in km/h
  static const double speedDrivingKmH = 25.0;
  static const double speedWalkingKmH = 4.5;
  static const double speedTransitKmH = 18.0;

  /// Main pure ordering function
  static RouteOptimizationResult optimizeStopsProximity({
    required List<ItineraryStop> stops,
    required double startLat,
    required double startLng,
    required String startPointLabel,
    String travelMode = 'driving',
    String pace = 'moderate',
    TravelersModel travelers = const TravelersModel(),
    String dayStartTime = '09:00',
    String dayEndTime = '21:00',
  }) {
    if (stops.isEmpty) {
      return RouteOptimizationResult(
        orderedStops: const [],
        startPointMessage: 'Route starts from $startPointLabel',
        totalDistanceKm: 0.0,
        totalTravelMinutes: 0,
      );
    }

    if (stops.length == 1) {
      final stop = stops.first;
      final dist = (stop.latitude != null && stop.longitude != null)
          ? calculateDistanceKm(startLat, startLng, stop.latitude!, stop.longitude!)
          : 0.0;
      final travelMin = estimateTravelMinutes(dist, travelMode);
      final recalculated = stop.copyWith(
        distanceFromPrevKm: dist > 0 ? double.parse(dist.toStringAsFixed(1)) : null,
        travelTimeFromPrev: dist > 0 ? formatTravelTime(travelMin, travelMode) : null,
      );

      return RouteOptimizationResult(
        orderedStops: [recalculated],
        startPointMessage: 'Route starts from $startPointLabel',
        totalDistanceKm: dist,
        totalTravelMinutes: travelMin,
      );
    }

    // ── STEP 1: Segment stops by fixed anchors ──
    // Anchored items:
    // - explicitly anchored (isAnchored == true or isPinned == true)
    // - travel legs (type == 'travel')
    // - meeting points
    // - meal stops within lunch/dinner windows
    final segments = <_RouteSegment>[];
    var currentFreeStops = <ItineraryStop>[];
    double prevAnchorLat = startLat;
    double prevAnchorLng = startLng;

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      if (isStopAnchored(stop)) {
        // Close preceding segment
        segments.add(_RouteSegment(
          freeStops: currentFreeStops,
          segmentStartLat: prevAnchorLat,
          segmentStartLng: prevAnchorLng,
          anchorStop: stop,
        ));
        currentFreeStops = [];
        if (stop.latitude != null && stop.longitude != null) {
          prevAnchorLat = stop.latitude!;
          prevAnchorLng = stop.longitude!;
        }
      } else {
        currentFreeStops.add(stop);
      }
    }

    // Add trailing segment
    segments.add(_RouteSegment(
      freeStops: currentFreeStops,
      segmentStartLat: prevAnchorLat,
      segmentStartLng: prevAnchorLng,
      anchorStop: null,
    ));

    // ── STEP 2: Nearest-neighbor reordering per segment ──
    final orderedAllStops = <ItineraryStop>[];

    for (final seg in segments) {
      final orderedFree = _orderSegmentNearestNeighbor(
        freeStops: seg.freeStops,
        originLat: seg.segmentStartLat,
        originLng: seg.segmentStartLng,
      );
      orderedAllStops.addAll(orderedFree);
      if (seg.anchorStop != null) {
        orderedAllStops.add(seg.anchorStop!);
      }
    }

    // ── STEP 3: Opening Hours verification & swap ──
    final hoursAdjustedStops = _adjustForOpeningHours(
      stops: orderedAllStops,
      dayStartTime: dayStartTime,
      travelMode: travelMode,
      startLat: startLat,
      startLng: startLng,
    );

    // ── STEP 4: Time Slot & Duration Recalculation ──
    final timeAdjusted = _recalculateTimeSlots(
      stops: hoursAdjustedStops,
      startLat: startLat,
      startLng: startLng,
      travelMode: travelMode,
      pace: pace,
      travelers: travelers,
      dayStartTime: dayStartTime,
      dayEndTime: dayEndTime,
    );

    // Calculate total route distance & travel time
    double totalDist = 0.0;
    int totalTravel = 0;
    for (final s in timeAdjusted.orderedStops) {
      if (s.distanceFromPrevKm != null) {
        totalDist += s.distanceFromPrevKm!;
      }
      if (s.travelMinutes != null) {
        totalTravel += s.travelMinutes!;
      }
    }

    // Route distance warning check (e.g. if average inter-stop distance exceeds 18km)
    final avgDist = timeAdjusted.orderedStops.isNotEmpty
        ? totalDist / timeAdjusted.orderedStops.length
        : 0.0;
    final isDistanceHigh = avgDist > 18.0;

    return RouteOptimizationResult(
      orderedStops: timeAdjusted.orderedStops,
      startPointMessage: 'Route starts from $startPointLabel',
      totalDistanceKm: double.parse(totalDist.toStringAsFixed(1)),
      totalTravelMinutes: totalTravel,
      hasDistanceWarning: isDistanceHigh,
      distanceWarningNote: isDistanceHigh
          ? 'Note: Places are spread across the region (~${avgDist.toStringAsFixed(1)} km between stops). Consider allotting extra travel time.'
          : null,
      overflowStops: timeAdjusted.overflowStops,
    );
  }

  /// Check if a stop is anchored and should NEVER move
  static bool isStopAnchored(ItineraryStop stop) {
    if (stop.isAnchored || stop.isPinned) return true;
    if (stop.type == 'travel') return true;

    final lowerName = stop.name.toLowerCase();
    if (lowerName.contains('meeting point') || lowerName.contains('rejoin group')) {
      return true;
    }

    // Anchored meals in meal windows
    if (stop.type == 'food') {
      final startMin = timeToMinutes(stop.startTime);
      final isLunch = startMin >= 12 * 60 && startMin <= 14 * 60 + 30;
      final isDinner = startMin >= 19 * 60 && startMin <= 21 * 60 + 30;
      if (isLunch || isDinner) return true;
    }

    return false;
  }

  /// Nearest-Neighbor ordering on a list of free unanchored stops
  static List<ItineraryStop> _orderSegmentNearestNeighbor({
    required List<ItineraryStop> freeStops,
    required double originLat,
    required double originLng,
  }) {
    if (freeStops.length <= 1) return List.from(freeStops);

    final remaining = List<ItineraryStop>.from(freeStops);
    final ordered = <ItineraryStop>[];
    double currentLat = originLat;
    double currentLng = originLng;

    while (remaining.isNotEmpty) {
      ItineraryStop? bestCandidate;
      double minDistance = double.infinity;
      int bestIndex = -1;

      for (int i = 0; i < remaining.length; i++) {
        final candidate = remaining[i];
        final dist = (candidate.latitude != null && candidate.longitude != null)
            ? calculateDistanceKm(currentLat, currentLng, candidate.latitude!, candidate.longitude!)
            : 99999.0;

        if (dist < minDistance) {
          minDistance = dist;
          bestCandidate = candidate;
          bestIndex = i;
        } else if ((dist - minDistance).abs() < 0.001) {
          // Deterministic tie-breaking by alphabetical place name
          if (bestCandidate != null && candidate.name.compareTo(bestCandidate.name) < 0) {
            bestCandidate = candidate;
            bestIndex = i;
          }
        }
      }

      if (bestCandidate != null && bestIndex >= 0) {
        ordered.add(bestCandidate);
        if (bestCandidate.latitude != null && bestCandidate.longitude != null) {
          currentLat = bestCandidate.latitude!;
          currentLng = bestCandidate.longitude!;
        }
        remaining.removeAt(bestIndex);
      } else {
        // Fallback safety
        ordered.addAll(remaining);
        break;
      }
    }

    return ordered;
  }

  /// Opening hours adjustment: if stop is closed at expected time, pick next nearest open candidate
  static List<ItineraryStop> _adjustForOpeningHours({
    required List<ItineraryStop> stops,
    required String dayStartTime,
    required String travelMode,
    required double startLat,
    required double startLng,
  }) {
    if (stops.length <= 1) return stops;

    final adjusted = List<ItineraryStop>.from(stops);
    int currentMinutes = timeToMinutes(dayStartTime);

    for (int i = 0; i < adjusted.length; i++) {
      final stop = adjusted[i];
      if (stop.isAnchored || stop.isPinned) {
        currentMinutes = timeToMinutes(stop.endTime);
        continue;
      }

      if (stop.openingHours != null && stop.openingHours!.isNotEmpty) {
        final openWindow = parseOpeningHours(stop.openingHours!);
        if (openWindow != null) {
          final isOpen = currentMinutes >= openWindow.openMinutes &&
              currentMinutes < openWindow.closeMinutes;

          if (!isOpen && i + 1 < adjusted.length) {
            // Find next unanchored candidate that is open now
            int swapIndex = -1;
            for (int j = i + 1; j < adjusted.length; j++) {
              final candidate = adjusted[j];
              if (!isStopAnchored(candidate)) {
                if (candidate.openingHours == null || candidate.openingHours!.isEmpty) {
                  swapIndex = j;
                  break;
                }
                final candWindow = parseOpeningHours(candidate.openingHours!);
                if (candWindow == null ||
                    (currentMinutes >= candWindow.openMinutes &&
                        currentMinutes < candWindow.closeMinutes)) {
                  swapIndex = j;
                  break;
                }
              }
            }

            if (swapIndex != -1) {
              final temp = adjusted[i];
              adjusted[i] = adjusted[swapIndex];
              adjusted[swapIndex] = temp;
            }
          }
        }
      }

      final dur = stop.durationMinutes > 0 ? stop.durationMinutes : 60;
      currentMinutes += dur + 15;
    }

    return adjusted;
  }

  /// Sequential recalculation of start times, end times, and travel times
  static _TimeRecalculationResult _recalculateTimeSlots({
    required List<ItineraryStop> stops,
    required double startLat,
    required double startLng,
    required String travelMode,
    required String pace,
    required TravelersModel travelers,
    required String dayStartTime,
    required String dayEndTime,
  }) {
    final result = <ItineraryStop>[];
    final overflow = <ItineraryStop>[];

    int currentMinutes = timeToMinutes(dayStartTime);
    final limitMinutes = timeToMinutes(dayEndTime);

    // Buffer pace adjustments
    int paceBuffer = 10;
    if (pace == 'relaxed') {
      paceBuffer = 15;
    } else if (pace == 'fast') {
      paceBuffer = 5;
    }
    // Family / minors rest adjustment
    if (travelers.hasMinors) {
      paceBuffer += 10;
    }

    double prevLat = startLat;
    double prevLng = startLng;

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];

      // Distance and travel from previous
      double distKm = 0.0;
      if (stop.latitude != null && stop.longitude != null) {
        distKm = calculateDistanceKm(prevLat, prevLng, stop.latitude!, stop.longitude!);
      }
      final travelMin = estimateTravelMinutes(distKm, travelMode);

      // Advance clock by travel time
      currentMinutes += travelMin;

      // Handle anchored stop fixed start time if later
      if (stop.isAnchored && stop.startTime.isNotEmpty) {
        final fixedStart = timeToMinutes(stop.startTime);
        if (fixedStart > currentMinutes) {
          currentMinutes = fixedStart;
        }
      }

      int dur = stop.durationMinutes > 0 ? stop.durationMinutes : 60;
      // Minor safety pace adjustment
      if (travelers.hasMinors && dur > 120 && stop.type != 'food') {
        dur = 90; // moderate duration for kids
      }

      final startStr = minutesToTime(currentMinutes);
      final stopEndMinutes = currentMinutes + dur;
      final endStr = minutesToTime(stopEndMinutes);

      // Check overflow past day end limit
      if (currentMinutes >= limitMinutes && !isStopAnchored(stop) && i > 0) {
        overflow.add(stop);
        continue;
      }

      final updatedStop = stop.copyWith(
        startTime: startStr,
        endTime: endStr,
        durationMinutes: dur,
        travelMode: travelMode,
        travelMinutes: travelMin,
        distanceFromPrevKm: distKm > 0 ? double.parse(distKm.toStringAsFixed(1)) : null,
        travelTimeFromPrev: distKm > 0 ? formatTravelTime(travelMin, travelMode) : null,
      );

      result.add(updatedStop);

      currentMinutes = stopEndMinutes + paceBuffer;
      if (stop.latitude != null && stop.longitude != null) {
        prevLat = stop.latitude!;
        prevLng = stop.longitude!;
      }
    }

    return _TimeRecalculationResult(
      orderedStops: result,
      overflowStops: overflow,
    );
  }

  /// Spherical Haversine straight-line distance in kilometers,
  /// with road-winding corridor multiplier for urban navigation.
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    if (lat1 == lat2 && lon1 == lon2) return 0.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final straightLineKm = earthRadiusKm * c;

    return straightLineKm * roadWindingFactor;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  /// Estimate travel minutes based on distance and travel mode
  static int estimateTravelMinutes(double distanceKm, String travelMode) {
    if (distanceKm <= 0.05) return 0;

    double speed = speedDrivingKmH;
    if (travelMode.toLowerCase().contains('walk')) {
      speed = speedWalkingKmH;
    } else if (travelMode.toLowerCase().contains('transit') ||
        travelMode.toLowerCase().contains('bus')) {
      speed = speedTransitKmH;
    }

    final minutes = (distanceKm / speed * 60).round();
    return max(1, minutes);
  }

  /// Format travel time label (e.g. "6 min drive", "15 min walk")
  static String formatTravelTime(int minutes, String travelMode) {
    String modeLabel = 'drive';
    final lower = travelMode.toLowerCase();
    if (lower.contains('walk')) {
      modeLabel = 'walk';
    } else if (lower.contains('transit') || lower.contains('bus')) {
      modeLabel = 'transit';
    }
    return '$minutes min $modeLabel';
  }

  /// Parse time string into total minutes from midnight (handles 12h AM/PM and 24h formats)
  static int timeToMinutes(String time) {
    if (time.trim().isEmpty) return 9 * 60; // 09:00 default
    try {
      final upper = time.toUpperCase();
      final isPm = upper.contains('PM');
      final isAm = upper.contains('AM');
      final clean = time.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = clean.split(':');
      var h = int.parse(parts[0]);
      final m = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && h < 12) {
        h += 12;
      } else if (isAm && h == 12) {
        h = 0;
      }
      return h * 60 + m;
    } catch (_) {
      return 9 * 60;
    }
  }

  /// Format minutes into standard "HH:MM AM/PM"
  static String minutesToTime(int totalMinutes) {
    final total = totalMinutes % (24 * 60);
    final h24 = total ~/ 60;
    final m = total % 60;
    final period = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final hh = h12.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm $period';
  }

  /// Parse opening hours string into numeric window
  static _OpenWindow? parseOpeningHours(String raw) {
    try {
      final clean = raw.trim();
      final parts = clean.split(RegExp(r'[-–—to]'));
      if (parts.length >= 2) {
        final openMin = timeToMinutes(parts[0].trim());
        final closeMin = timeToMinutes(parts[1].trim());
        if (closeMin > openMin) {
          return _OpenWindow(openMin, closeMin);
        }
      }
    } catch (_) {}
    return null;
  }
}

class _RouteSegment {
  final List<ItineraryStop> freeStops;
  final double segmentStartLat;
  final double segmentStartLng;
  final ItineraryStop? anchorStop;

  _RouteSegment({
    required this.freeStops,
    required this.segmentStartLat,
    required this.segmentStartLng,
    required this.anchorStop,
  });
}

class _OpenWindow {
  final int openMinutes;
  final int closeMinutes;
  const _OpenWindow(this.openMinutes, this.closeMinutes);
}

class _TimeRecalculationResult {
  final List<ItineraryStop> orderedStops;
  final List<ItineraryStop> overflowStops;
  _TimeRecalculationResult({
    required this.orderedStops,
    required this.overflowStops,
  });
}
