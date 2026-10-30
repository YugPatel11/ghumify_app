import {
  CandidatePlace,
  CrowdLevel,
  estimateCrowd,
  formatMinutesToTime,
  normalizeOpeningHours,
  parseTimeToMinutes,
  pickLowestCrowdSlot,
} from './index';
import { CURATED_CROWD_PROFILES, resolveCrowdProfile } from './profile-store';
import { GeminiCaller } from './narration';

export interface ModifyRequest {
  userMessage: string;
  action?: 'replace_place' | 'add_food_stop' | 'less_time' | 'more_relaxed' | 'auto';
  targetPlaceName?: string;
  currentItinerary: any;
  foodPreference?: string;
}

export interface ModifyResponse {
  chatMessage: string;
  updatedItinerary: any | null;
}

/**
 * Fuzzy matches a place name query against a list of stops.
 */
export function fuzzyMatchStop(
  stops: Array<{ name: string; id?: string; placeId?: string }>,
  query: string
): { match?: any; ambiguous?: any[]; none?: boolean } {
  const q = query.trim().toLowerCase();
  if (!q) return { none: true };

  // 1. Exact match
  const exact = stops.find((s) => s.name.toLowerCase() === q);
  if (exact) return { match: exact };

  // 2. Substring match
  const substringMatches = stops.filter((s) => {
    const sName = s.name.toLowerCase();
    return sName.includes(q) || q.includes(sName);
  });

  if (substringMatches.length === 1) {
    return { match: substringMatches[0] };
  }
  if (substringMatches.length > 1) {
    return { ambiguous: substringMatches };
  }

  // 3. Significant token match (requires at least 60% of query tokens to match stop tokens)
  const qTokens = q
    .split(/\s+/)
    .filter((t) => t.length > 2 && !['the', 'and', 'visit', 'stop', 'place'].includes(t));

  if (qTokens.length > 0) {
    const scored = stops
      .map((s) => {
        const sTokens = s.name.toLowerCase().split(/\s+/);
        const matchCount = qTokens.filter((qt) => sTokens.some((st) => st === qt)).length;
        const ratio = matchCount / qTokens.length;
        return { stop: s, matchCount, ratio };
      })
      .filter((x) => x.ratio >= 0.6);

    if (scored.length === 1) {
      return { match: scored[0].stop };
    }
    if (scored.length > 1) {
      return { ambiguous: scored.map((x) => x.stop) };
    }
  }

  return { none: true };
}

/**
 * Detects the modification intent from user message.
 */
export function detectModificationIntent(message: string): 'replace_place' | 'add_food_stop' | 'less_time' | 'more_relaxed' | 'other' {
  const m = message.toLowerCase();
  if (m.includes('replace') || m.includes('swap') || m.includes('change place')) {
    return 'replace_place';
  }
  if (m.includes('food') || m.includes('lunch') || m.includes('dinner') || m.includes('restaurant') || m.includes('eat') || m.includes('snack')) {
    return 'add_food_stop';
  }
  if (m.includes('less time') || m.includes('shorter') || m.includes('cut short') || m.includes('finish early') || m.includes('end early') || m.includes('leave by')) {
    return 'less_time';
  }
  if (m.includes('relaxed') || m.includes('slow down') || m.includes('more time') || m.includes('leisure') || m.includes('too rushed') || m.includes('breathe')) {
    return 'more_relaxed';
  }
  return 'other';
}

/**
 * Extracts candidate place name to replace from user message.
 */
export function extractPlaceQuery(message: string): string {
  const m = message.trim();
  const replacePatterns = [
    /replace\s+(?:the\s+)?(.+?)(?:\s+(?:with|by|for)|$|\.|\?)/i,
    /swap\s+(?:the\s+)?(.+?)(?:\s+(?:with|by|for)|$|\.|\?)/i,
    /change\s+(?:the\s+)?(.+?)(?:\s+(?:to|for|with)|$|\.|\?)/i,
    /remove\s+(?:the\s+)?(.+?)(?:\s+(?:and|from)|$|\.|\?)/i,
  ];

  for (const pat of replacePatterns) {
    const match = m.match(pat);
    if (match && match[1]) {
      return match[1].trim();
    }
  }

  return '';
}

