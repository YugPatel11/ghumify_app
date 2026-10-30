import '../models/travelers_model.dart';
import '../models/itinerary_model.dart';

/// Centralized service and rules engine for family-friendly and traveler-tailored trips
class FamilyTravelService {
  FamilyTravelService._();

  /// Forbidden keywords that are strictly prohibited when minors/children are traveling
  static const List<String> forbiddenMinorsKeywords = [
    'bar',
    'pub',
    'nightclub',
    'night club',
    'disco',
    'discotheque',
    'brewery',
    'microbrewery',
    'hookah',
    'sheesha',
    'casino',
    'adult lounge',
    'wine tasting',
    'tavern',
  ];

  /// Recommended place categories when children are in the group
  static const List<String> kidFriendlyKeywords = [
    'park',
    'garden',
    'playground',
    'zoo',
    'aquarium',
    'planetarium',
    'science',
    'museum',
    'theme park',
    'amusement park',
    'water park',
    'boating',
    'lake',
    'toy train',
    'safari',
    'puppet',
    'ice cream',
    'dessert',
  ];

  /// Generate prompt directive for Gemini AI itinerary generation
  static String getTravelersPromptDirective(TravelersModel travelers) {
    if (!travelers.hasMinors) {
      if (travelers.isSolo) {
        return 'TRAVELERS: Solo adult traveler. Focus on flexible, enriching, and safe solo exploration.';
      }
      return 'TRAVELERS: Group of ${travelers.adults} adults. Tailor pacing and dining for an adult party.';
    }

    final hasToddler = travelers.minorAgeBands.contains(MinorAgeBand.toddler);
    final hasYoungChild = travelers.minorAgeBands.contains(MinorAgeBand.youngChild);
    final hasChild = travelers.minorAgeBands.contains(MinorAgeBand.child);
    final hasTeen = travelers.minorAgeBands.contains(MinorAgeBand.teen);

    final buffer = StringBuffer();
    buffer.writeln('FAMILY & TRAVELERS COMPOSITION:');
    buffer.writeln('- Adults: ${travelers.adults}');
    buffer.writeln('- Children (Minors): ${travelers.minors}');
    if (travelers.minorAgeBands.isNotEmpty) {
      buffer.writeln(
          '- Age Bands: ${travelers.minorAgeBands.map(MinorAgeBand.getLabel).join(", ")}');
    } else {
      buffer.writeln('- Age Bands: General children mix (ages 6–12 default)');
    }

    buffer.writeln('\nMANDATORY FAMILY & CHILD-FRIENDLY PLANNING DIRECTIVE:');
    buffer.writeln('1. This trip includes children. Prioritize family- and kid-friendly venues: city parks, gardens, playgrounds, science centers, zoos, aquariums, theme/amusement parks, cultural shows, boating, and dessert spots.');
    buffer.writeln('2. Balance: Mix in top cultural monuments that both adults and kids will appreciate, avoiding boredom.');

    if (hasToddler) {
      buffer.writeln('3. INFANT / TODDLER CARE (0–2 yrs): Include an afternoon rest/nap break (around 1:30 PM – 3:30 PM). Keep walks short, flat, and stroller-accessible. Avoid places with steep climbs or long queues.');
    }
    if (hasYoungChild) {
      buffer.writeln('4. YOUNG CHILDREN (3–5 yrs): Keep activity duration to 60–90 minutes max. Prefer open spaces, playgrounds, and animal or interactive attractions.');
    }
    if (hasChild) {
      buffer.writeln('5. CHILDREN (6–12 yrs): Include engaging science exhibits, interactive planetariums, forts with stories, and boat rides.');
    }
    if (hasTeen) {
      buffer.writeln('6. TEENS (13–17 yrs): Include photography vantage points, light adventure activities, and vibrant local bazaars.');
    }

    buffer.writeln('7. PACING & SAFETY:');
    buffer.writeln('   - Limit stops to 3–4 quality stops per day with comfortable transit times.');
    buffer.writeln('   - NEVER schedule bars, pubs, nightclubs, breweries, hookah lounges, or high-risk cliff edges.');
    buffer.writeln('   - All day activities must conclude by 8:30 PM.');
    buffer.writeln('   - For food stops, pick family-friendly restaurants with comfortable seating.');
    buffer.writeln('8. STOP METADATA FIELDS:');
    buffer.writeln('   - Set "isKidFriendly": true on family-appropriate stops.');
    buffer.writeln('   - Set "ageRangeRecommendation": e.g. "All ages", "Ages 3+", "Toddler friendly", or "Teens".');
    buffer.writeln('   - Set "strollerAccess": "yes", "no", or "partial".');
    buffer.writeln('   - Set "childTicketInfo": e.g. "Free under 5 years", "Discounted child ticket available", or "Please check on arrival". NEVER invent fake prices or fake opening hours.');

    return buffer.toString();
  }

