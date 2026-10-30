import {
  CROWD_CONFIG,
  getCrowdLevel,
  getCategoryHourlyProfile,
  computeBaseCrowd,
} from '../lib/crowd/config';
import { estimateCrowd, PlaceCrowdProfile } from '../lib/crowd/estimate';
import { normalizeOpeningHours } from '../lib/crowd/normalizeOpeningHours';
import { rankCandidates, CandidatePlace } from '../lib/crowd/rank';
import { pickLowestCrowdSlot } from '../lib/crowd/slots';

async function runCrowdTests() {
  console.log('--- Starting Ghumify Crowd-Aware Engine Test Suite ---');
  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, name: string) {
    if (condition) {
      console.log(`  [PASS] ${name}`);
      passed++;
    } else {
      console.error(`  [FAIL] ${name}`);
      failed++;
    }
  }

  // --------------------------------------------------------------------------
  // 1. Score stays 0-100 (Clamping under extreme conditions)
  // --------------------------------------------------------------------------
  console.log('\n1. Score stays 0-100:');
  const extremeHighPlace: PlaceCrowdProfile = {
    category: 'temple',
    popularity: 100,
    capacity: 'small', // High density multiplier 1.25
    hourlyProfile: Array(24).fill(3.0),
  };
  const maxResult = estimateCrowd(extremeHighPlace, '2026-11-01', 18, {
    isHoliday: true,
    hasEvent: true,
    eventMultiplier: 2.0,
    season: 'peak',
  });
  assert(maxResult.score <= 100 && maxResult.score >= 0, `Extreme high score is clamped at 100 (got ${maxResult.score})`);
  assert(maxResult.score === 100, 'Extreme high score hits 100');

  const extremeLowPlace: PlaceCrowdProfile = {
    category: 'nature',
    popularity: 0,
    capacity: 'large',
    hourlyProfile: Array(24).fill(0.0),
  };
  const minResult = estimateCrowd(extremeLowPlace, '2026-11-02', 3, {
    season: 'offPeak',
  });
  assert(minResult.score >= 0 && minResult.score <= 100, `Extreme low score is clamped at 0 (got ${minResult.score})`);

  // --------------------------------------------------------------------------
  // 2. Level boundaries (0-30 Low, 31-50 Moderate, 51-75 Busy, 76-100 Very Busy)
  // --------------------------------------------------------------------------
  console.log('\n2. Level Boundaries:');
  assert(getCrowdLevel(0) === 'low', 'Boundary 0 is low');
  assert(getCrowdLevel(30) === 'low', 'Boundary 30 is low');
  assert(getCrowdLevel(31) === 'moderate', 'Boundary 31 is moderate');
  assert(getCrowdLevel(50) === 'moderate', 'Boundary 50 is moderate');
  assert(getCrowdLevel(51) === 'busy', 'Boundary 51 is busy');
  assert(getCrowdLevel(75) === 'busy', 'Boundary 75 is busy');
  assert(getCrowdLevel(76) === 'very_busy', 'Boundary 76 is very_busy');
  assert(getCrowdLevel(100) === 'very_busy', 'Boundary 100 is very_busy');

  // --------------------------------------------------------------------------
  // 3. Weights always sum to exactly 1.0
  // --------------------------------------------------------------------------
  console.log('\n3. Weights sum to 1.0:');
  const std = CROWD_CONFIG.standardWeights;
  const stdSum = std.interest + std.budget + std.foodFamily + std.distance + std.crowdPenalty;
  assert(Math.abs(stdSum - 1.0) < 0.0001, `Standard weights sum to 1.0 (actual: ${stdSum})`);

  const avoid = CROWD_CONFIG.avoidCrowdsWeights;
  const avoidSum = avoid.interest + avoid.budget + avoid.foodFamily + avoid.distance + avoid.crowdPenalty;
  assert(Math.abs(avoidSum - 1.0) < 0.0001, `Avoid-crowds weights sum to 1.0 (actual: ${avoidSum})`);
  assert(avoid.crowdPenalty === 0.40, 'Avoid-crowds crowd weight is exactly 0.40');

  // --------------------------------------------------------------------------
  // 4. Hard filters remove closed/over-budget places
  // --------------------------------------------------------------------------
  console.log('\n4. Hard Filters:');
  const candidates: CandidatePlace[] = [
    {
      id: 'p_open_ok',
      name: 'Open Affordable Museum',
      category: 'heritage',
      latitude: 26.91,
      longitude: 75.82,
      entryFee: 100,
      openingHours: { mon: '09:00-18:00', tue: '09:00-18:00' },
    },
    {
      id: 'p_over_budget',
      name: 'Luxury Royal Palace',
      category: 'heritage',
      latitude: 26.92,
      longitude: 75.83,
      entryFee: 1500, // Exceeds budgetCap 500
      openingHours: { mon: '09:00-18:00' },
    },
    {
      id: 'p_closed_tuesday',
      name: 'Art Gallery Closed Tuesday',
      category: 'culture',
      latitude: 26.93,
      longitude: 75.84,
      entryFee: 50,
      openingHours: { mon: '09:00-18:00', tue: 'closed' },
    },
    {
      id: 'p_closed_time_window',
      name: 'Morning Only Garden',
      category: 'nature',
      latitude: 26.94,
      longitude: 75.85,
      entryFee: 20,
      openingHours: { mon: '06:00-10:00', tue: '06:00-10:00' }, // Closed during afternoon visit at 14:00
    },
  ];

  // Test Tuesday ranking with budget cap 500 at 14:00 (840 mins)
  const rankingResult = rankCandidates(candidates, {
    date: '2026-11-03', // Tuesday (day 2)
    visitStartMinutes: 14 * 60, // 14:00
    visitDurationMinutes: 60,
    budgetCap: 500,
  });

  assert(rankingResult.ranked.some((r) => r.candidate.id === 'p_open_ok'), 'Open affordable place passed filters');
  assert(!rankingResult.ranked.some((r) => r.candidate.id === 'p_over_budget'), 'Over-budget place rejected');
  assert(!rankingResult.ranked.some((r) => r.candidate.id === 'p_closed_tuesday'), 'Closed-day place rejected');
  assert(!rankingResult.ranked.some((r) => r.candidate.id === 'p_closed_time_window'), 'Off-hours place rejected');
  assert(rankingResult.rejected.length === 3, 'Exactly 3 places were rejected by hard filters');

  // --------------------------------------------------------------------------
  // 5. Missing inputs are neutral (50)
  // --------------------------------------------------------------------------
  console.log('\n5. Missing inputs are neutral (50):');
  const neutralPlace: CandidatePlace = {
    id: 'p_neutral',
    name: 'Simple Park',
    category: 'nature',
    latitude: 26.9,
    longitude: 75.8,
    openingHours: { mon: '00:00-24:00' },
    // scoreInputs completely omitted
  };

  const neutralRanking = rankCandidates([neutralPlace], {
    date: '2026-11-02', // Monday
    visitStartMinutes: 10 * 60,
    visitDurationMinutes: 60,
  });

  assert(neutralRanking.ranked.length === 1, 'Neutral candidate passed filter');
  const breakdown = neutralRanking.ranked[0].breakdown;
  assert(breakdown.interest === 50, 'Missing interest score defaulted to neutral 50');
  assert(breakdown.budget === 50, 'Missing budget score defaulted to neutral 50');
  assert(breakdown.foodFamily === 50, 'Missing foodFamily score defaulted to neutral 50');
  assert(breakdown.distance === 50, 'Missing distance score defaulted to neutral 50');

  // --------------------------------------------------------------------------
  // 6. Slot selection never falls outside opening hours or user window
  // --------------------------------------------------------------------------
  console.log('\n6. Slot Selection Boundaries:');
  const restrictedPlace = {
    category: 'heritage',
    openingHours: { mon: '11:00-16:00' }, // 660 to 960 mins
  };

  // User window 09:00 - 18:00 (540 to 1080)
  const userWindow = { startMinutes: 9 * 60, endMinutes: 18 * 60 };
  const slot = pickLowestCrowdSlot(restrictedPlace, '2026-11-02', userWindow, 60);

  assert(slot !== null, 'Slot was found within restricted opening hours');
  if (slot) {
    assert(slot.startMinutes >= userWindow.startMinutes, `Slot start (${slot.startTime}) is inside user window`);
    assert(slot.endMinutes <= userWindow.endMinutes, `Slot end (${slot.endTime}) is inside user window`);
    assert(slot.startMinutes >= 11 * 60, `Slot start (${slot.startTime}) is >= 11:00 opening time`);
    assert(slot.endMinutes <= 16 * 60, `Slot end (${slot.endTime}) is <= 16:00 closing time`);
  }

  // Overnight opening hours test: Pub open 20:00-02:00
  const pub = {
    category: 'food',
    openingHours: { mon: '20:00-02:00' },
  };
  const eveningWindow = { startMinutes: 19 * 60, endMinutes: 23 * 60 };
  const pubSlot = pickLowestCrowdSlot(pub, '2026-11-02', eveningWindow, 90);
  assert(pubSlot !== null, 'Found slot for overnight place in evening window');
  if (pubSlot) {
    assert(pubSlot.startMinutes >= 20 * 60, `Overnight slot starts at or after 20:00 (got ${pubSlot.startTime})`);
  }

  // When place is closed on user date -> returns null
  const closedPlace = {
    category: 'heritage',
    openingHours: { mon: 'closed' },
  };
  const closedSlot = pickLowestCrowdSlot(closedPlace, '2026-11-02', userWindow, 60);
  assert(closedSlot === null, 'Returns null when place is closed on date');

  // --------------------------------------------------------------------------
  // 7. Category fallback profiles work
  // --------------------------------------------------------------------------
  console.log('\n7. Category Fallback Profiles:');
  const templeProfile = getCategoryHourlyProfile('temple');
  assert(templeProfile[6] > templeProfile[13], 'Temple has dawn peak (06:00 > 13:00)');
  assert(templeProfile[18] > templeProfile[13], 'Temple has evening aarti peak (18:00 > 13:00)');

  const marketProfile = getCategoryHourlyProfile('market');
  assert(marketProfile[19] > marketProfile[10], 'Market has evening rush (19:00 > 10:00)');

  const fortProfile = getCategoryHourlyProfile('fort');
  assert(fortProfile[11] > fortProfile[7], 'Fort has late morning rush (11:00 > 07:00)');

  const foodProfile = getCategoryHourlyProfile('food');
  assert(foodProfile[13] > foodProfile[16], 'Food has lunch rush (13:00 > 16:00)');
  assert(foodProfile[20] > foodProfile[16], 'Food has dinner peak (20:00 > 16:00)');

  const natureProfile = getCategoryHourlyProfile('nature');
  assert(natureProfile[7] > natureProfile[13], 'Nature has morning peak over midday (07:00 > 13:00)');

  const defaultProfile = getCategoryHourlyProfile('completely_unknown_category');
  assert(defaultProfile.length === 24, 'Unknown category falls back to 24-hr default profile');

  // Summary
  console.log(`\nTests Summary: ${passed} Passed, ${failed} Failed`);
  if (failed > 0) {
    process.exit(1);
  }
}

runCrowdTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
