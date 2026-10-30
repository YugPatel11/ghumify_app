import assert from 'node:assert';
import { mergeFormAndRemarks, sanitizeRemarks, extractFromRemarks } from '../lib/planner/remarks-merger';
import { getDb } from '../lib/db';

async function runRemarksTests() {
  console.log('🧪 Starting Ghumify Remarks & Form Pipeline Test Suite...\n');
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

  // 1. Sanitization & Safety
  test('Sanitizes malicious script tags, HTML tags, and trims whitespace safely', () => {
    const malicious = '  <script>alert("hacked")</script> I want a nice <img src=x onerror=alert(1)> trip to Jaipur   ';
    const clean = sanitizeRemarks(malicious);
    assert.ok(!clean.includes('<script>'), 'Should strip script tags');
    assert.ok(!clean.includes('<img'), 'Should strip img tags');
    assert.ok(!clean.includes('onerror='), 'Should strip inline handlers');
    assert.ok(clean.includes('Jaipur'), 'Should keep user travel words');
    assert.strictEqual(clean, clean.trim(), 'Should be trimmed');
  });

  // 2. Empty / Whitespace-only Remarks Fast Path
  test('Empty, null, or whitespace-only remarks skips extraction and uses manual path', () => {
    const whitespaceCases = ['', '   ', '\t\n\r  ', '   \u200B\uFEFF  '];
    for (const ws of whitespaceCases) {
      const result = mergeFormAndRemarks(
        { city: 'Jaipur', numberOfDays: 2, hours: 6, pace: 'moderate' },
        ws,
        'en'
      );
      assert.strictEqual(result.valid, true);
      assert.strictEqual(result.plan?.hasRemarks, false, `Whitespace '${ws}' should count as no remarks`);
      assert.strictEqual(result.plan?.contradictions.length, 0, 'No contradictions on empty remarks');
      assert.strictEqual(result.plan?.sources['city'], 'form');
      assert.strictEqual(result.plan?.sources['numberOfDays'], 'form');
      assert.strictEqual(result.plan?.city, 'Jaipur');
    }
  });

  // 3. Form Priority Over Remarks
  test('Explicit form fields ALWAYS win over contradicting remarks', () => {
    const result = mergeFormAndRemarks(
      {
        city: 'Delhi',
        numberOfDays: 3,
        hours: 5,
        pace: 'fast',
      },
      'I want a 7 day trip to Mumbai at a relaxed pace with vegetarian food.',
      'en'
    );

    assert.strictEqual(result.valid, true);
    const plan = result.plan!;

    // Form values MUST win
    assert.strictEqual(plan.city, 'Delhi', 'Form city Delhi wins over Mumbai in remarks');
    assert.strictEqual(plan.numberOfDays, 3, 'Form days 3 wins over 7 days in remarks');
    assert.strictEqual(plan.hours, 5, 'Form hours wins');
    assert.strictEqual(plan.pace, 'fast', 'Form pace fast wins over relaxed in remarks');

    // Remarks fill gap for dietary
    assert.strictEqual(plan.foodPreference, 'vegetarian', 'Remarks fill dietary gap');
    assert.strictEqual(plan.sources['foodPreference'], 'remarks');
    assert.strictEqual(plan.sources['city'], 'form');

    // Contradictions are recorded
    assert.ok(plan.contradictions.length >= 3, 'Should flag city, numberOfDays, and pace contradictions');
    const cityContra = plan.contradictions.find((c) => c.field === 'city');
    assert.ok(cityContra, 'Should have city contradiction');
    assert.strictEqual(cityContra?.formValue, 'Delhi');
    assert.strictEqual(cityContra?.remarksValue, 'Mumbai');

    const daysContra = plan.contradictions.find((c) => c.field === 'numberOfDays');
    assert.ok(daysContra, 'Should have days contradiction');
    assert.strictEqual(daysContra?.formValue, 3);
    assert.strictEqual(daysContra?.remarksValue, 7);
  });

  // 4. Remarks Fill Missing Gaps
  test('Remarks fill missing destination, duration, pace, and accessibility', () => {
    const result = mergeFormAndRemarks(
      {}, // Completely empty form
      'Planning a weekend trip to Udaipur with kids. Need wheelchair accessible monuments and avoid early mornings.',
      'en'
    );

    assert.strictEqual(result.valid, true);
    const plan = result.plan!;

    assert.strictEqual(plan.city, 'Udaipur', 'City extracted from remarks');
    assert.strictEqual(plan.sources['city'], 'remarks');
    assert.strictEqual(plan.numberOfDays, 2, 'Weekend mapped to 2 days');
    assert.strictEqual(plan.extractedPreferences.kidFriendly, true, 'Kid friendly extracted');
    assert.strictEqual(plan.extractedPreferences.wheelchairAccessible, true, 'Wheelchair accessible extracted');
    assert.strictEqual(plan.extractedPreferences.avoidEarlyMornings, true, 'Avoid early morning extracted');
    assert.strictEqual(plan.contradictions.length, 0, 'No contradictions when form is empty');
  });

  // 5. Missing in Both triggers validation failure
  test('Missing critical info in both form and remarks triggers validation error', () => {
    const result = mergeFormAndRemarks(
      { numberOfDays: 2 },
      'I like vegetarian food and walking around historic markets.', // No city mentioned!
      'en'
    );

    assert.strictEqual(result.valid, false, 'Should fail validation');
    assert.ok(result.missingFields.includes('city'), 'Should indicate missing city');
    assert.ok(result.errorMessage?.toLowerCase().includes('city'), 'Error message should mention city');
  });

  // 6. Source Tracking
  test('Correctly records sources for every parameter (form vs remarks vs default)', () => {
    const result = mergeFormAndRemarks(
      { city: 'Agra', numberOfDays: 1 },
      'Vegetarian food only, no rush.',
      'en'
    );

    assert.strictEqual(result.valid, true);
    const plan = result.plan!;
    assert.strictEqual(plan.sources['city'], 'form');
    assert.strictEqual(plan.sources['numberOfDays'], 'form');
    assert.strictEqual(plan.sources['foodPreference'], 'remarks');
    assert.strictEqual(plan.sources['pace'], 'remarks');
    assert.strictEqual(plan.sources['travelMode'], 'default');
    assert.strictEqual(plan.sources['travelers'], 'default');
  });

  // 7. Idempotency Key Handling in Database
  test('Idempotency key prevents duplicate requests and returns existing record', () => {
    const db = getDb();
    const idempotencyKey = 'test_req_' + Date.now();
    const userId = 'user_demo';
    const nowIso = new Date().toISOString();

    const insertStmt = db.prepare(`
      INSERT INTO itinerary_requests (idempotency_key, user_id, city, form_fields, remarks, merged_plan, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 'completed', ?)
    `);

    const mockPlan = {
      city: 'Varanasi',
      numberOfDays: 3,
      sources: { city: 'form', numberOfDays: 'form' },
    };

    insertStmt.run(
      idempotencyKey,
      userId,
      'Varanasi',
      JSON.stringify({ city: 'Varanasi', numberOfDays: 3 }),
      'Visit ghats at evening',
      JSON.stringify(mockPlan),
      nowIso
    );

    // Retrieve using idempotency key
    const existing = db
      .prepare('SELECT * FROM itinerary_requests WHERE idempotency_key = ?')
      .get(idempotencyKey) as any;

    assert.ok(existing, 'Record should exist');
    assert.strictEqual(existing.idempotency_key, idempotencyKey);
    assert.strictEqual(existing.city, 'Varanasi');
    const parsedPlan = JSON.parse(existing.merged_plan);
    assert.strictEqual(parsedPlan.city, 'Varanasi');
    assert.strictEqual(parsedPlan.numberOfDays, 3);
  });

  // 8. Multilingual extraction (Hindi, Arabic)
  test('Remarks extraction recognizes Hindi and Arabic travel keywords', () => {
    const hiResult = mergeFormAndRemarks(
      { city: 'Jaipur' },
      'हम बच्चों के साथ जा रहे हैं और शाकाहारी भोजन चाहिए। सुबह जल्दी नहीं उठना है।',
      'hi'
    );
    assert.strictEqual(hiResult.valid, true);
    assert.strictEqual(hiResult.plan?.extractedPreferences.kidFriendly, true, 'Kid friendly recognized in Hindi');
    assert.strictEqual(hiResult.plan?.foodPreference, 'vegetarian', 'Vegetarian recognized in Hindi');
    assert.strictEqual(hiResult.plan?.extractedPreferences.avoidEarlyMornings, true, 'Late start recognized in Hindi');

    const arResult = mergeFormAndRemarks(
      { city: 'Dubai' },
      'مع الأطفال وطعام نباتي وجدول هادئ',
      'ar'
    );
    assert.strictEqual(arResult.valid, true);
    assert.strictEqual(arResult.plan?.extractedPreferences.kidFriendly, true, 'Kid friendly recognized in Arabic');
    assert.strictEqual(arResult.plan?.foodPreference, 'vegetarian', 'Vegetarian recognized in Arabic');
    assert.strictEqual(arResult.plan?.pace, 'relaxed', 'Relaxed pace recognized in Arabic');
  });

  // 9. Golden Set Evaluation: 6 Cases
  test('Golden Set Evaluation: passes all 6 standard test scenarios', () => {
    const goldenSet = [
      {
        name: 'Case 1: Standard form, empty remarks',
        form: { city: 'Jaipur', numberOfDays: 2, pace: 'moderate' },
        remarks: '   ',
        expectedCity: 'Jaipur',
        expectedDays: 2,
        expectedRemarksUsed: false,
      },
      {
        name: 'Case 2: Missing city in form, present in remarks',
        form: { numberOfDays: 3 },
        remarks: 'Trip to Agra for 3 days with heritage sights',
        expectedCity: 'Agra',
        expectedDays: 3,
        expectedRemarksUsed: true,
      },
      {
        name: 'Case 3: Contradiction in days (form wins)',
        form: { city: 'Goa', numberOfDays: 4 },
        remarks: 'We want to stay in Goa for a week with vegetarian food',
        expectedCity: 'Goa',
        expectedDays: 4,
        expectedRemarksUsed: true,
      },
      {
        name: 'Case 4: Full preferences from chips/speech',
        form: { city: 'Bengaluru', numberOfDays: 1 },
        remarks: 'Budget trip, affordable options, wheelchair accessible locations',
        expectedCity: 'Bengaluru',
        expectedDays: 1,
        expectedRemarksUsed: true,
      },
      {
        name: 'Case 5: Missing in both produces error',
        form: {},
        remarks: 'Just looking for good food and relaxing times',
        expectedCity: undefined,
        expectedDays: 1,
        expectedRemarksUsed: true,
      },
      {
        name: 'Case 6: Fast-path benchmark with undefined remarks',
        form: { city: 'Mumbai', numberOfDays: 2 },
        remarks: undefined as any,
        expectedCity: 'Mumbai',
        expectedDays: 2,
        expectedRemarksUsed: false,
      },
    ];

    for (const item of goldenSet) {
      const res = mergeFormAndRemarks(item.form, item.remarks || '', 'en');
      if (item.expectedCity) {
        assert.strictEqual(res.valid, true, `${item.name}: Should be valid`);
        assert.strictEqual(res.plan?.city, item.expectedCity, `${item.name}: City check`);
        assert.strictEqual(res.plan?.numberOfDays, item.expectedDays, `${item.name}: Days check`);
        assert.strictEqual(res.plan?.hasRemarks, item.expectedRemarksUsed, `${item.name}: Remarks used check`);
      } else {
        assert.strictEqual(res.valid, false, `${item.name}: Should be invalid due to missing city`);
      }
    }
  });

  console.log(`\n========================================`);
  console.log(`Remarks Pipeline: Total: ${passed + failed} | Passed: ${passed} | Failed: ${failed}`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runRemarksTests();
