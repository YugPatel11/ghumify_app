import {
  CROWD_CONFIG,
  CrowdConfidence,
  CrowdLevel,
  computeBaseCrowd,
  getCategoryHourlyProfile,
  getCrowdLevel,
} from './config';

export interface PlaceCrowdProfile {
  id?: string;
  name?: string;
  category?: string;
  popularity?: number | null;
  capacity?: string | number | null;
  hourlyProfile?: number[] | null;
  hasStatistics?: boolean | null;
}

export interface CalendarContext {
  isHoliday?: boolean;
  holidayName?: string;
  hasEvent?: boolean;
  eventName?: string;
  eventMultiplier?: number;
  season?: 'peak' | 'regular' | 'offPeak';
}

export interface CrowdEstimateResult {
  score: number;
  level: CrowdLevel;
  confidence: CrowdConfidence;
  reasons: string[];
}

/**
 * Estimates crowd score (0-100) using multiplicative formula:
 * C = clamp(base(popularity, capacity) x hourFactor x dayFactor x holidayFactor x eventFactor x seasonFactor, 0, 100)
 */
export function estimateCrowd(
  place: PlaceCrowdProfile,
  date: Date | string,
  hour: number,
  calendarContext?: CalendarContext
): CrowdEstimateResult {
  const d = typeof date === 'string' ? new Date(date) : date;
  const dayOfWeek = isNaN(d.getTime()) ? 1 : d.getDay(); // 0 = Sun..6 = Sat
  const validHour = Math.max(0, Math.min(23, Math.floor(hour)));

  // 1. Base crowd
  const base = computeBaseCrowd(place.popularity, place.capacity);

  // 2. Hourly factor
  let hourFactor: number;
  let isCustomProfile = false;
  if (Array.isArray(place.hourlyProfile) && place.hourlyProfile.length === 24) {
    hourFactor = place.hourlyProfile[validHour] ?? 1.0;
    isCustomProfile = true;
  } else {
    const catProfile = getCategoryHourlyProfile(place.category);
    hourFactor = catProfile[validHour] ?? 1.0;
  }

  // 3. Day of week factor
  const dayFactor = CROWD_CONFIG.dayFactors[dayOfWeek] ?? 1.0;

  // 4. Holiday factor
  const isHoliday = Boolean(calendarContext?.isHoliday);
  const holidayFactor = isHoliday ? CROWD_CONFIG.holidayFactor : 1.0;

  // 5. Event factor
  const hasEvent = Boolean(calendarContext?.hasEvent);
  const eventFactor = hasEvent
    ? (calendarContext?.eventMultiplier ?? CROWD_CONFIG.eventFactor)
    : 1.0;

  // 6. Season factor
  const season = calendarContext?.season ?? 'regular';
  const seasonFactor = CROWD_CONFIG.seasonFactors[season] ?? 1.0;

  // Multiplicative formula
  const rawScore = base * hourFactor * dayFactor * holidayFactor * eventFactor * seasonFactor;
  const score = Math.max(0, Math.min(100, Math.round(rawScore)));

  // Level classification (0-30 Low, 31-50 Moderate, 51-75 Busy, 76-100 Very Busy)
  const level = getCrowdLevel(score);

  // Confidence: "medium" if statistics-backed, "low" if curated / default
  const confidence: CrowdConfidence = place.hasStatistics || isCustomProfile ? 'medium' : 'low';

  // Human-readable explanatory reasons
  const reasons: string[] = [];
  if (hourFactor >= 1.5) {
    reasons.push(`Peak visit hour (${validHour}:00) for ${place.category || 'this type of place'}`);
  } else if (hourFactor <= 0.4) {
    reasons.push(`Quiet off-peak hour (${validHour}:00)`);
  }

  if (dayOfWeek === 0 || dayOfWeek === 6) {
    reasons.push('Weekend visitor rush');
  }

  if (isHoliday) {
    reasons.push(calendarContext?.holidayName ? `Public holiday (${calendarContext.holidayName})` : 'Public holiday surge');
  }

  if (hasEvent) {
    reasons.push(calendarContext?.eventName ? `Local event: ${calendarContext.eventName}` : 'Local event in progress');
  }

  if (season === 'peak') {
    reasons.push('Peak tourism season');
  } else if (season === 'offPeak') {
    reasons.push('Off-peak travel season');
  }

  if (reasons.length === 0) {
    reasons.push('Standard expected crowd conditions');
  }

  return {
    score,
    level,
    confidence,
    reasons,
  };
}

