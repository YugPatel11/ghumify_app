import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { verifyAuthToken } from '@/lib/auth/firebase-auth';
import { checkRateLimit } from '@/lib/language-resolution';
import {
  CROWD_CONFIG,
  CrowdConfidence,
  CrowdLevel,
  estimateCrowd,
  formatMinutesToTime,
  normalizeOpeningHours,
  parseTimeToMinutes,
  pickLowestCrowdSlot,
  rankCandidates,
  CandidatePlace,
  calculateHaversineKm,
  narrateItinerary,
  NarrationInput,
  planMultiDayCrowdItinerary,
} from '@/lib/crowd';
import {
  CURATED_CROWD_PROFILES,
  getHolidayForDate,
  resolveCrowdProfile,
} from '@/lib/crowd/profile-store';
import { placesRouter } from '@/lib/places';

// Validation Schema for Request Payload
const CandidateInputSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  category: z.string().default('heritage'),
  latitude: z.number(),
  longitude: z.number(),
  openingHours: z.any().optional(),
  entryFee: z.number().nullable().optional(),
  rating: z.number().nullable().optional(),
  reviewCount: z.number().nullable().optional(),
  popularity: z.number().nullable().optional(),
  capacity: z.union([z.string(), z.number()]).nullable().optional(),
  hourlyProfile: z.array(z.number()).length(24).optional(),
  durationMinutes: z.number().min(15).max(360).optional(),
  scoreInputs: z.object({
    interest: z.number().optional(),
    budget: z.number().optional(),
    foodFamily: z.number().optional(),
    distance: z.number().optional(),
    crowd: z.number().optional(),
  }).optional(),
});

const RecommendRequestSchema = z.object({
  city: z.string().min(1, 'City is required'),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be formatted as YYYY-MM-DD'),
  startTime: z.string().regex(/^\d{1,2}:\d{2}$/, 'startTime must be HH:MM').default('09:00'),
  endTime: z.string().regex(/^\d{1,2}:\d{2}$/, 'endTime must be HH:MM').default('18:00'),
  avoidCrowds: z.boolean().default(false),
  budgetCap: z.number().nullable().optional(),
  interests: z.array(z.string()).default([]),
  maxStops: z.number().int().min(1).max(8).default(4),
  originCoords: z.object({
    latitude: z.number(),
    longitude: z.number(),
  }).optional(),
  isMultiDay: z.boolean().default(false),
  numberOfDays: z.number().int().min(1).max(10).optional(),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  candidates: z.array(CandidateInputSchema).optional(),
});

