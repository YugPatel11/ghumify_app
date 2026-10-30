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

  async function test(name: string, fn: () => void | Promise<void>) {
    try {
      await fn();
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

  // 7. Leave-Time Engine & Routing Tests
  const { LeaveTimeEngine } = await import('../lib/notifications/leave-time-engine');
  const { RoutingProvider } = await import('../lib/notifications/routing-provider');
  const { NotificationService } = await import('../lib/notifications/notification-service');
  const { AlertScheduler } = await import('../lib/notifications/scheduler');

  test('RoutingProvider haversine distance calculates accurate meters', () => {
    // Delhi (28.6139, 77.2090) to Jaipur (26.9124, 75.7873) is ~235 km direct
    const dist = RoutingProvider.haversineMeters(
      { lat: 28.6139, lng: 77.209 },
      { lat: 26.9124, lng: 75.7873 }
    );
    assert.ok(dist > 230000 && dist < 245000, `Expected ~235km, got ${dist}`);
  });

  test('RoutingProvider fallback estimate handles zero travel distance for identical coords', () => {
    const coords = { lat: 26.9124, lng: 75.7873 };
    const est = RoutingProvider.calculateHaversineEstimate(coords, coords, 'driving');
    assert.strictEqual(est.durationSeconds, 0);
    assert.strictEqual(est.distanceMeters, 0);
    assert.strictEqual(est.isApproximate, false);
  });

  await test('LeaveTimeEngine computes leave_at = next_arrival - travel - safety_buffer', async () => {
    const currentStop = {
      id: 'stop_1',
      trip_id: 'test_trip',
      stop_order: 1,
      title: 'Hawa Mahal',
      stop_type: 'visit',
      planned_arrival_at: '2026-10-31T09:00:00Z',
      planned_departure_at: '2026-10-31T10:30:00Z',
      stay_duration_minutes: 90,
      transport_mode: 'driving' as const,
      status: 'upcoming' as const,
      lat: 26.9239,
      lng: 75.8267,
      timezone: 'UTC',
    };

    const nextStop = {
      id: 'stop_2',
      trip_id: 'test_trip',
      stop_order: 2,
      title: 'Amber Fort',
      stop_type: 'visit',
      planned_arrival_at: '2026-10-31T11:15:00Z',
      planned_departure_at: '2026-10-31T13:00:00Z',
      stay_duration_minutes: 105,
      transport_mode: 'driving' as const,
      status: 'upcoming' as const,
      lat: 26.9855,
      lng: 75.8513,
      timezone: 'UTC',
    };

    const transition = await LeaveTimeEngine.calculateTransition(
      'test_trip',
      currentStop,
      nextStop,
      10 // 10 min safety buffer
    );

    const nextArrivalEpoch = new Date(nextStop.planned_arrival_at).getTime();
    const leaveEpoch = new Date(transition.leaveTimeUtc).getTime();
    const bufferAndTravelMs = transition.travelDurationSeconds * 1000 + 10 * 60 * 1000;

    assert.strictEqual(
      leaveEpoch,
      nextArrivalEpoch - bufferAndTravelMs,
      'Leave time must equal next_stop.arrival - travel_time - safety_buffer'
    );
  });

  await test('LeaveTimeEngine detects impossible schedule when leave time precedes departure time', async () => {
    const currentStop = {
      id: 'stop_a',
      trip_id: 'test_trip_impossible',
      stop_order: 1,
      title: 'Taj Mahal',
      stop_type: 'visit',
      planned_arrival_at: '2026-10-31T09:00:00Z',
      planned_departure_at: '2026-10-31T11:00:00Z', // departure at 11:00
      stay_duration_minutes: 120,
      transport_mode: 'driving' as const,
      status: 'upcoming' as const,
      lat: 27.1751,
      lng: 78.0421,
      timezone: 'UTC',
    };

    const nextStop = {
      id: 'stop_b',
      trip_id: 'test_trip_impossible',
      stop_order: 2,
      title: 'Fatehpur Sikri',
      stop_type: 'visit',
      planned_arrival_at: '2026-10-31T11:05:00Z', // impossible: 36km away but only 5 min later!
      planned_departure_at: '2026-10-31T13:00:00Z',
      stay_duration_minutes: 115,
      transport_mode: 'driving' as const,
      status: 'upcoming' as const,
      lat: 27.0945,
      lng: 77.6679,
      timezone: 'UTC',
    };

    const transition = await LeaveTimeEngine.calculateTransition(
      'test_trip_impossible',
      currentStop,
      nextStop,
      10
    );

    assert.strictEqual(transition.isImpossibleSchedule, true, 'Should flag impossible schedule');
    assert.ok(transition.delayRiskMinutes > 0, 'Delay risk minutes should be greater than 0');
  });

  test('LeaveTimeEngine generates deterministic notification keys', () => {
    const key1 = LeaveTimeEngine.makeNotificationKey('t1', 's1', 'leave_now', '2026-10-31T10:30:15Z');
    const key2 = LeaveTimeEngine.makeNotificationKey('t1', 's1', 'leave_now', '2026-10-31T10:30:59Z');
    const key3 = LeaveTimeEngine.makeNotificationKey('t1', 's1', 'leave_now', '2026-10-31T10:31:00Z');

    assert.strictEqual(key1, key2, 'Keys within same minute must match for deduplication');
    assert.notStrictEqual(key1, key3, 'Keys in different minutes must differ');
  });

  test('NotificationService localizes alert templates in en, hi, es, ar', () => {
    const en = NotificationService.renderTemplate('leave_now', 'en', { place: 'City Palace' });
    assert.ok(en.body.includes('City Palace'));

    const hi = NotificationService.renderTemplate('leave_now', 'hi', { place: 'सिटी पैलेस' });
    assert.ok(hi.body.includes('सिटी पैलेस') && hi.title.includes('निकलने'));

    const es = NotificationService.renderTemplate('leave_now', 'es', { place: 'Palacio' });
    assert.ok(es.title.includes('Hora'));

    const ar = NotificationService.renderTemplate('leave_now', 'ar', { place: 'القصر' });
    assert.ok(ar.title.includes('المغادرة'));
  });

  test('NotificationService accurately checks quiet hours', () => {
    const prefsDisabled = { quiet_hours_enabled: 0 };
    assert.strictEqual(NotificationService.isQuietHours(prefsDisabled), false);

    const prefsEnabled = {
      quiet_hours_enabled: 1,
      quiet_hours_start: '00:00',
      quiet_hours_end: '23:59',
    };
    assert.strictEqual(NotificationService.isQuietHours(prefsEnabled), true);
  });

  await test('AlertScheduler startup audit handles recovery and dropping stale records', async () => {
    const result = await AlertScheduler.onStartup();
    assert.ok(typeof result.recovered === 'number');
    assert.ok(typeof result.dropped === 'number');
  });

  // 8. SOS & Emergency Safety System Tests
  const { SmsProvider } = await import('../lib/sos/sms-provider');
  const { HospitalProvider } = await import('../lib/sos/hospital-provider');
  const { SosEngine } = await import('../lib/sos/sos-engine');

  test('SmsProvider E.164 phone validation and normalization works accurately', () => {
    // Valid normalization
    const norm1 = SmsProvider.normalizePhone('+919876543210');
    assert.strictEqual(norm1.e164, '+919876543210');
    assert.strictEqual(norm1.isValid, true);

    const norm2 = SmsProvider.normalizePhone('9876543210', '+91');
    assert.strictEqual(norm2.e164, '+919876543210');
    assert.strictEqual(norm2.isValid, true);

    const norm3 = SmsProvider.normalizePhone('(987) 654-3210', '+1');
    assert.strictEqual(norm3.e164, '+19876543210');
    assert.strictEqual(norm3.isValid, true);

    // Validation
    assert.strictEqual(SmsProvider.normalizePhone('+919876543210').isValid, true);
    assert.strictEqual(SmsProvider.normalizePhone('12345').isValid, false);
    assert.strictEqual(SmsProvider.normalizePhone('+0123456789').isValid, false);
    assert.strictEqual(SmsProvider.normalizePhone('letters-not-allowed').isValid, false);
  });

  test('SmsProvider calculates GSM-7 and Unicode segments (English vs Hindi/Arabic)', () => {
    // English GSM-7 under 160 chars = 1 segment
    const enText = 'SOS alert from Test User. Location: https://maps.google.com';
    const enSeg = SmsProvider.calculateSegments(enText);
    assert.strictEqual(enSeg.isUnicode, false);
    assert.strictEqual(enSeg.segments, 1);

    // Hindi Unicode text under 70 chars = 1 segment
    const hiText = 'आपातकालीन सूचना: मुझे मदद की ज़रूरत है। कृपया मेरी लोकेशन देखें।';
    const hiSeg = SmsProvider.calculateSegments(hiText);
    assert.strictEqual(hiSeg.isUnicode, true);
    assert.strictEqual(hiSeg.segments, 1);

    // Concatenated multi-segment Hindi text
    const longHiText = hiText.repeat(3);
    const longHiSeg = SmsProvider.calculateSegments(longHiText);
    assert.strictEqual(longHiSeg.isUnicode, true);
    assert.ok(longHiSeg.segments > 1);
  });

  await test('HospitalProvider finds nearby hospitals and prioritizes emergency departments', async () => {
    // Test in Jaipur near SMS Hospital (26.8918, 75.8155)
    const hospitals = await HospitalProvider.findNearby(26.8918, 75.8155, 10000, 5);
    assert.ok(hospitals.length > 0, 'Should find nearby hospitals');
    assert.ok(hospitals[0].navigationUrl.includes('google.com/maps'));
  });

  await test('SosEngine triggers idempotent SOS and records snapshot, deliveries, and hospitals', async () => {
    const testSosId = 'test-sos-' + Date.now();
    const result1 = await SosEngine.triggerSos({
      sosId: testSosId,
      userId: 'user_demo',
      lat: 26.9124,
      lng: 75.7873,
      accuracyM: 12,
      locationSource: 'gps',
      triggerSource: 'home',
      batteryPercent: 88,
    });

    assert.strictEqual(result1.sosId, testSosId);
    assert.strictEqual(result1.status, 'active');
    assert.ok(result1.hospitals.length > 0, 'Should attach hospitals');

    // Idempotent test: calling with same sos_id returns existing event without re-sending
    const result2 = await SosEngine.triggerSos({
      sosId: testSosId,
      userId: 'user_demo',
      lat: 26.9124,
      lng: 75.7873,
      accuracyM: 12,
      locationSource: 'gps',
      triggerSource: 'home',
    });

    assert.strictEqual(result2.sosId, testSosId);
    assert.strictEqual(result2.deliveries.length, result1.deliveries.length);
  });

  await test('SosEngine records location trail and marks user safe', async () => {
    const testSosId = 'test-sos-trail-' + Date.now();
    await SosEngine.triggerSos({
      sosId: testSosId,
      userId: 'user_demo',
      lat: 26.9124,
      lng: 75.7873,
      accuracyM: 15,
      locationSource: 'gps',
      triggerSource: 'itinerary',
    });

    // Add location update
    const locUpdate = SosEngine.updateLocation(testSosId, 26.9150, 75.7900, 8);
    assert.strictEqual(locUpdate, true);

    // Mark safe
    const safeResult = await SosEngine.resolveSafe(testSosId, 'user_demo');
    assert.strictEqual(safeResult, true);
  });

  await test('SosEngine handles false alarm cancellation', async () => {
    const testSosId = 'test-sos-false-' + Date.now();
    await SosEngine.triggerSos({
      sosId: testSosId,
      userId: 'user_demo',
      lat: 26.9124,
      lng: 75.7873,
      accuracyM: 10,
      locationSource: 'gps',
      triggerSource: 'home',
    });

    const cancelResult = await SosEngine.cancelOrFalseAlarm(testSosId, 'user_demo', true);
    assert.strictEqual(cancelResult, true);
  });

  console.log(`\n========================================`);
  console.log(`Total: ${passed + failed} | Passed: ${passed} | Failed: ${failed}`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runAllTests();

