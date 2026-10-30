import 'package:flutter/material.dart';

/// Clean internal values for food preferences
class FoodPreference {
  static const String veg = 'veg';
  static const String vegEgg = 'veg_egg';
  static const String jain = 'jain';
  static const String nonVeg = 'non_veg';
  static const String all = 'all';

  static const List<String> values = [
    veg,
    vegEgg,
    jain,
    nonVeg,
    all,
  ];

  static bool isValid(String? value) {
    return value != null && values.contains(value);
  }

  static String normalize(String? value) {
    if (value != null && values.contains(value)) {
      return value;
    }
    return all;
  }

  static String getLabel(String value) {
    switch (value) {
      case veg:
        return 'Veg';
      case vegEgg:
        return 'Veg + Egg';
      case jain:
        return 'Jain';
      case nonVeg:
        return 'Non-Veg';
      case all:
      default:
        return 'All';
    }
  }

  static String getExplanation(String value) {
    switch (value) {
      case veg:
        return 'No meat, fish, or eggs. Dairy is fine.';
      case vegEgg:
        return 'Vegetarian food plus eggs. No meat or fish.';
      case jain:
        return 'Strict vegetarian with no root vegetables (such as onion, garlic, potato, carrot, radish, and beetroot), no eggs, and no meat or fish.';
      case nonVeg:
        return 'Meat, fish, and eggs are welcome.';
      case all:
      default:
        return 'A mix of everything.';
    }
  }

  static Color getIndicatorColor(String value) {
    switch (value) {
      case veg:
        return const Color(0xFF10B981); // Emerald Green
      case vegEgg:
        return const Color(0xFFF59E0B); // Amber / Yellow
      case jain:
        return const Color(0xFF059669); // Deep Green
      case nonVeg:
        return const Color(0xFFEF4444); // Red
      case all:
      default:
        return const Color(0xFF94A3B8); // Slate / Neutral
    }
  }

  static Widget getIndicatorDot(String value, {double size = 12}) {
    switch (value) {
      case veg:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        );
      case vegEgg:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        );
      case jain:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF059669),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        );
      case nonVeg:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        );
      case all:
      default:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF94A3B8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        );
    }
  }

  /// Strictness rank: Jain (4) > Veg (3) > Veg+Egg (2) > Non-Veg (1) > All (0)
  static int getStrictnessRank(String value) {
    switch (value) {
      case jain:
        return 4;
      case veg:
        return 3;
      case vegEgg:
        return 2;
      case nonVeg:
        return 1;
      case all:
      default:
        return 0;
    }
  }
}

/// Central rules engine and post-response validation for dietary preferences
class DietaryFilterService {
  // Disallowed terms for Jain
  static const List<String> jainDisallowedKeywords = [
    'meat', 'chicken', 'mutton', 'fish', 'prawn', 'seafood', 'crab', 'lobster',
    'pork', 'beef', 'bacon', 'sausage', 'egg', 'omelette', 'bhurji',
    'onion', 'garlic', 'pyaz', 'lehsun', 'lasun',
    'potato', 'aloo', 'batata',
    'carrot', 'gajar',
    'radish', 'mooli',
    'beetroot', 'chukandar',
    'ginger', 'adrak',
    'yam', 'jimikand', 'suran',
  ];

  // Disallowed terms for Pure Veg
  static const List<String> vegDisallowedKeywords = [
    'meat', 'chicken', 'mutton', 'fish', 'prawn', 'seafood', 'crab', 'lobster',
    'pork', 'beef', 'bacon', 'sausage', 'egg', 'omelette', 'bhurji',
    'kabab', 'kebab', 'tandoori chicken', 'biryani non-veg', 'gosht',
  ];

  // Disallowed terms for Veg + Egg (meat/fish disallowed, eggs allowed)
  static const List<String> vegEggDisallowedKeywords = [
    'meat', 'chicken', 'mutton', 'fish', 'prawn', 'seafood', 'crab', 'lobster',
    'pork', 'beef', 'bacon', 'sausage', 'gosht',
  ];

  /// Get AI prompt directives for a chosen food preference
  static String getPromptDirective(String preference) {
    switch (preference) {
      case FoodPreference.veg:
        return '''
CRITICAL DIETARY RULE — PURE VEGETARIAN:
- The traveler strictly eats VEGETARIAN food only.
- ZERO meat, poultry, fish, seafood, or eggs under ANY circumstances.
- Dairy products (milk, paneer, butter, ghee, curd) are allowed.
- You MUST recommend only pure vegetarian restaurants or places with certified separate veg kitchens.
- Explicitly state whether each food spot is "Pure Veg" or "Has Veg Options".
- Do NOT suggest any non-veg or egg dishes.
''';

      case FoodPreference.vegEgg:
        return '''
CRITICAL DIETARY RULE — VEGETARIAN + EGG:
- The traveler eats vegetarian food plus EGG dishes (e.g., omelettes, egg bhurji, egg curry, egg rolls).
- ZERO meat, poultry, fish, seafood, pork, or beef.
- Suggest vegetarian cafes, pure-veg spots, and breakfast cafes famous for egg dishes.
- Clearly differentiate vegetarian dishes from egg dishes.
''';

      case FoodPreference.jain:
        return '''
CRITICAL DIETARY RULE — STRICT JAIN FOOD:
- The traveler strictly eats JAIN FOOD ONLY.
- ZERO meat, fish, poultry, seafood, or eggs.
- ZERO ROOT VEGETABLES: absolutely NO onion, NO garlic, NO potato, NO carrot, NO radish, NO beetroot, and NO ginger.
- Recommend authentic pure-veg restaurants that explicitly serve Jain food or can prepare meals without onion, garlic, and root vegetables.
- Suggest dishes that are naturally Jain or easily prepared Jain (e.g., Jain Paneer, Jain Dal, Jain Thali, Poha without onion/potato).
- You MUST add this exact advisory note for every food stop: "Please confirm Jain preparation with the restaurant."
''';

      case FoodPreference.nonVeg:
        return '''
DIETARY PREFERENCE — NON-VEGETARIAN:
- Prioritize famous non-vegetarian delicacies and renowned local meat/seafood restaurants (e.g., authentic kebabs, biryanis, fish curries).
- You may still include a few iconic pure-veg snack or sweet spots if they are legendary in the city.
''';

      case FoodPreference.all:
      default:
        return '''
DIETARY PREFERENCE — ALL (BALANCED MIX):
- Provide a vibrant, balanced culinary mix of the city's best vegetarian and non-vegetarian specialties, street food, and cafes.
''';
    }
  }

