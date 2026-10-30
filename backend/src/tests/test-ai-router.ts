import { PlaceSchema } from '../lib/schemas/place';
import { NearbyServiceSchema } from '../lib/schemas/nearby-service';
import { RawSingleDayAIOutputSchema, ItineraryModelSchema } from '../lib/schemas/itinerary';
import { RawMultiDayAIOutputSchema, MultiDayItineraryModelSchema } from '../lib/schemas/multi-day-itinerary';
import { CircuitBreaker } from '../lib/circuit-breaker';
import { rulePlanner } from '../lib/planner/rule-planner';
import { verifyStopsGrounded } from '../lib/ai/grounding';
import { Place } from '../lib/schemas/place';

async function runTests() {
  console.log('--- Starting Ghumify Backend AI & Places Router Tests ---');
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

  // 1. Circuit Breaker Tests (3 failures -> 60s cooldown -> recover)
  console.log('\n1. Circuit Breaker:');
  const cb = new CircuitBreaker({ failureThreshold: 3, cooldownMs: 100 });
  assert(cb.isAvailable('test_provider'), 'Initially available');
  cb.recordFailure('test_provider');
  cb.recordFailure('test_provider');
  assert(cb.isAvailable('test_provider'), 'Still available after 2 failures');
  cb.recordFailure('test_provider');
  assert(!cb.isAvailable('test_provider'), 'Circuit opens after 3 failures');
  await new Promise((r) => setTimeout(r, 120));
  assert(cb.isAvailable('test_provider'), 'Circuit recovers after cooldown expires');
  cb.recordSuccess('test_provider');

  // 2. Schema Validation Tests
  console.log('\n2. Zod Schema Validation:');
  const mockPlace: Place = {
    id: 'place_1',
    name: 'Amber Fort',
    city: 'Jaipur',
    state: 'Rajasthan',
    category: 'heritage',
    description: 'Iconic hill fort',
    history: '',
    latitude: 26.9855,
    longitude: 75.8513,
    address: 'Devisinghpura, Amer',
    openingHours: { mon: '09:00-18:00' },
    photoUrls: ['https://example.com/photo.jpg'],
    thumbnailUrl: 'https://example.com/photo.jpg',
    avgVisitDurationMinutes: 90,
    rating: 4.6,
    reviewCount: 45000,
    entryFee: 100,
    tags: ['historic', 'fort'],
    nearbyPlaceIds: [],
    googlePlaceId: 'ChIJ_amber',
    isHiddenGem: false,
    specialNote: 'Elephant ride available in morning',
    createdAt: new Date().toISOString(),
  };

  const parsedPlace = PlaceSchema.safeParse(mockPlace);
  assert(parsedPlace.success, 'Valid Place schema matches');

  const invalidPlace = { id: '', latitude: 'invalid' };
  assert(!PlaceSchema.safeParse(invalidPlace).success, 'Invalid place rejected');

  const mockService = {
    name: 'City Hospital',
    type: 'hospital',
    latitude: 26.9124,
    longitude: 75.7873,
    address: 'Station Road',
    distanceKm: 1.2,
  };
  assert(NearbyServiceSchema.safeParse(mockService).success, 'Valid NearbyService schema matches');

  // 3. Grounding & Invented Stop Detection
  console.log('\n3. Grounding & Anti-Hallucination:');
  const candidates: Place[] = [
    mockPlace,
    {
      ...mockPlace,
      id: 'food_1',
      name: 'Laxmi Mishthan Bhandar',
      category: 'food',
      latitude: 26.9200,
      longitude: 75.8200,
    },
  ];

  const groundedStops = [
    {
      name: 'Amber Fort',
      type: 'place',
      placeId: 'place_1',
      startTime: '09:30',
      endTime: '11:00',
      durationMinutes: 90,
      latitude: 26.9855,
      longitude: 75.8513,
      description: 'Visit fort',
      tips: [],
    },
  ];
  const groundCheckValid = verifyStopsGrounded(groundedStops as any, candidates);
  assert(groundCheckValid.valid, 'Grounded stop matching candidate passes');

  const inventedStops = [
    ...groundedStops,
    {
      name: 'Nonexistent Imaginary Palace',
      type: 'place',
      placeId: 'fake_999',
      startTime: '12:00',
      endTime: '13:00',
      durationMinutes: 60,
      latitude: 20.0,
      longitude: 70.0,
      description: 'Invented place',
      tips: [],
    },
  ];
  const groundCheckInvalid = verifyStopsGrounded(inventedStops as any, candidates);
  assert(!groundCheckInvalid.valid, 'Invented stop caught and rejected');
  assert(groundCheckInvalid.inventedStops.includes('Nonexistent Imaginary Palace'), 'Identified exact hallucinated stop');

  // 4. Rule-Based Planner (Degraded AI-free fallback)
  console.log('\n4. Rule-Based Planner:');
  const plannedSingle = rulePlanner.planSingleDay(candidates, {
    city: 'Jaipur',
    startTime: '09:00',
    endTime: '18:00',
    interests: ['heritage', 'food'],
    travelMode: 'driving',
    pace: 'moderate',
    budget: 2000,
  });

  assert(plannedSingle.stops.length >= 1, 'Rule planner generated sequential stops');
  assert(plannedSingle.expenseSummary !== null, 'Rule planner computed expense summary');
  assert(ItineraryModelSchema.safeParse(plannedSingle).success, 'Rule planner output passes ItineraryModel schema');

  const plannedMulti = rulePlanner.planMultiDay(candidates, {
    city: 'Jaipur',
    numberOfDays: 2,
    startTime: '09:00',
    endTime: '18:00',
    interests: ['heritage', 'food'],
    travelMode: 'driving',
    pace: 'moderate',
    budget: 5000,
  });
  assert(plannedMulti.days.length === 2, 'Rule planner generated 2 days for multi-day');
  assert(MultiDayItineraryModelSchema.safeParse(plannedMulti).success, 'Rule planner multi-day passes MultiDayItineraryModel schema');

  console.log(`\nTests Summary: ${passed} Passed, ${failed} Failed\n`);
  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((e) => {
  console.error(e);
  process.exit(1);
});

