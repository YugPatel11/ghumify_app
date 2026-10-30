enum LocalChatIntentType {
  addFood,
  removeStop,
  replaceStop,
  lessTime,
  moreRelaxed,
  nearestService,
  translateCached,
  help,
  unknown,
}

enum ServiceType {
  hospital,
  pharmacy,
  atm,
  police,
  restroom,
  petrol,
}

class ParsedIntent {
  final LocalChatIntentType type;
  final ServiceType? serviceType;
  final int? targetStopIndex; // 0-indexed
  final String? targetStopName;
  final int? targetDayNumber; // 1-indexed for multi-day
  final String? translateText;
  final String? targetLanguage;
  final bool isAmbiguous;
  final String? ambiguityReason;

  const ParsedIntent({
    required this.type,
    this.serviceType,
    this.targetStopIndex,
    this.targetStopName,
    this.targetDayNumber,
    this.translateText,
    this.targetLanguage,
    this.isAmbiguous = false,
    this.ambiguityReason,
  });
}

class IntentParser {
  static const Map<String, int> _ordinals = {
    'first': 0,
    '1st': 0,
    'pehla': 0,
    'pehli': 0,
    'initial': 0,
    'second': 1,
    '2nd': 1,
    'dusra': 1,
    'dusri': 1,
    'third': 2,
    '3rd': 2,
    'teesra': 2,
    'teesri': 2,
    'fourth': 3,
    '4th': 3,
    'chautha': 3,
    'fifth': 4,
    '5th': 4,
    'paanchwa': 4,
    'last': -1,
    'aakhri': -1,
    'antim': -1,
  };

