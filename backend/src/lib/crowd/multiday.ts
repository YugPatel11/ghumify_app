import {
  calculateHaversineKm,
  CandidatePlace,
  CrowdConfidence,
  CrowdLevel,
  estimateCrowd,
  formatMinutesToTime,
  normalizeOpeningHours,
  parseTimeToMinutes,
  pickLowestCrowdSlot,
} from './index';
import { getHolidayForDate, resolveCrowdProfile } from './profile-store';
import { GeminiCaller, narrateItinerary, NarrationInput } from './narration';

export interface MultiDayStopRecommendation {
  placeId: string;
  name: string;
  category: string;
  suggestedStart: string;
  suggestedEnd: string;
  durationMinutes: number;
  estimatedCrowdLevel: CrowdLevel;
  crowdScore: number;
  confidence: CrowdConfidence;
  reasons: string[];
  description: string;
  tips: string[];
  alternatives: Array<{
    placeId: string;
    name: string;
    category: string;
    estimatedCrowdLevel: CrowdLevel;
    crowdScore: number;
    suggestedStart: string;
    suggestedEnd: string;
    reasons: string[];
  }>;
}

export interface MultiDayItineraryDay {
  dayNumber: number;
  date: string;
  theme: string;
  totalMinutes: number;
  isWeekend: boolean;
  isHoliday: boolean;
  holidayName?: string;
  summary: string;
  narrationSource: 'gemini' | 'template_fallback';
  stops: MultiDayStopRecommendation[];
}

export interface MultiDayRecommendationResult {
  city: string;
  startDate: string;
  endDate: string;
  numberOfDays: number;
  avoidCrowds: boolean;
  days: MultiDayItineraryDay[];
}

export interface MultiDayCrowdPlanOptions {
  city: string;
  startDate: string; // YYYY-MM-DD
  numberOfDays: number;
  dailyStartTime?: string; // default "09:00"
  dailyEndTime?: string; // default "18:00"
  avoidCrowds?: boolean;
  budgetCap?: number | null;
  candidates: CandidatePlace[];
  geminiCallerOverride?: GeminiCaller;
}

/**
 * Generates a descriptive theme for a day based on its dominant categories.
 */
export function generateDayTheme(stops: CandidatePlace[]): string {
  if (stops.length === 0) return 'City Exploration';

  const categories = stops.map((s) => s.category.toLowerCase());
  const hasFort = categories.some((c) => c.includes('fort') || c.includes('monument'));
  const hasPalace = categories.some((c) => c.includes('palace') || c.includes('heritage'));
  const hasMarket = categories.some((c) => c.includes('market') || c.includes('bazaar') || c.includes('craft'));
  const hasTemple = categories.some((c) => c.includes('temple') || c.includes('spiritual') || c.includes('religious'));
  const hasFood = categories.some((c) => c.includes('food') || c.includes('culinary') || c.includes('restaurant'));

  if (hasFort && hasPalace) return 'Royal Fortresses & Historic Palaces';
  if (hasFort) return 'Historic Forts & Panoramic Vistas';
  if (hasPalace) return 'Royal Palaces & Architectural Heritage';
  if (hasMarket && hasFood) return 'Vibrant Bazaars & Culinary Heritage';
  if (hasMarket) return 'Old City Markets & Artisan Bazaars';
  if (hasTemple) return 'Sacred Temples & Spiritual Heritage';
  return 'Iconic Landmarks & Cultural Highlights';
}

/**
 * Clusters places geographically into K days, placing crowd-sensitive popular places
 * on the lowest-crowd days (weekdays over weekends, non-holidays over holidays),
 * while balancing stops and minutes so stop counts differ by at most 2 and days fit in their window.
 */
