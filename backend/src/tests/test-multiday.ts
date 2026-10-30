import { planMultiDayCrowdItinerary } from '../lib/crowd/multiday';
import { CandidatePlace } from '../lib/crowd';

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

async function runMultiDayTests() {
  console.log('--- RUNNING MULTI-DAY CROWD-AWARE ENGINE VERIFICATION ---');

  // 10 realistic candidate places in Jaipur covering 3 geographic regions:
  // North (Amer Forts), Central (Old City Palaces), South/Bazaars (Markets & Food)
  const jaipurPlaces: CandidatePlace[] = [
    // North Cluster (Amer Forts) - High crowd sensitivity
    {
      id: 'amber_fort',
      name: 'Amber Fort',
      category: 'fort',
      latitude: 26.9855,
      longitude: 75.8513,
      popularity: 95,
      durationMinutes: 120,
      openingHours: { daily: '08:00-18:00' },
    },
    {
      id: 'jaigarh_fort',
      name: 'Jaigarh Fort',
      category: 'fort',
      latitude: 26.9833,
      longitude: 75.8488,
      popularity: 75,
      durationMinutes: 90,
      openingHours: { daily: '09:00-17:00' },
    },
    {
      id: 'nahargarh_fort',
      name: 'Nahargarh Fort',
      category: 'fort',
      latitude: 26.9372,
      longitude: 75.8156,
      popularity: 80,
      durationMinutes: 90,
      openingHours: { daily: '10:00-17:30' },
    },

    // Central Cluster (City Palace, Hawa Mahal, Jantar Mantar)
    {
      id: 'city_palace',
      name: 'City Palace',
      category: 'heritage',
      latitude: 26.9258,
      longitude: 75.8237,
      popularity: 88,
      durationMinutes: 100,
      openingHours: { daily: '09:30-17:00' },
    },
    {
      id: 'hawa_mahal',
      name: 'Hawa Mahal',
      category: 'heritage',
      latitude: 26.9239,
      longitude: 75.8267,
      popularity: 90,
      durationMinutes: 60,
      openingHours: { daily: '09:00-17:00' },
    },
    {
      id: 'jantar_mantar',
      name: 'Jantar Mantar',
      category: 'heritage',
      latitude: 26.9248,
      longitude: 75.8246,
      popularity: 78,
      durationMinutes: 60,
      openingHours: { daily: '09:00-17:00' },
    },

    // South / Market Cluster
    {
      id: 'johari_bazaar',
      name: 'Johari Bazaar',
      category: 'market',
      latitude: 26.9189,
      longitude: 75.8276,
      popularity: 72,
      durationMinutes: 90,
      openingHours: { daily: '10:30-20:00' },
    },
    {
      id: 'bapu_bazaar',
      name: 'Bapu Bazaar',
      category: 'market',
      latitude: 26.9167,
      longitude: 75.8211,
      popularity: 74,
      durationMinutes: 90,
      openingHours: { daily: '11:00-21:00' },
    },
    {
      id: 'masala_chowk',
      name: 'Masala Chowk',
      category: 'food',
      latitude: 26.9038,
      longitude: 75.8189,
      popularity: 82,
      durationMinutes: 75,
      openingHours: { daily: '10:00-22:00' },
    },
  ];

  // Test 3-day window:
  // Day 1: 2026-11-06 (Friday, regular weekday, NO holiday) -> LOWEST crowd pressure
  // Day 2: 2026-11-07 (Saturday, regular weekend) -> MEDIUM crowd pressure
  // Day 3: 2026-11-08 (Sunday, Diwali festival holiday in DEFAULT_HOLIDAYS) -> HIGHEST crowd pressure
  console.log('\n[Case] 3-Day Test: Friday (weekday) -> Saturday (weekend) -> Sunday (Diwali)');

  const result = await planMultiDayCrowdItinerary({
    city: 'Jaipur',
    startDate: '2026-11-06',
    numberOfDays: 3,
    dailyStartTime: '09:00',
    dailyEndTime: '18:00',
    avoidCrowds: true,
    candidates: jaipurPlaces,
  });

  assert(result.days.length === 3, 'Output has exactly 3 days');
  assert(result.startDate === '2026-11-06', 'Start date is 2026-11-06');
  assert(result.endDate === '2026-11-08', 'End date is 2026-11-08');

  // Verify Weekend and Holiday detection
  console.log('\n--- Day 1 (Friday, 2026-11-06) ---');
  const day1 = result.days[0];
  console.log(`  Date: ${day1.date} | Weekend: ${day1.isWeekend} | Holiday: ${day1.isHoliday}`);
  console.log(`  Theme: "${day1.theme}" | Stops: ${day1.stops.map((s) => s.name).join(', ')}`);
  assert(!day1.isWeekend, 'Day 1 is NOT a weekend');
  assert(!day1.isHoliday, 'Day 1 is NOT a holiday');

  console.log('\n--- Day 2 (Saturday, 2026-11-07) ---');
  const day2 = result.days[1];
  console.log(`  Date: ${day2.date} | Weekend: ${day2.isWeekend} | Holiday: ${day2.isHoliday}`);
  console.log(`  Theme: "${day2.theme}" | Stops: ${day2.stops.map((s) => s.name).join(', ')}`);
  assert(day2.isWeekend, 'Day 2 IS a weekend');
  assert(!day2.isHoliday, 'Day 2 is NOT a holiday');

  console.log('\n--- Day 3 (Sunday, 2026-11-08, Diwali) ---');
  const day3 = result.days[2];
  console.log(`  Date: ${day3.date} | Weekend: ${day3.isWeekend} | Holiday: ${day3.isHoliday} (${day3.holidayName})`);
  console.log(`  Theme: "${day3.theme}" | Stops: ${day3.stops.map((s) => s.name).join(', ')}`);
  assert(day3.isWeekend, 'Day 3 IS a weekend');
  assert(day3.isHoliday, 'Day 3 IS recognized as Diwali holiday');
  assert(day3.holidayName === 'Diwali', 'Day 3 holidayName is Diwali');

  // Check Crowd-Sensitive Anchor Placement
  // Amber Fort has highest popularity (95) and fort sensitivity.
  // Must be placed on Day 1 (Friday, lowest crowd day), NOT on Sunday (Diwali).
  console.log('\n--- Verifying Crowd Sensitivity Placement ---');
  const day1Names = day1.stops.map((s) => s.name);
  const day3Names = day3.stops.map((s) => s.name);
  assert(day1Names.includes('Amber Fort'), 'Most crowd-sensitive place (Amber Fort) is scheduled on Friday (lowest-crowd day)');
  assert(!day3Names.includes('Amber Fort'), 'Amber Fort is avoided on Sunday (Diwali holiday)');

  // Check Stop Balance (diff <= 2)
  console.log('\n--- Verifying Stop Count Balance ---');
  const stopCounts = result.days.map((d) => d.stops.length);
  const maxStops = Math.max(...stopCounts);
  const minStops = Math.min(...stopCounts);
  console.log(`  Stop counts per day: ${stopCounts.join(', ')} (max: ${maxStops}, min: ${minStops})`);
  assert(maxStops - minStops <= 2, `Stop counts differ by at most 2 (actual diff: ${maxStops - minStops})`);
  assert(minStops >= 2, 'Every day has at least 2 stops');

  // Check Daily Windows (No day over its window)
  console.log('\n--- Verifying Daily Window (09:00 - 18:00 = 540 min) ---');
  const windowStartMin = 9 * 60; // 540
  const windowEndMin = 18 * 60;   // 1080
  const maxDayMinutes = windowEndMin - windowStartMin; // 540

  for (const d of result.days) {
    console.log(`  Day ${d.dayNumber} total visit minutes: ${d.totalMinutes}m (max: ${maxDayMinutes}m)`);
    assert(d.totalMinutes <= maxDayMinutes, `Day ${d.dayNumber} visit minutes (${d.totalMinutes}m) fits in daily window`);

    for (const s of d.stops) {
      const [sh, sm] = s.suggestedStart.split(':').map(Number);
      const [eh, em] = s.suggestedEnd.split(':').map(Number);
      const startMin = sh * 60 + sm;
      const endMin = eh * 60 + em;

      assert(startMin >= windowStartMin, `Stop "${s.name}" starts at/after window start 09:00 (actual: ${s.suggestedStart})`);
      assert(endMin <= windowEndMin, `Stop "${s.name}" ends at/before window end 18:00 (actual: ${s.suggestedEnd})`);
    }
  }

  // Check Short Theme per Day
  console.log('\n--- Verifying Day Themes ---');
  for (const d of result.days) {
    assert(typeof d.theme === 'string' && d.theme.length > 5, `Day ${d.dayNumber} has theme: "${d.theme}"`);
    assert(d.theme.length <= 40, `Day ${d.dayNumber} theme is concise (length: ${d.theme.length})`);
  }

  // Check Step 4-5 Reuse per Day (slots, crowd labels, narration)
  console.log('\n--- Verifying Steps 4-5 Reuse per Day ---');
  for (const d of result.days) {
    assert(d.summary.length > 10, `Day ${d.dayNumber} has summary: "${d.summary.slice(0, 40)}..."`);
    for (const s of d.stops) {
      assert(['low', 'moderate', 'busy', 'very_busy'].includes(s.estimatedCrowdLevel.toLowerCase()), `Stop "${s.name}" has valid crowd level: ${s.estimatedCrowdLevel}`);
      assert(s.description.length > 10, `Stop "${s.name}" has narrated description`);
      assert(s.tips.length > 0, `Stop "${s.name}" has tips`);
    }
  }

  console.log(`\n========================================`);
  console.log(`TOTAL: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
  console.log(`========================================`);

  if (failed > 0) {
    process.exit(1);
  }
}

runMultiDayTests().catch((e) => {
  console.error('Test runner failure:', e);
  process.exit(1);
});

