import {
  modifyItineraryWithEngine,
  fuzzyMatchStop,
  detectModificationIntent,
  extractPlaceQuery,
} from '../lib/crowd/modify';

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

async function runModifyTests() {
  console.log('--- RUNNING ITINERARY MODIFICATION ENGINE TESTS (STEP 7) ---');

  // Baseline 3-stop itinerary in Jaipur
  const baseItinerary = {
    id: 'itin_jaipur_001',
    city: 'Jaipur',
    date: '2026-11-02',
    startTime: '09:00',
    endTime: '18:00',
    stops: [
      {
        placeId: 'amber_fort',
        name: 'Amber Fort',
        category: 'fort',
        startTime: '09:00',
        endTime: '11:00',
        durationMinutes: 120,
        estimatedCrowdLevel: 'moderate',
      },
      {
        placeId: 'jaigarh_fort',
        name: 'Jaigarh Fort',
        category: 'fort',
        startTime: '11:15',
        endTime: '12:45',
        durationMinutes: 90,
        estimatedCrowdLevel: 'low',
      },
      {
        placeId: 'hawa_mahal',
        name: 'Hawa Mahal',
        category: 'heritage',
        startTime: '13:15',
        endTime: '14:30',
        durationMinutes: 75,
        estimatedCrowdLevel: 'busy',
      },
    ],
  };

  // 1. Fuzzy Match Unit Tests
  console.log('\n[1] Fuzzy Name Matching');
  const stops = baseItinerary.stops;

  const exact = fuzzyMatchStop(stops, 'Amber Fort');
  assert(exact.match?.name === 'Amber Fort', 'Exact match resolves to Amber Fort');

  const substring = fuzzyMatchStop(stops, 'Hawa');
  assert(substring.match?.name === 'Hawa Mahal', 'Substring "Hawa" resolves to Hawa Mahal');

  const ambiguous = fuzzyMatchStop(stops, 'Fort');
  assert(
    ambiguous.ambiguous?.length === 2,
    'Ambiguous query "Fort" matches both Amber Fort and Jaigarh Fort'
  );

  const missing = fuzzyMatchStop(stops, 'Taj Mahal');
  assert(missing.none === true, 'Non-existent venue returns none');

  // 2. Action 1: Replace a place
  console.log('\n[2] Action: Replace a place ("Replace Amber Fort with something else")');
  const replaceRes = await modifyItineraryWithEngine({
    userMessage: 'Replace Amber Fort with something else',
    currentItinerary: baseItinerary,
  });

  assert(replaceRes.updatedItinerary !== null, 'Returned updated itinerary');
  assert(replaceRes.chatMessage.length > 10, `Returned chat message: "${replaceRes.chatMessage}"`);
  const newStopNames = replaceRes.updatedItinerary.stops.map((s: any) => s.name);
  assert(!newStopNames.includes('Amber Fort'), 'Amber Fort was removed');
  assert(newStopNames.length === 3, 'Stop count remains 3 after replacement');
  assert(
    replaceRes.updatedItinerary.stops[0].startTime === '09:00',
    'Recomputed slot starts at 09:00'
  );

  // 3. Action 2: Add a food stop
  console.log('\n[3] Action: Add a food stop ("Can we add a food stop for lunch?")');
  const foodRes = await modifyItineraryWithEngine({
    userMessage: 'Can we add a food stop for lunch?',
    currentItinerary: baseItinerary,
  });

  assert(foodRes.updatedItinerary !== null, 'Returned updated itinerary');
  assert(foodRes.chatMessage.length > 10, `Returned chat message: "${foodRes.chatMessage}"`);
  assert(
    foodRes.updatedItinerary.stops.length === baseItinerary.stops.length + 1,
    'Stop count increased by 1'
  );
  const hasFoodCategory = foodRes.updatedItinerary.stops.some((s: any) => s.category === 'food');
  assert(hasFoodCategory, 'Itinerary now includes a stop with category food');

  // 4. Action 3: I have less time
  console.log('\n[4] Action: I have less time ("I have less time today, need to end early by 14:00")');
  const lessTimeRes = await modifyItineraryWithEngine({
    userMessage: 'I have less time today, need to end early by 14:00',
    currentItinerary: baseItinerary,
  });

  assert(lessTimeRes.updatedItinerary !== null, 'Returned updated itinerary');
  assert(lessTimeRes.chatMessage.length > 10, `Returned chat message: "${lessTimeRes.chatMessage}"`);
  const finalStop = lessTimeRes.updatedItinerary.stops[lessTimeRes.updatedItinerary.stops.length - 1];
  const [fsh, fsm] = finalStop.endTime.split(':').map(Number);
  const finalMinutes = fsh * 60 + fsm;
  assert(finalMinutes <= 14 * 60, `All stops complete at or before 14:00 (actual: ${finalStop.endTime})`);

  // 5. Action 4: Make it more relaxed
  console.log('\n[5] Action: Make it more relaxed ("Make it more relaxed, slow down the pace")');
  const relaxedRes = await modifyItineraryWithEngine({
    userMessage: 'Make it more relaxed, slow down the pace',
    currentItinerary: baseItinerary,
  });

  assert(relaxedRes.updatedItinerary !== null, 'Returned updated itinerary');
  assert(relaxedRes.chatMessage.length > 10, `Returned chat message: "${relaxedRes.chatMessage}"`);
  assert(relaxedRes.updatedItinerary.pace === 'relaxed', 'Itinerary pace set to relaxed');

  // 6. Ambiguous Name Case
  console.log('\n[6] Ambiguous Name Case ("Replace the Fort")');
  const ambiguousRes = await modifyItineraryWithEngine({
    userMessage: 'Replace the Fort',
    currentItinerary: baseItinerary,
  });

  assert(ambiguousRes.updatedItinerary === null, 'No itinerary change applied on ambiguity');
  assert(
    ambiguousRes.chatMessage.includes('Amber Fort') && ambiguousRes.chatMessage.includes('Jaigarh Fort'),
    'Chat message lists both matching options for user choice'
  );
  console.log(`  Bot prompt: "${ambiguousRes.chatMessage}"`);

  // 7. Impossible Request Case (Window Exceeded / Packed Schedule)
  console.log('\n[7] Impossible Request Case (Schedule already at capacity until 18:00)');
  const packedItinerary = {
    ...baseItinerary,
    stops: [
      { name: 'Stop 1', durationMinutes: 150, startTime: '09:00', endTime: '11:30' },
      { name: 'Stop 2', durationMinutes: 150, startTime: '11:45', endTime: '14:15' },
      { name: 'Stop 3', durationMinutes: 150, startTime: '14:30', endTime: '17:00' },
      { name: 'Stop 4', durationMinutes: 60, startTime: '17:15', endTime: '18:00' },
    ],
  };

  const impossibleRes = await modifyItineraryWithEngine({
    userMessage: 'Add another food stop for 2 hours',
    action: 'add_food_stop',
    currentItinerary: packedItinerary,
  });

  assert(impossibleRes.updatedItinerary === null, 'Rejected impossible change (updatedItinerary is null)');
  assert(
    impossibleRes.chatMessage.toLowerCase().includes('fully booked') ||
      impossibleRes.chatMessage.toLowerCase().includes('cannot add') ||
      impossibleRes.chatMessage.toLowerCase().includes('schedule'),
    'Explains why in chatMessage without applying impossible change'
  );
  console.log(`  Rejection explanation: "${impossibleRes.chatMessage}"`);

  console.log(`\n========================================`);
  console.log(`TOTAL: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
  console.log(`========================================`);

  if (failed > 0) {
    process.exit(1);
  }
}

runModifyTests().catch((e) => {
  console.error('Test runner failure:', e);
  process.exit(1);
});