  static String normalize(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), ' ');
  }

  static ParsedIntent parse({
    required String message,
    required List<String> currentStopNames,
    int? currentDayNumber,
    int totalDays = 1,
  }) {
    final raw = message.trim();
    final norm = normalize(raw);

    if (norm.isEmpty) {
      return const ParsedIntent(type: LocalChatIntentType.unknown);
    }

    // 1. Help intent
    if (_matches(norm, ['help', 'madad', 'commands', 'options', 'kya kar sakte ho', 'menu', 'guide'])) {
      return const ParsedIntent(type: LocalChatIntentType.help);
    }

    // 2. Nearest Emergency / Essential Services
    final serviceMatch = _detectService(norm);
    if (serviceMatch != null) {
      return ParsedIntent(
        type: LocalChatIntentType.nearestService,
        serviceType: serviceMatch,
      );
    }

    // 3. Translation
    if (_matches(norm, ['translate', 'anuvad', 'kaise bolte', 'meaning of', 'translate to'])) {
      final textToTranslate = _extractTranslateQuery(raw);
      final targetLang = _detectTargetLanguage(norm);
      return ParsedIntent(
        type: LocalChatIntentType.translateCached,
        translateText: textToTranslate,
        targetLanguage: targetLang,
      );
    }

    // 4. Less Time (Shrink schedule)
    if (_matches(norm, [
      'less time',
      'kam time',
      'kam samay',
      'time kam hai',
      'jaldi khatam',
      'shorter',
      'cut short',
      'tight schedule',
      'shorten',
      'jaldi'
    ])) {
      return const ParsedIntent(type: LocalChatIntentType.lessTime);
    }

    // 5. More Relaxed (Pace expansion)
    if (_matches(norm, [
      'more relaxed',
      'relax',
      'araam se',
      'aram se',
      'dheere',
      'slow down',
      'less packed',
      'peaceful',
      'breathe',
      'fursat'
    ])) {
      return const ParsedIntent(type: LocalChatIntentType.moreRelaxed);
    }

    // Check Day Reference for multi-day
    int? targetDay = currentDayNumber;
    final dayMatch = RegExp(r'day\s*(\d+)|din\s*(\d+)').firstMatch(norm);
    if (dayMatch != null) {
      final numStr = dayMatch.group(1) ?? dayMatch.group(2);
      if (numStr != null) {
        targetDay = int.tryParse(numStr);
      }
    }

    // 6. Add Food
    if (_matches(norm, [
      'add food',
      'food stop',
      'lunch',
      'dinner',
      'breakfast',
      'khana',
      'khaana',
      'bhookh',
      'bhook',
      'restaurant',
      'cafe',
      'dhaba',
      'nashta',
      'snack',
      'eat'
    ])) {
      return ParsedIntent(
        type: LocalChatIntentType.addFood,
        targetDayNumber: targetDay,
      );
    }

    // Check stop references by ordinal or name
    final stopRef = _extractStopReference(norm, currentStopNames);

    // 7. Remove Stop
    if (_matches(norm, ['remove', 'delete', 'hata do', 'hatao', 'nikal do', 'drop', 'skip', 'chhod do', 'cut'])) {
      if (stopRef.isAmbiguous) {
        return ParsedIntent(
          type: LocalChatIntentType.removeStop,
          isAmbiguous: true,
          ambiguityReason: 'Which stop would you like to remove? Please name the place.',
        );
      }
      return ParsedIntent(
        type: LocalChatIntentType.removeStop,
        targetStopIndex: stopRef.index,
        targetStopName: stopRef.name,
        targetDayNumber: targetDay,
      );
    }

    // 8. Replace Stop
    if (_matches(norm, ['replace', 'badal do', 'badlo', 'swap', 'change', 'kuch aur', 'dusra dikhao', 'alternative'])) {
      if (stopRef.isAmbiguous) {
        return ParsedIntent(
          type: LocalChatIntentType.replaceStop,
          isAmbiguous: true,
          ambiguityReason: 'Which stop would you like to replace? Please specify the place name.',
        );
      }
      return ParsedIntent(
        type: LocalChatIntentType.replaceStop,
        targetStopIndex: stopRef.index,
        targetStopName: stopRef.name,
        targetDayNumber: targetDay,
      );
    }

    return const ParsedIntent(type: LocalChatIntentType.unknown);
  }

  static bool _matches(String text, List<String> patterns) {
    for (final p in patterns) {
      if (text.contains(p)) return true;
    }
    return false;
  }

  static ServiceType? _detectService(String text) {
    if (_matches(text, ['hospital', 'doctor', 'aspataal', 'clinic', 'emergency', 'ilaj'])) {
      return ServiceType.hospital;
    }
    if (_matches(text, ['pharmacy', 'chemist', 'dawa', 'medical store', 'medicine'])) {
      return ServiceType.pharmacy;
    }
    if (_matches(text, ['atm', 'cash', 'paise', 'bank'])) {
      return ServiceType.atm;
    }
    if (_matches(text, ['police', 'thana', 'kotwali', 'cop', 'suraksha'])) {
      return ServiceType.police;
    }
    if (_matches(text, ['toilet', 'washroom', 'restroom', 'bathroom', 'shauchalay'])) {
      return ServiceType.restroom;
    }
    if (_matches(text, ['petrol', 'diesel', 'fuel', 'gas station', 'pump'])) {
      return ServiceType.petrol;
    }
    return null;
  }

  static String _extractTranslateQuery(String raw) {
    final lower = raw.toLowerCase();
    final prefixes = ['translate', 'meaning of', 'how to say', 'kaise bolte hain'];
    for (final p in prefixes) {
      final idx = lower.indexOf(p);
      if (idx != -1) {
        final remaining = raw.substring(idx + p.length).trim();
        return remaining.replaceAll(RegExp(r'^[:"“”]+|[:"“”]+$'), '').trim();
      }
    }
    return raw;
  }

  static String _detectTargetLanguage(String norm) {
    if (norm.contains('hindi') || norm.contains('हिंदी')) return 'hi';
    if (norm.contains('english') || norm.contains('angrezi')) return 'en';
    if (norm.contains('spanish') || norm.contains('espanol')) return 'es';
    if (norm.contains('french') || norm.contains('francais')) return 'fr';
    return 'hi';
  }

  static ({int? index, String? name, bool isAmbiguous}) _extractStopReference(
    String norm,
    List<String> currentStopNames,
  ) {
    // 1. Check ordinals first
    for (final entry in _ordinals.entries) {
      if (norm.contains(entry.key)) {
        final targetIdx = entry.value == -1
            ? (currentStopNames.isNotEmpty ? currentStopNames.length - 1 : null)
            : entry.value;

        if (targetIdx != null && targetIdx >= 0 && targetIdx < currentStopNames.length) {
          return (index: targetIdx, name: currentStopNames[targetIdx], isAmbiguous: false);
        }
      }
    }

    // 2. Fuzzy name match against current stops
    final matchedIndices = <int>[];
    for (int i = 0; i < currentStopNames.length; i++) {
      final stopNameNorm = normalize(currentStopNames[i]);
      final words = stopNameNorm.split(' ').where((w) => w.length > 2);
      for (final w in words) {
        if (norm.contains(w)) {
          matchedIndices.add(i);
          break;
        }
      }
    }

    if (matchedIndices.length == 1) {
      final idx = matchedIndices.first;
      return (index: idx, name: currentStopNames[idx], isAmbiguous: false);
    } else if (matchedIndices.length > 1) {
      return (index: null, name: null, isAmbiguous: true);
    }

    return (index: null, name: null, isAmbiguous: false);
  }
}