  /// Get AI prompt directives for group itinerary planning with multiple dietary preferences
  static String getGroupPromptDirective(List<String> memberPreferences) {
    if (memberPreferences.isEmpty) return getPromptDirective(FoodPreference.all);

    final uniquePrefs = memberPreferences.map(FoodPreference.normalize).toSet().toList();
    if (uniquePrefs.length == 1) {
      return getPromptDirective(uniquePrefs.first);
    }

    final hasJain = uniquePrefs.contains(FoodPreference.jain);
    final hasVeg = uniquePrefs.contains(FoodPreference.veg);
    final hasVegEgg = uniquePrefs.contains(FoodPreference.vegEgg);
    final hasNonVeg = uniquePrefs.contains(FoodPreference.nonVeg);

    final summary = uniquePrefs.map(FoodPreference.getLabel).join(', ');

    return '''
GROUP DIETARY HARMONIZATION:
- Group members have differing food preferences: $summary.
- Suggest restaurants and food venues that work for EVERYONE in the group.
- For each food stop, clearly mention who each dish or section suits.
${hasJain ? '- CRITICAL: Since there are JAIN members in the group, ensure pure-veg restaurants with authentic Jain-friendly options (no root vegetables, onion, garlic) are prioritized, or multi-cuisine restaurants with separate Jain kitchens.' : ''}
${hasJain && hasNonVeg ? '- CONFLICT DETECTED: The group includes both Jain and Non-Vegetarian travelers. Prioritize restaurants with clearly separated vegetarian/Jain and non-vegetarian preparation areas, or pure-vegetarian venues with standout menus so no member is left out.' : ''}
${hasVeg && !hasJain ? '- Since there are pure vegetarian members, ensure dedicated pure-veg restaurants or places with certified separate veg kitchens are chosen.' : ''}
${hasVegEgg ? '- Vegetarian + egg options should be highlighted where available.' : ''}
''';
  }

  /// Get chatbot instructions for dietary preferences, including handling conflicting requests
  static String getChatbotDirective(String preference) {
    final label = FoodPreference.getLabel(preference);
    return '''
USER FOOD PREFERENCE: $label ($preference)
${getPromptDirective(preference)}
CHATBOT DIETARY BEHAVIOR:
1. When suggesting food, cafes, snacks, or restaurants, strictly follow the $label food preference.
2. If the user explicitly asks for something that CONFLICTS with their saved preference (e.g. a Veg user asking for "best butter chicken" or a Jain user asking for "famous aloo paratha"):
   - Warmly and politely acknowledge their saved preference: "Since your food preference is set to $label, please note this dish contains non-conforming ingredients..."
   - Then answer their question helpfully, and remind them they can easily update their Food Preference in Settings or Trip Planning anytime.
''';
  }

  /// Inspect a stop/dish text and verify compliance with user preference
  static bool isCompliant(String preference, String text) {
    final lower = text.toLowerCase();
    switch (preference) {
      case FoodPreference.jain:
        for (final kw in jainDisallowedKeywords) {
          if (_containsWord(lower, kw)) return false;
        }
        return true;

      case FoodPreference.veg:
        for (final kw in vegDisallowedKeywords) {
          if (_containsWord(lower, kw)) return false;
        }
        return true;

      case FoodPreference.vegEgg:
        for (final kw in vegEggDisallowedKeywords) {
          if (_containsWord(lower, kw)) return false;
        }
        return true;

      case FoodPreference.nonVeg:
      case FoodPreference.all:
      default:
        return true;
    }
  }

  /// Resolve dietary type tag for a place or stop
  static String inferDietaryType(String text, {String? preference}) {
    final lower = text.toLowerCase();

    // Check non-veg keywords
    for (final kw in vegEggDisallowedKeywords) {
      if (_containsWord(lower, kw)) return FoodPreference.nonVeg;
    }

    // Check egg keywords
    if (_containsWord(lower, 'egg') ||
        _containsWord(lower, 'omelette') ||
        _containsWord(lower, 'bhurji')) {
      return FoodPreference.vegEgg;
    }

    // Check Jain keywords
    if (lower.contains('jain') || preference == FoodPreference.jain) {
      return FoodPreference.jain;
    }

    return FoodPreference.veg;
  }

  static bool _containsWord(String text, String word) {
    final pattern = RegExp(r'\b' + RegExp.escape(word) + r'(?:s|es)?\b', caseSensitive: false);
    return pattern.hasMatch(text);
  }
}