/**
 * Calls Gemini to generate a warm, concise conversational message explaining the change.
 * Falls back to default template message if Gemini fails.
 */
async function generateChatMessage(
  summaryOfChange: string,
  geminiCaller?: GeminiCaller
): Promise<string> {
  if (geminiCaller) {
    try {
      const prompt = `You are a warm, helpful travel assistant.
The itinerary modification has already been calculated by the engine:
"${summaryOfChange}"

Write a friendly, concise 1-2 sentence response to the traveler explaining what was updated. Do NOT output raw JSON or code.`;

      const response = await geminiCaller(prompt, { type: 'STRING' });
      const clean = response.replace(/^```json\s*/i, '').replace(/```\s*$/i, '').trim();
      if (clean.length > 5 && !clean.startsWith('{')) {
        return clean;
      }
    } catch {
      // Fall through to template
    }
  }

  return summaryOfChange;
}

/**
 * Main modifier engine routing the 4 key modification actions.
 */
export async function modifyItineraryWithEngine(
  req: ModifyRequest,
  geminiCaller?: GeminiCaller
): Promise<ModifyResponse> {
  const { userMessage, currentItinerary, foodPreference = 'all' } = req;
  const intent = req.action && req.action !== 'auto' ? req.action : detectModificationIntent(userMessage);

  if (!currentItinerary || !currentItinerary.stops || !Array.isArray(currentItinerary.stops)) {
    return {
      chatMessage: "I couldn't locate your current itinerary stops to modify. Please try refreshing.",
      updatedItinerary: null,
    };
  }

  const stops = [...currentItinerary.stops];
  const city = currentItinerary.city || 'Jaipur';
  const date = currentItinerary.date || new Date().toISOString().slice(0, 10);
  const dailyStart = currentItinerary.startTime || '09:00';
  const dailyEnd = currentItinerary.endTime || '18:00';
  const windowStartMin = parseTimeToMinutes(dailyStart);
  let windowEndMin = parseTimeToMinutes(dailyEnd);

  // ──────────────────────────────────────────────────────────────────────────
  // 1. ACTION: Replace a place
  // ──────────────────────────────────────────────────────────────────────────
  if (intent === 'replace_place') {
    const targetQuery = req.targetPlaceName || extractPlaceQuery(userMessage);
    if (!targetQuery) {
      return {
        chatMessage: "Which place would you like to replace? Please let me know the name of the attraction.",
        updatedItinerary: null,
      };
    }

    const matchResult = fuzzyMatchStop(stops, targetQuery);

    if (matchResult.ambiguous && matchResult.ambiguous.length > 1) {
      const names = matchResult.ambiguous.map((s) => s.name).join(' and ');
      return {
        chatMessage: `I found multiple matching places: ${names}. Which one would you like to replace?`,
        updatedItinerary: null,
      };
    }

    if (!matchResult.match) {
      return {
        chatMessage: `I couldn't find "${targetQuery}" in your current itinerary. Please check the name and try again.`,
        updatedItinerary: null,
      };
    }

    const targetStop = matchResult.match;
    const targetIdx = stops.findIndex((s) => s.name === targetStop.name);

    // Find available curated places in the same city not already in stops
    const existingNames = new Set(stops.map((s) => s.name.toLowerCase()));
    const curatedMatches = CURATED_CROWD_PROFILES.filter(
      (cp) =>
        cp.city?.toLowerCase() === city.toLowerCase() &&
        !existingNames.has((cp.name || '').toLowerCase())
    );

    // Filter to candidates that are open during the target slot
    const targetDuration = targetStop.durationMinutes || 90;
    const targetStartMin = parseTimeToMinutes(targetStop.startTime || '10:00');

    let replacementPlace: any = null;
    for (const cp of curatedMatches) {
      const openingHours = { daily: '09:00-18:00' };
      const hours = normalizeOpeningHours(openingHours);
      if (hours.isOpenSpan(date, targetStartMin, targetDuration)) {
        replacementPlace = {
          id: cp.placeId,
          name: cp.name,
          category: cp.category,
          latitude: 26.91 + curatedMatches.indexOf(cp) * 0.01,
          longitude: 75.82 + curatedMatches.indexOf(cp) * 0.01,
          popularity: 75,
          openingHours,
          durationMinutes: targetDuration,
        };
        break;
      }
    }

    // If no replacement found or opening hours violated
    if (!replacementPlace) {
      return {
        chatMessage: `I couldn't find an open replacement for ${targetStop.name} during that time window because other attractions are closed.`,
        updatedItinerary: null,
      };
    }

    // Replace stop and recompute timings
    const updatedStops = [...stops];
    updatedStops[targetIdx] = {
      ...targetStop,
      placeId: replacementPlace.id,
      name: replacementPlace.name,
      category: replacementPlace.category,
      description: `Explore ${replacementPlace.name}, an alternative ${replacementPlace.category} in ${city}.`,
      tips: [`Visit during ${targetStop.startTime} - ${targetStop.endTime}.`],
    };

    // Recompute slots for day
    let runningMin = windowStartMin;
    for (let i = 0; i < updatedStops.length; i++) {
      const dur = updatedStops[i].durationMinutes || 90;
      const sStart = runningMin;
      const sEnd = Math.min(windowEndMin, sStart + dur);
      updatedStops[i].startTime = formatMinutesToTime(sStart);
      updatedStops[i].endTime = formatMinutesToTime(sEnd);
      runningMin = sEnd + 15;
    }

    const updatedItinerary = {
      ...currentItinerary,
      stops: updatedStops,
    };

    const explanation = `I've replaced ${targetStop.name} with ${replacementPlace.name} and adjusted your timings.`;
    const friendlyChat = await generateChatMessage(explanation, geminiCaller);

    return {
      chatMessage: friendlyChat,
      updatedItinerary,
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. ACTION: Add a food stop
  // ──────────────────────────────────────────────────────────────────────────
  if (intent === 'add_food_stop') {
    // Check if day is already packed to window limit
    const totalCurrentDuration = stops.reduce((sum, s) => sum + (s.durationMinutes || 90) + 15, 0);
    const lunchDuration = 60;

    if (windowStartMin + totalCurrentDuration + lunchDuration > windowEndMin + 15) {
      return {
        chatMessage: `I cannot add a food stop because your schedule is already fully booked until ${dailyEnd}. Consider removing a stop to make room.`,
        updatedItinerary: null,
      };
    }

    // Find midday insertion index (e.g. around 12:30 or between stop 1 and 2)
    const insertIdx = Math.max(1, Math.min(stops.length, Math.floor(stops.length / 2)));
    const foodStop = {
      placeId: `food_${Date.now()}`,
      name: `${city} Traditional Feast & Street Food`,
      category: 'food',
      durationMinutes: lunchDuration,
      estimatedCrowdLevel: 'moderate',
      confidence: 'low',
      crowdReason: 'Popular lunch dining hours',
      description: `Savor authentic regional cuisine and local delicacies in ${city}.`,
      tips: ['Try the signature local thali and beverages.', 'Great time to rest and recharge.'],
    };

    const updatedStops = [...stops];
    updatedStops.splice(insertIdx, 0, foodStop);

    // Recompute all slots
    let runningMin = windowStartMin;
    for (let i = 0; i < updatedStops.length; i++) {
      const dur = updatedStops[i].durationMinutes || 90;
      const sStart = runningMin;
      const sEnd = Math.min(windowEndMin, sStart + dur);
      updatedStops[i].startTime = formatMinutesToTime(sStart);
      updatedStops[i].endTime = formatMinutesToTime(sEnd);
      runningMin = sEnd + 15;
    }

    const updatedItinerary = {
      ...currentItinerary,
      stops: updatedStops,
    };

    const explanation = `I've added a delicious food stop "${foodStop.name}" around lunch time and recalculated your schedule.`;
    const friendlyChat = await generateChatMessage(explanation, geminiCaller);

    return {
      chatMessage: friendlyChat,
      updatedItinerary,
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. ACTION: I have less time
  // ──────────────────────────────────────────────────────────────────────────
  if (intent === 'less_time') {
    // Check if user specified a target end time e.g. "by 16:00"
    const timeMatch = userMessage.match(/(\d{1,2}:\d{2}|\d{1,2}\s*(?:am|pm))/i);
    let newEndMin = windowEndMin - 90; // Default: finish 90 mins earlier

    if (timeMatch) {
      const raw = timeMatch[1].toLowerCase();
      if (raw.includes(':')) {
        newEndMin = parseTimeToMinutes(raw);
      }
    }

    if (newEndMin <= windowStartMin + 60) {
      return {
        chatMessage: `I cannot shorten the day that much because you need at least a couple of hours for sightseeing.`,
        updatedItinerary: null,
      };
    }

    // Trim stops if needed so remaining stops fit within the newEndMin
    const updatedStops = [...stops];
    while (updatedStops.length > 1) {
      const totalDur = updatedStops.reduce((sum, s) => sum + (s.durationMinutes || 75) + 15, 0);
      if (windowStartMin + totalDur <= newEndMin + 15) break;
      updatedStops.pop(); // Drop last stop
    }

    // Recompute slots
    let runningMin = windowStartMin;
    for (let i = 0; i < updatedStops.length; i++) {
      const dur = updatedStops[i].durationMinutes || 75;
      const sStart = runningMin;
      const sEnd = Math.min(newEndMin, sStart + dur);
      updatedStops[i].startTime = formatMinutesToTime(sStart);
      updatedStops[i].endTime = formatMinutesToTime(sEnd);
      runningMin = sEnd + 15;
    }

    const updatedItinerary = {
      ...currentItinerary,
      endTime: formatMinutesToTime(newEndMin),
      stops: updatedStops,
    };

    const droppedCount = stops.length - updatedStops.length;
    const explanation = droppedCount > 0
      ? `I've shortened your day to conclude at ${formatMinutesToTime(newEndMin)}, trimming ${droppedCount} stop so you can wrap up comfortably on time.`
      : `I've compressed your schedule to conclude by ${formatMinutesToTime(newEndMin)}.`;

    const friendlyChat = await generateChatMessage(explanation, geminiCaller);

    return {
      chatMessage: friendlyChat,
      updatedItinerary,
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. ACTION: Make it more relaxed
  // ──────────────────────────────────────────────────────────────────────────
  if (intent === 'more_relaxed') {
    // Increase dwell times and buffer to 30 mins
    const updatedStops = [...stops];
    if (updatedStops.length > 3) {
      updatedStops.pop(); // Remove 1 stop if more than 3 stops for relaxed pace
    }

    const relaxedBuffer = 30;
    let runningMin = windowStartMin;

    for (let i = 0; i < updatedStops.length; i++) {
      const dur = updatedStops[i].durationMinutes || 90;
      const sStart = runningMin;
      const sEnd = Math.min(windowEndMin, sStart + dur);
      updatedStops[i].startTime = formatMinutesToTime(sStart);
      updatedStops[i].endTime = formatMinutesToTime(sEnd);
      runningMin = sEnd + relaxedBuffer;
    }

    const updatedItinerary = {
      ...currentItinerary,
      pace: 'relaxed',
      stops: updatedStops,
    };

    const explanation = `I've adjusted your pace to relaxed, adding generous 30-minute breaks between stops so you can explore without rushing.`;
    const friendlyChat = await generateChatMessage(explanation, geminiCaller);

    return {
      chatMessage: friendlyChat,
      updatedItinerary,
    };
  }

  // Fallback for general chat or unknown request
  return {
    chatMessage: "I'm ready to help you adjust your itinerary. You can ask me to replace a place, add a food stop, shorten the day, or make it more relaxed.",
    updatedItinerary: null,
  };
}
