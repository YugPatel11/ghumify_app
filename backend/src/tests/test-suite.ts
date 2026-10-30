import assert from 'node:assert';
import { maskPlaceholders, restorePlaceholders } from '../lib/translation/placeholder';
import { isLanguageSupported, getLanguageMetadata, SUPPORTED_LANGUAGES } from '../lib/languages';
import { resolveLanguage, parseAcceptLanguage } from '../lib/language-resolution';
import { computeSourceHash } from '../lib/translation/provider';
import { getDb } from '../lib/db';

async function runAllTests() {
  console.log('🧪 Starting Ghumify Localization & Translation Test Suite...\n');
  let passed = 0;
  let failed = 0;

  function test(name: string, fn: () => void | Promise<void>) {
    try {
      fn();
      console.log(`  ✓ ${name}`);
      passed++;
    } catch (err: any) {
      console.error(`  ✗ ${name}`);
      console.error(`    ${err.message}`);
      failed++;
    }
  }

  // 1. Supported Languages
  test('Supported languages includes at least required languages (en, hi, es, fr, de, pt, ar, bn, ta, te, mr, ur, zh, ja, ru)', () => {
    const required = ['en', 'hi', 'es', 'fr', 'de', 'pt', 'ar', 'bn', 'ta', 'te', 'mr', 'ur', 'zh', 'ja', 'ru'];
    for (const code of required) {
      assert.strictEqual(isLanguageSupported(code), true, `Language ${code} should be supported`);
    }
    assert.strictEqual(isLanguageSupported('klingon'), false, 'Unsupported language should return false');
  });

  test('Arabic and Urdu have RTL direction', () => {
    const ar = getLanguageMetadata('ar');
    assert.strictEqual(ar?.direction, 'rtl');
    const ur = getLanguageMetadata('ur');
    assert.strictEqual(ur?.direction, 'rtl');

    const hi = getLanguageMetadata('hi');
    assert.strictEqual(hi?.direction, 'ltr');
  });

  // 2. Placeholder Protection & Restoration
  test('Masks ICU placeholders, URLs, and brand names correctly', () => {
    const original = 'Welcome to Ghumify! You have {count} hours in {city}. Visit https://ghumify.app for details.';
    const { masked, tokens } = maskPlaceholders(original);

    assert.ok(!masked.includes('{count}'), 'ICU placeholder should be masked');
    assert.ok(!masked.includes('{city}'), 'ICU placeholder should be masked');
    assert.ok(!masked.includes('https://ghumify.app'), 'URL should be masked');
    assert.ok(!masked.includes('Ghumify'), 'Brand name should be masked');

    // Simulate translation preserving tokens
    const simulatedTranslation = masked.replace('Welcome to', 'Bienvenue sur');
    const { text, intact } = restorePlaceholders(simulatedTranslation, tokens);

    assert.strictEqual(intact, true, 'Placeholders should be marked intact');
    assert.ok(text.includes('{count}'), 'Restored text should contain {count}');
    assert.ok(text.includes('{city}'), 'Restored text should contain {city}');
    assert.ok(text.includes('https://ghumify.app'), 'Restored text should contain URL');
    assert.ok(text.includes('Ghumify'), 'Restored text should contain brand name');
  });

  test('Detects corrupted or removed tokens', () => {
    const original = 'Hello {name}!';
    const { masked, tokens } = maskPlaceholders(original);
    // Token deleted by broken model
    const brokenTranslation = 'Hola!';
    const { intact } = restorePlaceholders(brokenTranslation, tokens);
    assert.strictEqual(intact, false, 'Should flag corrupted token');
  });

  // 3. Language Resolution Order
  test('Language resolution follows priority: user pref > query/header > accept-language > default en', () => {
    // 3a. Accept-language header parsing
    const parsed = parseAcceptLanguage('fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7');
    assert.deepStrictEqual(parsed, ['fr-CH', 'fr', 'en', 'de']);

    // 3b. Fallback to default en
    const defaultLang = resolveLanguage({});
    assert.strictEqual(defaultLang, 'en');

    // 3c. Accept-Language resolution
    const headerLang = resolveLanguage({ acceptLanguageHeader: 'es-ES, es;q=0.9, en;q=0.8' });
    assert.strictEqual(headerLang, 'es');

    // 3d. Explicit queryLang overrides accept-language
    const queryOverride = resolveLanguage({
      queryLang: 'fr',
      acceptLanguageHeader: 'es-ES, es;q=0.9',
    });
    assert.strictEqual(queryOverride, 'fr');

    // 3e. User profile preference overrides query/header
    const userPref = resolveLanguage({
      userId: 'user_demo',
      queryLang: 'fr',
    });
    // user_demo was seeded with 'en'
    assert.strictEqual(userPref, 'en');
  });

  // 4. Source Hash Computation & Cache
  test('Source text hash is deterministic SHA-256', () => {
    const text1 = 'Explore local markets';
    const text2 = 'Explore local markets';
    const text3 = 'Explore different markets';

    assert.strictEqual(computeSourceHash(text1), computeSourceHash(text2));
    assert.notStrictEqual(computeSourceHash(text1), computeSourceHash(text3));
  });

  // 5. Database Schema & Persistence
  test('SQLite database operations: translations and user preferred language', () => {
    const db = getDb();
    const testKey = 'test.unique_key';
    const testLang = 'hi';
    const testHash = computeSourceHash('Sample Source');

    // Upsert translation
    db.prepare(`
      INSERT INTO translations (id, namespace, key, source_hash, source_text, language, translated_text, provider, is_manual, created_at, updated_at)
      VALUES (?, 'test', ?, ?, 'Sample Source', ?, 'नमूना स्रोत', 'test', 0, ?, ?)
      ON CONFLICT(key, language) DO UPDATE SET translated_text = excluded.translated_text
    `).run(`${testKey}_${testLang}`, testKey, testHash, testLang, new Date().toISOString(), new Date().toISOString());

    const row = db.prepare('SELECT translated_text FROM translations WHERE key = ? AND language = ?').get(testKey, testLang) as any;
    assert.strictEqual(row?.translated_text, 'नमूना स्रोत');

    // Update user preferred language
    db.prepare('UPDATE users SET preferred_language = ? WHERE id = ?').run('hi', 'user_demo');
    const userRow = db.prepare('SELECT preferred_language FROM users WHERE id = ?').get('user_demo') as any;
    assert.strictEqual(userRow?.preferred_language, 'hi');

    // Revert user preference back to 'en'
    db.prepare('UPDATE users SET preferred_language = ? WHERE id = ?').run('en', 'user_demo');
  });

  // 6. Speech-to-Text Audio Validation & Locales
  const { validateAudioData, sanitizeTranscript } = await import('../lib/speech/audio-validator');
  const { getSpeechLocale } = await import('../lib/speech/locale-map');

  test('Speech locale maps languages to correct regional audio recognition tags', () => {
    assert.strictEqual(getSpeechLocale('hi'), 'hi-IN');
    assert.strictEqual(getSpeechLocale('ar'), 'ar-SA');
    assert.strictEqual(getSpeechLocale('ur'), 'ur-PK');
    assert.strictEqual(getSpeechLocale('fr'), 'fr-FR');
    assert.strictEqual(getSpeechLocale('en'), 'en-US');
  });

  test('Audio validation accepts supported formats and rejects invalid payloads', () => {
    const validBuffer = Buffer.from('RIFF....WAVEfmt '); // Fake wav header buffer
    const validRes = validateAudioData(validBuffer, 'audio/wav');
    assert.strictEqual(validRes.valid, true);

    const emptyRes = validateAudioData(Buffer.alloc(0), 'audio/wav');
    assert.strictEqual(emptyRes.valid, false);
    assert.strictEqual(emptyRes.errorCode, 'EMPTY_AUDIO');

    const badMimeRes = validateAudioData(validBuffer, 'video/mp4');
    assert.strictEqual(badMimeRes.valid, false);
    assert.strictEqual(badMimeRes.errorCode, 'UNSUPPORTED_MIME_TYPE');
  });

  test('Transcript sanitization strips dangerous characters and trims text', () => {
    const malicious = '  <script>alert(1)</script>Hello Indore!  ';
    const clean = sanitizeTranscript(malicious);
    assert.strictEqual(clean, 'scriptalert(1)/scriptHello Indore!');
  });

  console.log(`\n========================================`);
  console.log(`Total: ${passed + failed} | Passed: ${passed} | Failed: ${failed}`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runAllTests();