  /// Post-response deterministic validator and sanitizer
  /// Guarantees that no unsuitable nightlife or dangerous venues reach families with children.
  static List<ItineraryStop> validateAndEnrichStops(
    List<ItineraryStop> rawStops,
    TravelersModel travelers,
  ) {
    if (!travelers.hasMinors) {
      return rawStops;
    }

    final sanitized = <ItineraryStop>[];

    for (final stop in rawStops) {
      final nameLower = stop.name.toLowerCase();
      final descLower = stop.description.toLowerCase();
      final fullText = '$nameLower $descLower';

      // Check if stop contains forbidden nightlife or adult entertainment terms
      bool isForbidden = false;
      for (final term in forbiddenMinorsKeywords) {
        if (RegExp('\\b${RegExp.escape(term)}\\b').hasMatch(fullText)) {
          isForbidden = true;
          break;
        }
      }

      if (isForbidden) {
        // Replace forbidden venue with a wholesome, family-friendly alternative
        sanitized.add(
          stop.copyWith(
            name: 'City Garden & Cultural Walk',
            type: 'place',
            description:
                'A scenic, family-friendly green park and heritage walking area perfect for all ages to relax.',
            isKidFriendly: true,
            ageRangeRecommendation: 'All ages',
            strollerAccess: 'yes',
            childTicketInfo: 'Free entry for all',
            tips: [
              'Spacious lawns and clean paved walking paths',
              'Ice cream and snack kiosks available nearby',
            ],
          ),
        );
        continue;
      }

      // Check if stop matches kid-friendly keywords
      bool isKid = stop.isKidFriendly;
      if (!isKid) {
        for (final k in kidFriendlyKeywords) {
          if (fullText.contains(k)) {
            isKid = true;
            break;
          }
        }
      }

      // Default safe child ticket info if missing
      String? ticketInfo = stop.childTicketInfo;
      if (ticketInfo == null || ticketInfo.trim().isEmpty) {
        ticketInfo = 'Please check on arrival';
      }

      // Default stroller access if toddler present and missing
      String? stroller = stop.strollerAccess;
      if (stroller == null && travelers.minorAgeBands.contains(MinorAgeBand.toddler)) {
        stroller = (stop.type == 'place' && !nameLower.contains('fort') && !nameLower.contains('climb'))
            ? 'yes'
            : 'partial';
      }

      sanitized.add(
        stop.copyWith(
          isKidFriendly: isKid,
          childTicketInfo: ticketInfo,
          strollerAccess: stroller,
          ageRangeRecommendation: stop.ageRangeRecommendation ??
              (isKid ? 'Family friendly' : 'All ages'),
        ),
      );
    }

    final maxStops = getMaxStopsPerDay(travelers);
    if (sanitized.length > maxStops) {
      return sanitized.sublist(0, maxStops);
    }

    return sanitized;
  }

  /// Max recommended stops per day based on traveler group composition
  static int getMaxStopsPerDay(TravelersModel travelers) {
    if (!travelers.hasMinors) return 8;
    if (travelers.minorAgeBands.contains(MinorAgeBand.toddler) ||
        travelers.minorAgeBands.contains(MinorAgeBand.youngChild)) {
      return 4; // Young children & infants: gentle pace with rest & nap times
    }
    return 5; // School children & teens: active but balanced
  }
}
