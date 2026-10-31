import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghumify_app/core/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TranslationService().clearCache();
  });

  group('Sarvam AI Translation Service Tests', () {
    test('English language returns original text without API calls', () async {
      final service = TranslationService();
      final result = await service.translateText('Hello world', targetLang: 'en');
      expect(result, 'Hello world');
    });

    test('Numbers, times, currencies, and emails bypass translation', () async {
      final service = TranslationService();
      expect(await service.translateText('12:30 PM', targetLang: 'hi'), '12:30 PM');
      expect(await service.translateText('₹500', targetLang: 'hi'), '₹500');
      expect(await service.translateText('12345', targetLang: 'gu'), '12345');
      expect(await service.translateText('support@ghumify.com', targetLang: 'hi'), 'support@ghumify.com');
      expect(await service.translateText('Ghumify', targetLang: 'hi'), 'Ghumify');
    });

    test('Memory cache works synchronously for already translated strings', () async {
      final service = TranslationService();
      
      // Initially not cached
      expect(service.getCached('Explore Trips', targetLang: 'hi'), isNull);

      // Pre-seed persistent cache
      SharedPreferences.setMockInitialValues({
        'ghumify_tr_cache_hi': '{"Explore Trips": "यात्राएं देखें"}',
      });

      // Calling translate loads cache
      final translated = await service.translateText('Explore Trips', targetLang: 'hi');
      expect(translated, 'यात्राएं देखें');

      // Now synchronous lookup returns it immediately
      expect(service.getCached('Explore Trips', targetLang: 'hi'), 'यात्राएं देखें');
    });

    test('Batch translation preserves list order and returns results', () async {
      final service = TranslationService();
      final texts = ['Hello', '12:30 PM', '₹100'];
      final results = await service.translateBatch(texts: texts, targetLanguage: 'en');
      expect(results, ['Hello', '12:30 PM', '₹100']);
    });
  });
}
