import { CrowdConfidence, CrowdLevel } from './config';
import { CalendarContext, estimateCrowd, PlaceCrowdProfile } from './estimate';
import { normalizeOpeningHours } from './normalizeOpeningHours';

export interface UserTimeWindow {
  startMinutes: number; // e.g. 09:00 -> 540
  endMinutes: number;   // e.g. 18:00 -> 1080
}

export interface SlotRecommendation {
  startMinutes: number;
  endMinutes: number;
  startTime: string; // "09:00"
  endTime: string;   // "10:30"
  crowdScore: number;
  crowdLevel: CrowdLevel;
  confidence: CrowdConfidence;
  reasons: string[];
}

export function formatMinutesToTime(minutes: number): string {
  const normalized = Math.max(0, Math.min(1439, Math.round(minutes)));
  const h = Math.floor(normalized / 60);
  const m = normalized % 60;
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
}

export function parseTimeToMinutes(timeStr: string): number {
  const parts = timeStr.trim().split(':');
  if (parts.length < 2) return 540; // Default 09:00
  const h = parseInt(parts[0], 10) || 0;
  const m = parseInt(parts[1], 10) || 0;
  return h * 60 + m;
}

/**
 * Evaluates all valid time slots within the user window and opening hours,
 * picking the slot that minimizes estimated crowd level.
 * 
 * Invariants guaranteed:
 * 1. Slot is strictly within the user window [startMinutes, endMinutes].
 * 2. Slot is strictly within the place's opening hours (isOpenSpan).
 * 3. Never returns a slot outside allowed hours.
 * 4. If no valid slot exists, returns null.
 */
export function pickLowestCrowdSlot(
  place: PlaceCrowdProfile & { openingHours?: any },
  date: Date | string,
  userWindow: UserTimeWindow,
  visitDurationMinutes: number = 60,
  calendarContext?: CalendarContext,
  stepMinutes: number = 30
): SlotRecommendation | null {
  const hours = normalizeOpeningHours(place.openingHours);

  // Check if place is closed completely on that date
  const d = typeof date === 'string' ? new Date(date) : date;
  const dayOfWeek = isNaN(d.getTime()) ? 1 : d.getDay();
  if (hours.days[dayOfWeek]?.isClosed) {
    return null;
  }

  const duration = Math.max(15, visitDurationMinutes);
  const latestStart = userWindow.endMinutes - duration;

  if (latestStart < userWindow.startMinutes) {
    return null; // Window is too short for the required visit duration
  }

  let bestSlot: SlotRecommendation | null = null;
  let lowestCrowd = Infinity;

  // Search in steps across the user window
  for (let start = userWindow.startMinutes; start <= latestStart; start += stepMinutes) {
    const end = start + duration;

    // Boundary check 1: Must fit in user window
    if (end > userWindow.endMinutes) {
      continue;
    }

    // Boundary check 2: Must be fully within opening hours
    const isOpen = hours.isOpenSpan(date, start, duration);
    if (!isOpen) {
      continue;
    }

    // Calculate crowd score during this slot
    // Midpoint hour of the visit gives representative crowd
    const midMinutes = start + duration / 2;
    const midHour = Math.floor(midMinutes / 60);

    const estimate = estimateCrowd(place, date, midHour, calendarContext);

    if (estimate.score < lowestCrowd) {
      lowestCrowd = estimate.score;
      bestSlot = {
        startMinutes: start,
        endMinutes: end,
        startTime: formatMinutesToTime(start),
        endTime: formatMinutesToTime(end),
        crowdScore: estimate.score,
        crowdLevel: estimate.level,
        confidence: estimate.confidence,
        reasons: estimate.reasons,
      };
    }
  }

  return bestSlot;
}
