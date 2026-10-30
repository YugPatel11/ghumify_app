import {
  NarrationInput,
  narrateItinerary,
  validateNarrationOutput,
  buildSanitizedNarrationPrompt,
  generateTemplateFallback,
} from '../lib/crowd/narration';

let passed = 0;
let failed = 0;

function assert(condition: boolean, msg: string) {
  if (condition) {
    passed++;
    console.log(`  [PASS] ${msg}`);
  } else {
    failed++;
    console.error(`  [FAIL] ${msg}`);
  }
}

async function runTests() {
  console.log('--- RUNNING NARRATION UNIT TESTS ---');

  const sampleInput: NarrationInput = {
    city: 'Jaipur',
    date: '2026-11-01',
    stops: [
      {
        placeId: 'amber-fort-1',
        name: 'Amber Fort',
        category: 'fort',
        suggestedStart: '08:30',
        suggestedEnd: '11:00',
        estimatedCrowdLevel: 'Low',
        durationMinutes: 150,
      },
      {
        placeId: 'hawa-mahal-2',
        name: 'Hawa Mahal',
        category: 'heritage',
        suggestedStart: '11:30',
        suggestedEnd: '12:45',
        estimatedCrowdLevel: 'Moderate',
        durationMinutes: 75,
      },
    ],
  };

  // TEST 1: Privacy Sanitizer verification
  console.log('\n[1] Privacy Sanitizer Invariants');
  const prompt = buildSanitizedNarrationPrompt(sampleInput);
  assert(!prompt.includes('userId'), 'Prompt does not contain userId');
  assert(!prompt.includes('user_'), 'Prompt does not contain user identifiers');
  assert(!prompt.includes('latitude') && !prompt.includes('longitude'), 'Prompt does not contain coordinates');
  assert(prompt.includes('Amber Fort') && prompt.includes('Hawa Mahal'), 'Prompt includes input stop names');
  assert(prompt.includes('08:30 - 11:00') && prompt.includes('Low'), 'Prompt includes slots and crowd labels');

  // TEST 2: Mocked Gemini returning an invented place
  console.log('\n[2] Mock Gemini - Invented Place (must be rejected & fall back)');
  let inventedCallCount = 0;
  const mockInventedGemini = async () => {
    inventedCallCount++;
    return JSON.stringify({
      summary: 'A day in Jaipur',
      stops: [
        {
          placeId: 'amber-fort-1',
          name: 'Amber Fort',
          description: 'A grand hilltop fortress.',
          tips: ['Go early', 'Wear walking shoes'],
        },
        {
          placeId: 'invented-disney-99',
          name: 'Disneyland Castle', // Invented place!
          description: 'Invented theme park attraction.',
          tips: ['Buy passes', 'Ride rollercoasters'],
        },
      ],
    });
  };

  const inventedResult = await narrateItinerary(sampleInput, mockInventedGemini);
  assert(inventedCallCount === 2, 'Invented place triggered 1 retry (total 2 attempts)');
  assert(inventedResult.source === 'template_fallback', 'Invented place fell back to template text');
  assert(inventedResult.stops.length === 2, 'Maintains 2 stops in output');
  assert(inventedResult.stops[0].placeId === 'amber-fort-1', 'First stop placeId is preserved');
  assert(inventedResult.stops[1].placeId === 'hawa-mahal-2', 'Second stop placeId is preserved (invented place rejected)');
  assert(inventedResult.stops[1].name === 'Hawa Mahal', 'Second stop name is preserved as Hawa Mahal');

  // TEST 3: Mocked Gemini returning reordered stops
  console.log('\n[3] Mock Gemini - Reordered Stops (must be rejected & fall back)');
  let reorderCallCount = 0;
  const mockReorderedGemini = async () => {
    reorderCallCount++;
    return JSON.stringify({
      summary: 'Reordered day in Jaipur',
      stops: [
        {
          placeId: 'hawa-mahal-2',
          name: 'Hawa Mahal', // Swapped order!
          description: 'Palace of winds.',
          tips: ['Take photos from street', 'Visit museum'],
        },
        {
          placeId: 'amber-fort-1',
          name: 'Amber Fort',
          description: 'Hilltop fortress.',
          tips: ['Elephant ride', 'See Sheesh Mahal'],
        },
      ],
    });
  };

  const reorderedResult = await narrateItinerary(sampleInput, mockReorderedGemini);
  assert(reorderCallCount === 2, 'Reordered stops triggered 1 retry (total 2 attempts)');
  assert(reorderedResult.source === 'template_fallback', 'Reordered stops fell back to template text');
  assert(reorderedResult.stops[0].name === 'Amber Fort', 'Preserves original first stop order (Amber Fort)');
  assert(reorderedResult.stops[1].name === 'Hawa Mahal', 'Preserves original second stop order (Hawa Mahal)');

  // TEST 4: Mocked Gemini returning malformed JSON
  console.log('\n[4] Mock Gemini - Malformed JSON (must be rejected & fall back)');
  let malformedCallCount = 0;
  const mockMalformedGemini = async () => {
    malformedCallCount++;
    return '{ summary: "Unclosed string, stops: [{ bad_json: true }';
  };

  const malformedResult = await narrateItinerary(sampleInput, mockMalformedGemini);
  assert(malformedCallCount === 2, 'Malformed JSON triggered 1 retry (total 2 attempts)');
  assert(malformedResult.source === 'template_fallback', 'Malformed JSON fell back to template text');
  assert(malformedResult.summary.length > 0, 'Fallback summary is generated');
  assert(malformedResult.stops[0].description.length > 0, 'Fallback description is generated');
  assert(malformedResult.stops[0].tips.length > 0, 'Fallback tips are generated');

  // TEST 5: Mocked Gemini succeeding on retry (Attempt 1 fails, Attempt 2 succeeds)
  console.log('\n[5] Mock Gemini - Retry Recovery (Attempt 1 fails, Attempt 2 succeeds)');
  let recoverAttempts = 0;
  const mockRecoverGemini = async () => {
    recoverAttempts++;
    if (recoverAttempts === 1) {
      throw new Error('Temporary 503 Service Unavailable');
    }
    return JSON.stringify({
      summary: 'Experience Jaipur royal heritage with scenic forts and iconic palaces.',
      stops: [
        {
          placeId: 'amber-fort-1',
          name: 'Amber Fort',
          description: 'Marvel at the artistic Hindu style elements overlooking Maota Lake.',
          tips: ['Visit early morning to beat the heat', 'Allow 2 hours for Sheesh Mahal'],
        },
        {
          placeId: 'hawa-mahal-2',
          name: 'Hawa Mahal',
          description: 'Admire the 953 honeycomb windows crafted with red and pink sandstone.',
          tips: ['Cross the road for the best exterior view', 'Explore the compact royal rooms'],
        },
      ],
    });
  };

  const recoveredResult = await narrateItinerary(sampleInput, mockRecoverGemini);
  assert(recoverAttempts === 2, 'Retried once after first failure');
  assert(recoveredResult.source === 'gemini', 'Successfully used Gemini output on second attempt');
  assert(recoveredResult.stops[0].description.includes('Maota Lake'), 'Applied narrated description');
  assert(recoveredResult.stops[0].tips.length === 2, 'Applied narrated tips');

  // TEST 6: Mocked Gemini succeeding cleanly on first attempt
  console.log('\n[6] Mock Gemini - Direct Success');
  const mockValidGemini = async () => {
    return JSON.stringify({
      summary: 'A wonderful exploration of Jaipur treasures.',
      stops: [
        {
          placeId: 'amber-fort-1',
          name: 'Amber Fort',
          description: 'A magnificent fort on the Amer hills.',
          tips: ['Wear sunglasses', 'Bring a camera'],
        },
        {
          placeId: 'hawa-mahal-2',
          name: 'Hawa Mahal',
          description: 'The iconic honeycomb palace facade.',
          tips: ['Stop at wind view cafe', 'Best light in afternoon'],
        },
      ],
    });
  };

  const validResult = await narrateItinerary(sampleInput, mockValidGemini);
  assert(validResult.source === 'gemini', 'Direct valid output accepted as gemini source');
  assert(validResult.stops[0].placeId === 'amber-fort-1', 'Place ID matches');
  assert(validResult.stops[1].placeId === 'hawa-mahal-2', 'Place ID matches');
  assert(validResult.stops[1].tips[0] === 'Stop at wind view cafe', 'Tips match Gemini text');

  // TEST 7: Template fallback generator directly
  console.log('\n[7] Template Fallback Invariant');
  const fallback = generateTemplateFallback(sampleInput);
  assert(fallback.source === 'template_fallback', 'Source is template_fallback');
  assert(fallback.stops.length === sampleInput.stops.length, 'Generates fallback for all stops');
  assert(fallback.summary.includes('Jaipur'), 'Fallback summary references city');

  console.log(`\n========================================`);
  console.log(`TOTAL: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
  console.log(`========================================`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((e) => {
  console.error('Test runner error:', e);
  process.exit(1);
});