export async function planMultiDayCrowdItinerary(
  options: MultiDayCrowdPlanOptions
): Promise<MultiDayRecommendationResult> {
  const {
    city,
    startDate,
    numberOfDays,
    dailyStartTime = '09:00',
    dailyEndTime = '18:00',
    avoidCrowds = false,
    budgetCap = null,
    candidates,
    geminiCallerOverride,
  } = options;

  const windowStartMin = parseTimeToMinutes(dailyStartTime);
  const windowEndMin = parseTimeToMinutes(dailyEndTime);
  const maxDayMinutes = windowEndMin - windowStartMin;

  // 1. Build calendar metadata for each day
  const dayMeta: Array<{
    dayNumber: number;
    date: string;
    isWeekend: boolean;
    isHoliday: boolean;
    holidayName?: string;
    dayPressure: number; // lower pressure = lower crowd
  }> = [];

  const startParsed = new Date(startDate);
  for (let d = 0; d < numberOfDays; d++) {
    const curDate = new Date(startParsed);
    curDate.setDate(startParsed.getDate() + d);
    const dateStr = curDate.toISOString().slice(0, 10);
    const dayOfWeek = curDate.getDay();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    const holiday = getHolidayForDate(dateStr);
    const isHoliday = Boolean(holiday);

    // Multipliers: weekend (1.25), holiday (1.30 to 1.50)
    const weekendFactor = isWeekend ? 1.25 : 1.0;
    const holidayFactor = holiday ? holiday.multiplier : 1.0;
    const dayPressure = weekendFactor * holidayFactor;

    dayMeta.push({
      dayNumber: d + 1,
      date: dateStr,
      isWeekend,
      isHoliday,
      holidayName: holiday?.name,
      dayPressure,
    });
  }

  const endDate = dayMeta[dayMeta.length - 1]?.date || startDate;

  // 2. Filter candidates by budgetCap
  let eligibleCandidates = candidates.filter((c) => {
    if (budgetCap !== null && budgetCap !== undefined && c.entryFee !== undefined && c.entryFee !== null) {
      return c.entryFee <= budgetCap;
    }
    return true;
  });

  if (eligibleCandidates.length === 0) {
    eligibleCandidates = [...candidates];
  }

  // 3. Score candidate places by crowd sensitivity & popularity
  const scoredCandidates = eligibleCandidates.map((c) => {
    const pop = c.popularity ?? (c.rating ? c.rating * 20 : 50);
    const profile = resolveCrowdProfile({ placeId: c.id, category: c.category });
    const weekendMult = profile.weekendMultiplier || 1.30;
    const sensitivity = pop * weekendMult;
    return { place: c, popularity: pop, sensitivity };
  });

  // Sort descending by sensitivity
  scoredCandidates.sort((a, b) => b.sensitivity - a.sensitivity);

  // 4. Map the top K most crowd-sensitive anchor places to the LOWEST crowd pressure days
  // Sort days ascending by dayPressure (lowest pressure first)
  const daysSortedByPressure = [...dayMeta].sort((a, b) => a.dayPressure - b.dayPressure);

  // Day assignment map: dayNumber -> CandidatePlace[]
  const dayBuckets: Map<number, CandidatePlace[]> = new Map();
  for (const dm of dayMeta) {
    dayBuckets.set(dm.dayNumber, []);
  }

  const assignedPlaceIds = new Set<string>();

  // Assign top anchors: day with lowest pressure gets place with highest sensitivity
  const anchorCount = Math.min(numberOfDays, scoredCandidates.length);
  for (let i = 0; i < anchorCount; i++) {
    const targetDay = daysSortedByPressure[i];
    const topPlace = scoredCandidates[i].place;
    dayBuckets.get(targetDay.dayNumber)!.push(topPlace);
    assignedPlaceIds.add(topPlace.id);
  }

  // 5. Geographic Clustering for Remaining Places
  // Calculate average target stops per day (e.g. 3-4 stops/day)
  const remainingCandidates = scoredCandidates
    .filter((sc) => !assignedPlaceIds.has(sc.place.id))
    .map((sc) => sc.place);

  const targetStopsPerDay = Math.min(5, Math.max(2, Math.floor(eligibleCandidates.length / numberOfDays)));
  const maxStopsPerDay = targetStopsPerDay + 1;

  for (const cand of remainingCandidates) {
    // Find candidate day that:
    // a) has capacity (< maxStopsPerDay)
    // b) does not exceed window minutes
    // c) minimizes geographic distance to day's cluster center
    let bestDayNum: number | null = null;
    let minDistance = Infinity;

    for (const dm of dayMeta) {
      const bucket = dayBuckets.get(dm.dayNumber)!;
      if (bucket.length >= maxStopsPerDay) continue;

      const currentDayMinutes = bucket.reduce((sum, p) => sum + (p.durationMinutes || 90) + 20, 0);
      const candDuration = cand.durationMinutes || 90;
      if (currentDayMinutes + candDuration + 20 > maxDayMinutes) continue;

      // Calculate distance to cluster center of this day
      let dist = 0;
      if (bucket.length > 0) {
        const centerLat = bucket.reduce((sum, p) => sum + p.latitude, 0) / bucket.length;
        const centerLon = bucket.reduce((sum, p) => sum + p.longitude, 0) / bucket.length;
        dist = calculateHaversineKm(cand.latitude, cand.longitude, centerLat, centerLon);
      }

      if (dist < minDistance) {
        minDistance = dist;
        bestDayNum = dm.dayNumber;
      }
    }

    if (bestDayNum !== null) {
      dayBuckets.get(bestDayNum)!.push(cand);
      assignedPlaceIds.add(cand.id);
    }
  }

  // 6. Ensure Stop Count Balance: max difference between any two days <= 2
  // If difference > 2, rebalance closest places from heaviest day to lightest day
  let balanced = false;
  let iterations = 0;
  while (!balanced && iterations < 10) {
    iterations++;
    const counts = Array.from(dayBuckets.values()).map((b) => b.length);
    const maxCount = Math.max(...counts);
    const minCount = Math.min(...counts);

    if (maxCount - minCount <= 2) {
      balanced = true;
      break;
    }

    const heavyDay = Array.from(dayBuckets.entries()).find(([, b]) => b.length === maxCount);
    const lightDay = Array.from(dayBuckets.entries()).find(([, b]) => b.length === minCount);

    if (!heavyDay || !lightDay) break;

    // Move the non-anchor place from heavyDay that is closest to lightDay
    const heavyPlaces = heavyDay[1];
    if (heavyPlaces.length <= 1) break;

    const lightCenterLat =
      lightDay[1].reduce((sum, p) => sum + p.latitude, 0) / (lightDay[1].length || 1);
    const lightCenterLon =
      lightDay[1].reduce((sum, p) => sum + p.longitude, 0) / (lightDay[1].length || 1);

    // Pick candidate place at index > 0 (keep anchor place at index 0)
    let bestMoveIndex = 1;
    let bestMoveDist = Infinity;
    for (let j = 1; j < heavyPlaces.length; j++) {
      const d = calculateHaversineKm(
        heavyPlaces[j].latitude,
        heavyPlaces[j].longitude,
        lightCenterLat,
        lightCenterLon
      );
      if (d < bestMoveDist) {
        bestMoveDist = d;
        bestMoveIndex = j;
      }
    }

    const [moved] = heavyPlaces.splice(bestMoveIndex, 1);
    lightDay[1].push(moved);
  }

  // 7. Process Each Day Reusing Steps 4-5 (Slot Selection + Narration)
  const resultDays: MultiDayItineraryDay[] = [];

  for (const dm of dayMeta) {
    const rawStops = dayBuckets.get(dm.dayNumber)!;
    const theme = generateDayTheme(rawStops);

    // 7a. Sequence stops by greedy nearest-neighbour starting from earliest opening
    const sequenced = [...rawStops];
    if (sequenced.length > 2) {
      // Simple 2-opt or nearest neighbour chain
      for (let i = 0; i < sequenced.length - 1; i++) {
        let nearestIdx = i + 1;
        let nearestDist = Infinity;
        for (let j = i + 1; j < sequenced.length; j++) {
          const d = calculateHaversineKm(
            sequenced[i].latitude,
            sequenced[i].longitude,
            sequenced[j].latitude,
            sequenced[j].longitude
          );
          if (d < nearestDist) {
            nearestDist = d;
            nearestIdx = j;
          }
        }
        if (nearestIdx !== i + 1) {
          const temp = sequenced[i + 1];
          sequenced[i + 1] = sequenced[nearestIdx];
          sequenced[nearestIdx] = temp;
        }
      }
    }

    // 7b. Assign slots with pickLowestCrowdSlot
    let runningMinutes = windowStartMin;
    const calendarContext = {
      isWeekend: dm.isWeekend,
      isHoliday: dm.isHoliday,
      holidayMultiplier: dm.isHoliday ? 1.35 : 1.0,
      seasonalityMonth: startParsed.getMonth() + 1,
    };

    const finalizedStops: MultiDayStopRecommendation[] = [];

    for (let sIdx = 0; sIdx < sequenced.length; sIdx++) {
      const place = sequenced[sIdx];
      const duration = place.durationMinutes || 90;

      // Slot selection within user window and opening hours
      const slot = pickLowestCrowdSlot(
        place,
        dm.date,
        { startMinutes: runningMinutes, endMinutes: windowEndMin },
        duration,
        calendarContext
      );

      let stopStart = runningMinutes;
      let stopEnd = Math.min(windowEndMin, stopStart + duration);
      let crowdLevel: CrowdLevel = 'moderate';
      let crowdScore = 45;
      let confidence: CrowdConfidence = 'low';
      let reasons = ['Optimal scheduled window'];

      if (slot) {
        stopStart = slot.startMinutes;
        stopEnd = slot.endMinutes;
        crowdLevel = slot.crowdLevel;
        crowdScore = slot.crowdScore;
        confidence = slot.confidence;
        reasons = slot.reasons;
      }

      // Find alternatives: max 2, same category, lower crowd, open at that time
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

      for (const alt of eligibleCandidates) {
        if (alternatives.length >= 2) break;
        if (alt.id === place.id) continue;
        if (alt.category.toLowerCase() !== place.category.toLowerCase()) continue;

        const altHours = normalizeOpeningHours(alt.openingHours);
        if (!altHours.isOpenSpan(dm.date, stopStart, duration)) continue;

        const altMidHour = Math.floor((stopStart + duration / 2) / 60);
        const altEst = estimateCrowd(alt, dm.date, altMidHour, calendarContext);
        if (altEst.score < crowdScore) {
          alternatives.push({
            placeId: alt.id,
            name: alt.name,
            category: alt.category,
            estimatedCrowdLevel: altEst.level,
            crowdScore: altEst.score,
            suggestedStart: formatMinutesToTime(stopStart),
            suggestedEnd: formatMinutesToTime(stopEnd),
            reasons: altEst.reasons,
          });
        }
      }

      finalizedStops.push({
        placeId: place.id,
        name: place.name,
        category: place.category,
        suggestedStart: formatMinutesToTime(stopStart),
        suggestedEnd: formatMinutesToTime(stopEnd),
        durationMinutes: stopEnd - stopStart,
        estimatedCrowdLevel: crowdLevel,
        crowdScore,
        confidence,
        reasons,
        description: '',
        tips: [],
        alternatives,
      });

      // Advance clock with travel buffer (15 mins)
      runningMinutes = Math.min(windowEndMin, stopEnd + 15);
    }

    // 7c. Narration Step per Day (Gemini with Retry and Template Fallback)
    const narrationInput: NarrationInput = {
      city,
      date: dm.date,
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

    const narration = await narrateItinerary(narrationInput, geminiCallerOverride);

    // Merge narrated text into day stops
    for (let k = 0; k < finalizedStops.length; k++) {
      const narrated = narration.stops[k];
      finalizedStops[k].description = narrated?.description || `Visit ${finalizedStops[k].name} in ${city}.`;
      finalizedStops[k].tips = narrated?.tips || [`Visit during ${finalizedStops[k].suggestedStart} - ${finalizedStops[k].suggestedEnd}.`];
    }

    const totalMinutes = finalizedStops.reduce((sum, s) => sum + s.durationMinutes, 0);

    resultDays.push({
      dayNumber: dm.dayNumber,
      date: dm.date,
      theme,
      totalMinutes,
      isWeekend: dm.isWeekend,
      isHoliday: dm.isHoliday,
      holidayName: dm.holidayName,
      summary: narration.summary,
      narrationSource: narration.source,
      stops: finalizedStops,
    });
  }

  return {
    city,
    startDate,
    endDate,
    numberOfDays,
    avoidCrowds,
    days: resultDays,
  };
}
