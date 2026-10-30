import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/constants/food_preferences.dart';
import 'package:ghumify_app/core/models/user_model.dart';
import 'package:ghumify_app/core/models/itinerary_model.dart';
import 'package:ghumify_app/core/models/multi_day_itinerary_model.dart';
import 'package:ghumify_app/core/models/group_member_model.dart';

void main() {
  group('FoodPreference Constants & Ordering', () {
    test('values contains exactly 5 options in the required order', () {
      expect(FoodPreference.values, [
        'veg',
        'veg_egg',
        'jain',
        'non_veg',
        'all',
      ]);
    });

    test('isValid validates allowed internal values and rejects invalid', () {
      expect(FoodPreference.isValid('veg'), isTrue);
      expect(FoodPreference.isValid('veg_egg'), isTrue);
      expect(FoodPreference.isValid('jain'), isTrue);
      expect(FoodPreference.isValid('non_veg'), isTrue);
      expect(FoodPreference.isValid('all'), isTrue);

      expect(FoodPreference.isValid(null), isFalse);
      expect(FoodPreference.isValid(''), isFalse);
      expect(FoodPreference.isValid('vegan'), isFalse);
      expect(FoodPreference.isValid('halal'), isFalse);
      expect(FoodPreference.isValid('Vegetarian'), isFalse);
    });

    test('normalize defaults legacy / unknown values to all', () {
      expect(FoodPreference.normalize(null), equals(FoodPreference.all));
      expect(FoodPreference.normalize(''), equals(FoodPreference.all));
      expect(FoodPreference.normalize('unknown_value'), equals(FoodPreference.all));
      expect(FoodPreference.normalize('veg'), equals('veg'));
      expect(FoodPreference.normalize('jain'), equals('jain'));
    });

    test('getLabel returns exact human readable names', () {
      expect(FoodPreference.getLabel(FoodPreference.veg), equals('Veg'));
      expect(FoodPreference.getLabel(FoodPreference.vegEgg), equals('Veg + Egg'));
      expect(FoodPreference.getLabel(FoodPreference.jain), equals('Jain'));
      expect(FoodPreference.getLabel(FoodPreference.nonVeg), equals('Non-Veg'));
      expect(FoodPreference.getLabel(FoodPreference.all), equals('All'));
    });

    test('getExplanation returns accurate one-line guidance', () {
      expect(FoodPreference.getExplanation(FoodPreference.veg),
          contains('No meat, fish, or eggs. Dairy is fine.'));
      expect(FoodPreference.getExplanation(FoodPreference.vegEgg),
          contains('Vegetarian food plus eggs. No meat or fish.'));
      expect(FoodPreference.getExplanation(FoodPreference.jain),
          contains('Strict vegetarian with no root vegetables'));
      expect(FoodPreference.getExplanation(FoodPreference.nonVeg),
          contains('Meat, fish, and eggs are welcome.'));
      expect(FoodPreference.getExplanation(FoodPreference.all),
          contains('A mix of everything.'));
    });

    test('strictness rank follows Jain > Veg > Veg+Egg > Non-Veg > All', () {
      final jainRank = FoodPreference.getStrictnessRank(FoodPreference.jain);
      final vegRank = FoodPreference.getStrictnessRank(FoodPreference.veg);
      final vegEggRank = FoodPreference.getStrictnessRank(FoodPreference.vegEgg);
      final nonVegRank = FoodPreference.getStrictnessRank(FoodPreference.nonVeg);
      final allRank = FoodPreference.getStrictnessRank(FoodPreference.all);

      expect(jainRank > vegRank, isTrue);
      expect(vegRank > vegEggRank, isTrue);
      expect(vegEggRank > nonVegRank, isTrue);
      expect(nonVegRank > allRank, isTrue);
    });
  });

  group('DietaryFilterService Compliance & Keywords', () {
    test('Jain compliance rejects meat, eggs, onion, garlic, and root vegetables', () {
      // Disallowed items
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Chicken Tikka'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Fish Curry'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Egg Omelette'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Paneer with onion gravy'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Garlic Naan'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Aloo Paratha'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Carrot halwa (gajar halwa)'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Radish salad (mooli)'), isFalse);

      // Allowed items
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Jain Paneer Butter Masala'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Steamed Basmati Rice with Moong Dal'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.jain, 'Fresh Milk Kulfi and Rabri'), isTrue);
    });

    test('Veg compliance rejects meat, fish, and eggs, but allows root vegetables', () {
      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Mutton Biryani'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Prawns Fry'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Egg Bhurji'), isFalse);

      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Aloo Gobi with Onion Gravy'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Garlic Naan with Dal Makhani'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.veg, 'Paneer Tikka with Mint Chutney'), isTrue);
    });

    test('Veg + Egg compliance allows egg dishes but rejects meat and seafood', () {
      expect(DietaryFilterService.isCompliant(FoodPreference.vegEgg, 'Chicken Biryani'), isFalse);
      expect(DietaryFilterService.isCompliant(FoodPreference.vegEgg, 'Fish Tacos'), isFalse);

      expect(DietaryFilterService.isCompliant(FoodPreference.vegEgg, 'Cheese Omelette with Toast'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.vegEgg, 'Spicy Egg Bhurji'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.vegEgg, 'Paneer Tikka & Roti'), isTrue);
    });

    test('Non-Veg and All compliance allow all foods', () {
      expect(DietaryFilterService.isCompliant(FoodPreference.nonVeg, 'Mutton Biryani'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.nonVeg, 'Paneer Tikka'), isTrue);
      expect(DietaryFilterService.isCompliant(FoodPreference.all, 'Butter Chicken & Naan'), isTrue);
    });

    test('inferDietaryType correctly classifies dishes', () {
      expect(DietaryFilterService.inferDietaryType('Chicken Kebab'), equals(FoodPreference.nonVeg));
      expect(DietaryFilterService.inferDietaryType('Fish Tikka'), equals(FoodPreference.nonVeg));
      expect(DietaryFilterService.inferDietaryType('Egg Curry with Paratha'), equals(FoodPreference.vegEgg));
      expect(DietaryFilterService.inferDietaryType('Jain Dal Baati'), equals(FoodPreference.jain));
      expect(DietaryFilterService.inferDietaryType('Dal Makhani and Roti'), equals(FoodPreference.veg));
    });

    test('Prompt directives contain essential rules for each preference', () {
      final vegDirective = DietaryFilterService.getPromptDirective(FoodPreference.veg);
      expect(vegDirective, contains('PURE VEGETARIAN'));
      expect(vegDirective, contains('ZERO meat, poultry, fish'));

      final jainDirective = DietaryFilterService.getPromptDirective(FoodPreference.jain);
      expect(jainDirective, contains('STRICT JAIN FOOD'));
      expect(jainDirective, contains('ZERO ROOT VEGETABLES'));
      expect(jainDirective, contains('Please confirm Jain preparation with the restaurant.'));

      final chatbotDirective = DietaryFilterService.getChatbotDirective(FoodPreference.veg);
      expect(chatbotDirective, contains('CONFLICTS with their saved preference'));
    });

    test('Group prompt directive identifies conflicts between Jain and Non-Veg', () {
      final groupDirective = DietaryFilterService.getGroupPromptDirective([
        FoodPreference.jain,
        FoodPreference.nonVeg,
      ]);
      expect(groupDirective, contains('CONFLICT DETECTED'));
      expect(groupDirective, contains('Jain and Non-Vegetarian'));
      expect(groupDirective, contains('GROUP DIETARY HARMONIZATION'));
    });
  });

  group('Data Models & Backward Compatibility', () {
    test('UserModel defaults to all if field is absent in legacy record', () {
      final legacyMap = {
        'uid': 'user_123',
        'name': 'Priya Sharma',
        'email': 'priya@example.com',
      };
      final user = UserModel.fromMap(legacyMap);
      expect(user.foodPreference, equals('all'));
    });

    test('UserModel retains explicit foodPreference', () {
      final userMap = {
        'uid': 'user_456',
        'name': 'Rahul Jain',
        'email': 'rahul@example.com',
        'foodPreference': 'jain',
      };
      final user = UserModel.fromMap(userMap);
      expect(user.foodPreference, equals('jain'));

      final firestoreMap = user.toFirestore();
      expect(firestoreMap['foodPreference'], equals('jain'));
    });

    test('ItineraryModel stores and preserves foodPreference', () {
      final itinerary = ItineraryModel(
        id: 'itin_1',
        userId: 'user_1',
        city: 'Jaipur',
        date: '2026-10-30',
        startTime: '09:00',
        endTime: '18:00',
        totalDurationMinutes: 540,
        foodPreference: 'veg',
      );
      expect(itinerary.foodPreference, equals('veg'));
      final map = itinerary.toMap();
      expect(map['foodPreference'], equals('veg'));
    });

    test('ItineraryStop copyWith retains and updates dietaryType', () {
      final stop = ItineraryStop(
        name: 'LMB Laxmi Mishthan Bhandar',
        type: 'food',
        startTime: '13:00',
        endTime: '14:00',
        durationMinutes: 60,
        dietaryType: 'veg',
      );
      expect(stop.dietaryType, equals('veg'));

      final updatedStop = stop.copyWith(dietaryType: 'jain');
      expect(updatedStop.dietaryType, equals('jain'));
      expect(updatedStop.name, equals('LMB Laxmi Mishthan Bhandar'));
    });

    test('MultiDayItineraryModel stores and preserves foodPreference', () {
      final multiDay = MultiDayItineraryModel(
        id: 'multi_1',
        userId: 'user_1',
        city: 'Udaipur',
        startDate: '2026-11-01',
        endDate: '2026-11-03',
        numberOfDays: 3,
        dailyStartTime: '09:00',
        dailyEndTime: '19:00',
        foodPreference: 'veg_egg',
      );
      expect(multiDay.foodPreference, equals('veg_egg'));
      final map = multiDay.toMap();
      expect(map['foodPreference'], equals('veg_egg'));
    });

    test('GroupMemberModel stores and preserves foodPreference', () {
      final member = GroupMemberModel(
        userId: 'm1',
        email: 'member@test.com',
        displayName: 'Aarav',
        foodPreference: 'non_veg',
      );
      expect(member.foodPreference, equals('non_veg'));
      final map = member.toFirestore();
      expect(map['foodPreference'], equals('non_veg'));
    });
  });
}