export async function POST(request: NextRequest) {
  // 1. Feature Flag: Behind crowdAwareEnabled (default OFF -> 404)
  const isEnabled = (process.env.CROWD_AWARE_ENABLED || 'false').toLowerCase() === 'true';
  if (!isEnabled) {
    return NextResponse.json(
      { code: 'NOT_FOUND', error: 'Crowd-aware recommendation is currently disabled.' },
      { status: 404 }
    );
  }

  // 2. Authentication: Verify Firebase ID Token via firebase-admin
  const authHeader = request.headers.get('authorization');
  if (!authHeader) {
    return NextResponse.json(
      { code: 'UNAUTHORIZED', error: 'Missing Authorization header.' },
      { status: 401 }
    );
  }

  const auth = await verifyAuthToken(authHeader);
  if (!auth.valid) {
    return NextResponse.json(
      { code: 'UNAUTHORIZED', error: auth.error || 'Authentication required.' },
      { status: 401 }
    );
  }

  const userId = auth.userId || 'user_demo';

  // 3. Rate Limiting: 30 requests / minute per user
  const rate = checkRateLimit(`crowd_rec_${userId}`, 30, 60000);
  if (!rate.allowed) {
    return NextResponse.json(
      { code: 'RATE_LIMIT_EXCEEDED', error: 'Too many requests. Please wait a moment.' },
      { status: 429 }
    );
  }

  // 4. Input Parsing & Validation
  let rawBody: any;
  try {
    rawBody = await request.json();
  } catch {
    return NextResponse.json(
      { code: 'INVALID_JSON', error: 'Invalid JSON request payload.' },
      { status: 400 }
    );
  }

  const parseResult = RecommendRequestSchema.safeParse(rawBody);
  if (!parseResult.success) {
    return NextResponse.json(
      {
        code: 'BAD_REQUEST',
        error: 'Invalid request input.',
        details: parseResult.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`),
      },
      { status: 400 }
    );
  }

  const {
    city,
    date,
    startTime,
    endTime,
    avoidCrowds,
    budgetCap,
    interests,
    maxStops,
    originCoords,
  } = parseResult.data;

  const startMinutes = parseTimeToMinutes(startTime);
  const endMinutes = parseTimeToMinutes(endTime);

  if (endMinutes <= startMinutes + 60) {
    return NextResponse.json(
      { code: 'INVALID_WINDOW', error: 'Day endTime must be at least 60 minutes after startTime.' },
      { status: 400 }
    );
  }

  // 5. Calendar Context (Holidays, Seasonality)
  const holiday = getHolidayForDate(date);
  const dateObj = new Date(date);
  const month = dateObj.getMonth(); // 0..11
  const isPeakSeason = month >= 9 || month <= 2; // Oct to Mar in India

  const calendarContext = {
    isHoliday: Boolean(holiday),
    holidayName: holiday?.name,
    eventMultiplier: holiday?.multiplier,
    season: isPeakSeason ? ('peak' as const) : ('regular' as const),
  };

  // 6. Resolve Candidate Places
  let candidatePool: CandidatePlace[] = (parseResult.data.candidates || []) as CandidatePlace[];

  if (candidatePool.length === 0) {
    // If client did not provide candidates, load from curated database or live places router
    const curatedForCity = CURATED_CROWD_PROFILES.filter(
      (p) => p.city?.toLowerCase() === city.toLowerCase()
    );

    if (curatedForCity.length > 0) {
      candidatePool = curatedForCity.map((cp, idx) => ({
        id: cp.placeId,
        name: cp.name || cp.placeId,
        category: cp.category,
        latitude: 26.9124 + idx * 0.015,
        longitude: 75.7873 + idx * 0.015,
        popularity: 75,
        capacity: cp.capacity,
        hourlyProfile: cp.hourlyProfile,
        openingHours: { daily: '09:00-18:00' },
      }));
    } else {
      try {
        const liveResult = await placesRouter.search({ city, limit: 12 });
        candidatePool = liveResult.data.map((lp) => ({
          id: lp.id,
          name: lp.name,
          category: lp.category,
          latitude: lp.latitude,
          longitude: lp.longitude,
          rating: lp.rating,
          reviewCount: lp.reviewCount,
          openingHours: lp.openingHours,
          entryFee: lp.entryFee,
        }));
      } catch {
        // Fallback to sample city landmarks
        candidatePool = [
          {
            id: `${city.toLowerCase()}_monument_1`,
            name: `${city} Heritage Monument`,
            category: 'heritage',
            latitude: 26.91,
            longitude: 75.82,
            popularity: 80,
            openingHours: { daily: '09:00-18:00' },
          },
          {
            id: `${city.toLowerCase()}_market_1`,
            name: `${city} Traditional Bazaar`,
            category: 'market',
            latitude: 26.92,
            longitude: 75.83,
            popularity: 70,
            openingHours: { daily: '10:00-21:00' },
          },
          {
            id: `${city.toLowerCase()}_food_1`,
            name: `${city} Famous Food Street`,
            category: 'food',
            latitude: 26.915,
            longitude: 75.825,
            popularity: 85,
            openingHours: { daily: '11:00-22:00' },
          },
          {
            id: `${city.toLowerCase()}_garden_1`,
            name: `${city} Royal Botanical Gardens`,
            category: 'nature',
            latitude: 26.905,
            longitude: 75.815,
            popularity: 60,
            openingHours: { daily: '06:00-18:00' },
          },
        ];
      }
    }
  }

  // Multi-day routing if requested
  if (parseResult.data.isMultiDay || (parseResult.data.numberOfDays && parseResult.data.numberOfDays > 1)) {
    const multiResult = await planMultiDayCrowdItinerary({
      city,
      startDate: parseResult.data.startDate || date,
      numberOfDays: parseResult.data.numberOfDays || 3,
      dailyStartTime: startTime,
      dailyEndTime: endTime,
      avoidCrowds,
      budgetCap,
      candidates: candidatePool,
    });
    return NextResponse.json(multiResult);
  }

  // Augment candidates with resolved crowd profile data
  const augmentedPool = candidatePool.map((c) => {
    const profile = resolveCrowdProfile({
      placeId: c.id,
      category: c.category,
    });
    return {
      ...c,
      capacity: c.capacity ?? profile.capacity,
      hourlyProfile: c.hourlyProfile ?? profile.hourlyProfile,
      hasStatistics: profile.confidence === 'medium',
    };
  });

  // 7. Pick Lowest-Crowd Slot per Candidate within opening hours and user window
  const userWindow = { startMinutes, endMinutes };
  const candidatesWithSlots: Array<{
    candidate: CandidatePlace;
    slot: {
      startMinutes: number;
      endMinutes: number;
      startTime: string;
      endTime: string;
      crowdScore: number;
      crowdLevel: CrowdLevel;
      confidence: CrowdConfidence;
      reasons: string[];
    };
  }> = [];

  for (const candidate of augmentedPool) {
    const duration = (candidate as any).durationMinutes || 60;
    const bestSlot = pickLowestCrowdSlot(
      candidate,
      date,
      userWindow,
      duration,
      calendarContext,
      30
    );

    if (bestSlot) {
      candidatesWithSlots.push({
        candidate,
        slot: bestSlot,
      });
    }
  }

  // 8. Rank Candidates with Hard Filters & Renormalized Weights
  const { ranked } = rankCandidates(
    candidatesWithSlots.map((cs) => cs.candidate),
    {
      date,
      avoidCrowds,
      budgetCap,
      originCoords,
      calendarContext,
    }
  );

  // Take top candidates up to maxStops
  const selectedCandidates = ranked.slice(0, maxStops).map((r) => r.candidate);

  // 9. Sequencing: Order by chosen slot, then neighbour swaps if (travel + crowd penalty) decreases
  let orderedStops = selectedCandidates.map((cand) => {
    const slotInfo = candidatesWithSlots.find((cs) => cs.candidate.id === cand.id)!.slot;
    return {
      cand,
      slot: slotInfo,
      suggestedStartMinutes: slotInfo.startMinutes,
      suggestedEndMinutes: slotInfo.endMinutes,
    };
  });

  // Initial order by chosen slot start time
  orderedStops.sort((a, b) => a.suggestedStartMinutes - b.suggestedStartMinutes);

  // Neighbour swap optimization:
  // If adjacent stops travel time + crowd score can be decreased by swapping, do so
  for (let i = 0; i < orderedStops.length - 1; i++) {
    const cur = orderedStops[i];
    const next = orderedStops[i + 1];

    const currentTravelDist = calculateHaversineKm(
      cur.cand.latitude,
      cur.cand.longitude,
      next.cand.latitude,
      next.cand.longitude
    );
    const currentCost = currentTravelDist * 1.5 + (cur.slot.crowdScore + next.slot.crowdScore) * 0.2;

    // Check cost if swapped (assuming next visited before cur)
    const hoursCur = normalizeOpeningHours(cur.cand.openingHours);
    const hoursNext = normalizeOpeningHours(next.cand.openingHours);

    const durNext = next.suggestedEndMinutes - next.suggestedStartMinutes;
    const durCur = cur.suggestedEndMinutes - cur.suggestedStartMinutes;

    const canSwap =
      hoursNext.isOpenSpan(date, cur.suggestedStartMinutes, durNext) &&
      hoursCur.isOpenSpan(date, cur.suggestedStartMinutes + durNext + 15, durCur);

    if (canSwap) {
      const swappedCost = currentTravelDist * 1.5 + (next.slot.crowdScore + cur.slot.crowdScore) * 0.2;
      if (swappedCost < currentCost) {
        // Swap
        orderedStops[i] = next;
        orderedStops[i + 1] = cur;
      }
    }
  }

  // Sequentially adjust schedule so stops do not overlap
  let currentRunningMinutes = startMinutes;
  const finalizedStops = [];

  for (let i = 0; i < orderedStops.length; i++) {
    const item = orderedStops[i];
    const duration = item.slot.endMinutes - item.slot.startMinutes;

    let travelMins = 0;
    if (i > 0) {
      const prev = orderedStops[i - 1].cand;
      const distKm = calculateHaversineKm(
        prev.latitude,
        prev.longitude,
        item.cand.latitude,
        item.cand.longitude
      );
      travelMins = Math.max(5, Math.min(60, Math.round((distKm / 25) * 60 + 5)));
    }

    currentRunningMinutes += travelMins;
    const stopStart = Math.max(currentRunningMinutes, item.slot.startMinutes);
    const stopEnd = stopStart + duration;

    // If stop exceeds end of day window, break
    if (stopEnd > endMinutes && finalizedStops.length > 0) {
      break;
    }

    currentRunningMinutes = stopEnd;

    // 10. Find Alternatives: max 2, same category, lower crowd, open at that time
    const alternatives: Array<{
      placeId: string;
      name: string;
      category: string;
      estimatedCrowdLevel: CrowdLevel;
      crowdScore: number;
      suggestedStart: string;
      suggestedEnd: string;
      reasons: string[];
    }> = [];

    const otherCandidates = augmentedPool.filter((c) => c.id !== item.cand.id);
    for (const alt of otherCandidates) {
      if (alternatives.length >= 2) break;

      // Must share category (or category group)
      const sameCategory =
        alt.category.toLowerCase() === item.cand.category.toLowerCase() ||
        (alt.category.includes('heritage') && item.cand.category.includes('fort')) ||
        (alt.category.includes('fort') && item.cand.category.includes('heritage'));

      if (!sameCategory) continue;

      const altHours = normalizeOpeningHours(alt.openingHours);
      if (!altHours.isOpenSpan(date, stopStart, duration)) continue;

      const altMidHour = Math.floor((stopStart + duration / 2) / 60);
      const altEstimate = estimateCrowd(alt, date, altMidHour, calendarContext);

      // Must have lower crowd than the chosen stop
      if (altEstimate.score < item.slot.crowdScore) {
        alternatives.push({
          placeId: alt.id,
          name: alt.name,
          category: alt.category,
          estimatedCrowdLevel: altEstimate.level,
          crowdScore: altEstimate.score,
          suggestedStart: formatMinutesToTime(stopStart),
          suggestedEnd: formatMinutesToTime(stopEnd),
          reasons: altEstimate.reasons,
        });
      }
    }

    finalizedStops.push({
      placeId: item.cand.id,
      name: item.cand.name,
      category: item.cand.category,
      suggestedStart: formatMinutesToTime(stopStart),
      suggestedEnd: formatMinutesToTime(stopEnd),
      durationMinutes: duration,
      estimatedCrowdLevel: item.slot.crowdLevel,
      crowdScore: item.slot.crowdScore,
      confidence: item.slot.confidence,
      reasons: item.slot.reasons,
      alternatives,
    });
  }

  // 11. Narration Step (Gemini with Retry & Template Fallback)
  // Send ONLY selected stops, slots, order, and crowd labels. Never send userId.
  const narrationInput: NarrationInput = {
    city,
    date,
    stops: finalizedStops.map((s) => ({
      placeId: s.placeId,
      name: s.name,
      category: s.category,
      suggestedStart: s.suggestedStart,
      suggestedEnd: s.suggestedEnd,
      estimatedCrowdLevel: s.estimatedCrowdLevel,
      durationMinutes: s.durationMinutes,
    })),
  };

  const narration = await narrateItinerary(narrationInput);

  const narratedStops = finalizedStops.map((stop, idx) => {
    const item = narration.stops[idx];
    return {
      ...stop,
      description: item?.description ?? `Explore ${stop.name} in ${city}.`,
      tips: item?.tips ?? [`Optimal window: ${stop.suggestedStart} - ${stop.suggestedEnd}.`],
    };
  });

  return NextResponse.json({
    city,
    date,
    avoidCrowds,
    totalStops: narratedStops.length,
    summary: narration.summary,
    narrationSource: narration.source,
    stops: narratedStops,
  });
}
