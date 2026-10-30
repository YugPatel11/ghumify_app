/// Age band identifiers for minors
class MinorAgeBand {
  static const String toddler = '0-2'; // Infant / Toddler (0 to 2)
  static const String youngChild = '3-5'; // Young Child (3 to 5)
  static const String child = '6-12'; // Child (6 to 12)
  static const String teen = '13-17'; // Teen (13 to 17)

  static const List<String> all = [toddler, youngChild, child, teen];

  static String getLabel(String band) {
    switch (band) {
      case toddler:
        return 'Infant / Toddler (0–2 yrs)';
      case youngChild:
        return 'Young Child (3–5 yrs)';
      case child:
        return 'Child (6–12 yrs)';
      case teen:
        return 'Teen (13–17 yrs)';
      default:
        return band;
    }
  }

  static String getShortLabel(String band) {
    switch (band) {
      case toddler:
        return '0–2 yrs';
      case youngChild:
        return '3–5 yrs';
      case child:
        return '6–12 yrs';
      case teen:
        return '13–17 yrs';
      default:
        return band;
    }
  }
}

/// Represents the travelers composition for an itinerary
/// Respects DPDP Act privacy: stores counts and age bands only, NO personal data.
class TravelersModel {
  static const int minAdults = 1;
  static const int maxAdults = 20;
  static const int minMinors = 0;
  static const int maxMinors = 20;

  final int adults;
  final int minors;
  final List<String> minorAgeBands;

  const TravelersModel({
    int adults = 1,
    int minors = 0,
    this.minorAgeBands = const [],
  })  : adults = adults < minAdults ? minAdults : (adults > maxAdults ? maxAdults : adults),
        minors = minors < minMinors ? minMinors : (minors > maxMinors ? maxMinors : minors);

  bool get hasMinors => minors > 0;
  bool get isSolo => adults == 1 && minors == 0;
  bool get isSoloTrip => isSolo;
  bool get isFamilyFriendly => hasMinors;
  int get totalCount => adults + minors;

  List<String> get effectiveAgeBands {
    if (minors > 0 && minorAgeBands.isEmpty) {
      return const [MinorAgeBand.child];
    }
    return minorAgeBands;
  }

  bool get isAgeBandSkipped => minors > 0 && minorAgeBands.isEmpty;

  /// User-friendly summary (e.g. "2 Adults, 2 Children (Ages 3–5 yrs, 6–12 yrs)")
  String get summary {
    if (isSolo) return '1 Adult (Solo)';
    final adultsText = '$adults ${adults == 1 ? 'Adult' : 'Adults'}';
    if (minors == 0) return adultsText;

    final minorsText = '$minors ${minors == 1 ? 'Child' : 'Children'}';
    if (minorAgeBands.isEmpty) {
      return '$adultsText, $minorsText (Ages 6–12 (General mix))';
    }

    final bandsList = minorAgeBands.map(MinorAgeBand.getShortLabel).join(', ');
    return '$adultsText, $minorsText (Ages $bandsList)';
  }

  /// Compact badge string (e.g. "2 Adults, 2 Children" or "2 Adults")
  String get compactBadge {
    if (isSolo) return '1 Adult';
    if (minors == 0) return '$adults Adults';
    return '$adults Adults, $minors Children';
  }

  String get compactSummary => compactBadge;

  static int normalizeCount(dynamic val, {required int min, required int max, required int fallback}) {
    if (val == null) return fallback;
    final parsed = (val is num) ? val.toInt() : int.tryParse(val.toString().trim());
    if (parsed == null) return fallback;
    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  Map<String, dynamic> toMap() {
    return {
      'adults': adults,
      'minors': minors,
      'minorAgeBands': minorAgeBands,
      'summary': summary,
    };
  }

  factory TravelersModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const TravelersModel(adults: 1, minors: 0, minorAgeBands: []);
    }

    int parsedAdults = (data['adults'] as num?)?.toInt() ??
        (data['travelers'] as num?)?.toInt() ??
        1;
    if (parsedAdults < minAdults) parsedAdults = minAdults;
    if (parsedAdults > maxAdults) parsedAdults = maxAdults;

    int parsedMinors = (data['minors'] as num?)?.toInt() ??
        (data['minorsCount'] as num?)?.toInt() ??
        0;
    if (parsedMinors < minMinors) parsedMinors = minMinors;
    if (parsedMinors > maxMinors) parsedMinors = maxMinors;

    final bands = List<String>.from(data['minorAgeBands'] ?? []);

    return TravelersModel(
      adults: parsedAdults,
      minors: parsedMinors,
      minorAgeBands: bands,
    );
  }

  TravelersModel copyWith({
    int? adults,
    int? minors,
    List<String>? minorAgeBands,
  }) {
    return TravelersModel(
      adults: adults ?? this.adults,
      minors: minors ?? this.minors,
      minorAgeBands: minorAgeBands ?? this.minorAgeBands,
    );
  }
}
