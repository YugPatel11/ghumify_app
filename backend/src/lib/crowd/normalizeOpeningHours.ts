/**
 * Normalizes opening hours from Firestore or Google Places into a unified internal schedule.
 * Accurately models open windows, overnight spans (closing next day), closed days, and 24/7 operations.
 */

export interface TimeWindow {
  startMinutes: number; // minutes from 00:00 on the opening day (0..1439)
  endMinutes: number;   // minutes from 00:00 on opening day (e.g., 1620 for 03:00 next day)
  isOvernight?: boolean;
}

export interface DaySchedule {
  isClosed: boolean;
  isOpen24Hours: boolean;
  windows: TimeWindow[];
}

export interface NormalizedOpeningHours {
  // 0 = Sunday, 1 = Monday, ..., 6 = Saturday (JS Date.getDay())
  days: Record<number, DaySchedule>;
  isOpenAt(date: Date | string, hour: number, minute?: number): boolean;
  isOpenSpan(date: Date | string, startMinutes: number, durationMinutes: number): boolean;
  getWindowsForDate(date: Date | string): TimeWindow[];
}

const DAY_MAP: Record<string, number> = {
  sun: 0, sunday: 0,
  mon: 1, monday: 1,
  tue: 2, tuesday: 2, tues: 2,
  wed: 3, wednesday: 3,
  thu: 4, thursday: 4, thur: 4, thurs: 4,
  fri: 5, friday: 5,
  sat: 6, saturday: 6,
};

function parseTimeToMinutes(timeStr: string): number | null {
  const clean = timeStr.trim().toLowerCase();
  if (!clean) return null;

  // Check 12-hour AM/PM format (e.g., "9:30 AM", "5 PM", "11:00pm")
  const ampmMatch = clean.match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$/);
  if (ampmMatch) {
    let h = parseInt(ampmMatch[1], 10);
    const m = ampmMatch[2] ? parseInt(ampmMatch[2], 10) : 0;
    const isPm = ampmMatch[3] === 'pm';
    if (h === 12) h = isPm ? 12 : 0;
    else if (isPm) h += 12;
    return h * 60 + m;
  }

  // Check 24-hour HH:MM format or HHMM format (e.g., "09:00", "17:30", "0900", "2359")
  const hhmmMatch = clean.match(/^(\d{1,2}):?(\d{2})$/);
  if (hhmmMatch) {
    const h = parseInt(hhmmMatch[1], 10);
    const m = parseInt(hhmmMatch[2], 10);
    return h * 60 + m;
  }

  // Bare hour format (e.g. "9", "17")
  const bareHMatch = clean.match(/^(\d{1,2})$/);
  if (bareHMatch) {
    return parseInt(bareHMatch[1], 10) * 60;
  }

  return null;
}

function parseWindowString(spanStr: string): TimeWindow | null {
  const parts = spanStr.split(/[-–—to]/i);
  if (parts.length < 2) return null;

  const start = parseTimeToMinutes(parts[0]);
  const end = parseTimeToMinutes(parts[1]);
  if (start === null || end === null) return null;

  if (end <= start) {
    // Overnight span (e.g., 21:00 to 03:00 -> 1260 to 1440 + 180 = 1620)
    return {
      startMinutes: start,
      endMinutes: end + 1440,
      isOvernight: true,
    };
  }

  return {
    startMinutes: start,
    endMinutes: end,
    isOvernight: false,
  };
}

function parseDayString(rawVal: string): DaySchedule {
  const val = rawVal.trim().toLowerCase();

  if (val === 'closed' || val === 'off' || val === 'none') {
    return { isClosed: true, isOpen24Hours: false, windows: [] };
  }

  if (val.includes('24 hours') || val.includes('open 24') || val === '00:00-24:00' || val === '00:00-23:59') {
    return {
      isClosed: false,
      isOpen24Hours: true,
      windows: [{ startMinutes: 0, endMinutes: 1440, isOvernight: false }],
    };
  }

  // May contain multiple spans separated by comma or semicolon
  const spans = val.split(/[,;/]+/);
  const windows: TimeWindow[] = [];

  for (const span of spans) {
    const win = parseWindowString(span);
    if (win) windows.push(win);
  }

  if (windows.length === 0) {
    // If text was unrecognized but not explicitly "closed", default to standard daylight
    return {
      isClosed: false,
      isOpen24Hours: false,
      windows: [{ startMinutes: 9 * 60, endMinutes: 18 * 60, isOvernight: false }],
    };
  }

  return {
    isClosed: false,
    isOpen24Hours: false,
    windows,
  };
}

export function normalizeOpeningHours(rawHours: any): NormalizedOpeningHours {
  const days: Record<number, DaySchedule> = {
    0: { isClosed: false, isOpen24Hours: true, windows: [{ startMinutes: 0, endMinutes: 1440 }] },
    1: { isClosed: false, isOpen24Hours: true, windows: [{ startMinutes: 0, endMinutes: 1440 }] },
    2: { isClosed: false, isOpen24Hours: true, windows: [{ startMinutes: 0, endMinutes: 1440 }] },
    3: { isClosed: false, isOpen24Hours: true, windows: [{ startMinutes: 0, endMinutes: 1440 }] },
    4: { isClosed: false, isOpen24Hours: true, windows: [{ startMinutes: 0, endMinutes: 1440 }] },
    5: { isClosed: false, isOpen24Hours: true, windows: [{ startMinutes: 0, endMinutes: 1440 }] },
    6: { isClosed: false, isOpen24Hours: true, windows: [{ startMinutes: 0, endMinutes: 1440 }] },
  };

  if (!rawHours || typeof rawHours !== 'object') {
    return createNormalizedResult(days);
  }

  // 1. Google Places `periods` format
  if (Array.isArray(rawHours.periods)) {
    // Reset days to empty windows
    for (let i = 0; i < 7; i++) {
      days[i] = { isClosed: true, isOpen24Hours: false, windows: [] };
    }

    // Check for 24/7 period: single period open at day 0 time "0000" with no close
    if (
      rawHours.periods.length === 1 &&
      rawHours.periods[0]?.open?.day === 0 &&
      rawHours.periods[0]?.open?.time === '0000' &&
      !rawHours.periods[0]?.close
    ) {
      for (let i = 0; i < 7; i++) {
        days[i] = { isClosed: false, isOpen24Hours: true, windows: [{ startMinutes: 0, endMinutes: 1440 }] };
      }
      return createNormalizedResult(days);
    }

    for (const period of rawHours.periods) {
      const openDay = Number(period?.open?.day);
      const openTime = parseTimeToMinutes(String(period?.open?.time ?? ''));
      if (isNaN(openDay) || openTime === null) continue;

      let closeDay = Number(period?.close?.day ?? openDay);
      let closeTime = parseTimeToMinutes(String(period?.close?.time ?? ''));
      if (closeTime === null) closeTime = 1440;

      const isOvernight = closeDay !== openDay || closeTime <= openTime;
      const endMins = isOvernight ? closeTime + 1440 : closeTime;

      days[openDay].isClosed = false;
      days[openDay].windows.push({
        startMinutes: openTime,
        endMinutes: endMins,
        isOvernight,
      });
    }

    return createNormalizedResult(days);
  }

  // 2. Google Places `weekday_text` array format
  if (Array.isArray(rawHours.weekday_text)) {
    for (const text of rawHours.weekday_text) {
      const colonIdx = text.indexOf(':');
      if (colonIdx === -1) continue;
      const dayName = text.substring(0, colonIdx).trim().toLowerCase();
      const hoursText = text.substring(colonIdx + 1).trim();
      const dayIdx = DAY_MAP[dayName];
      if (dayIdx !== undefined) {
        days[dayIdx] = parseDayString(hoursText);
      }
    }
    return createNormalizedResult(days);
  }

  // 3. Firestore format: Record<string, string> e.g. {"mon": "9:00-17:00", "tue": "closed"}
  let hasMatchingDays = false;
  for (const [key, val] of Object.entries(rawHours)) {
    const dayKey = key.trim().toLowerCase();
    const dayIdx = DAY_MAP[dayKey];
    if (dayIdx !== undefined && typeof val === 'string') {
      days[dayIdx] = parseDayString(val);
      hasMatchingDays = true;
    }
  }

  if (!hasMatchingDays) {
    // If rawHours didn't match day names (empty map or unknown keys), default to 24/7 or standard
    return createNormalizedResult(days);
  }

  return createNormalizedResult(days);
}

function createNormalizedResult(days: Record<number, DaySchedule>): NormalizedOpeningHours {
  return {
    days,

    isOpenAt(date: Date | string, hour: number, minute: number = 0): boolean {
      const d = typeof date === 'string' ? new Date(date) : date;
      const targetDay = isNaN(d.getTime()) ? 1 : d.getDay();
      const curMins = Math.max(0, Math.min(23, hour)) * 60 + Math.max(0, Math.min(59, minute));

      // 1. Check current day's regular windows
      const curSchedule = days[targetDay];
      if (curSchedule && !curSchedule.isClosed) {
        if (curSchedule.isOpen24Hours) return true;
        for (const w of curSchedule.windows) {
          if (curMins >= w.startMinutes && curMins < Math.min(1440, w.endMinutes)) {
            return true;
          }
        }
      }

      // 2. Check previous day's overnight spillover windows into the morning of target day
      const prevDay = (targetDay + 6) % 7;
      const prevSchedule = days[prevDay];
      if (prevSchedule && !prevSchedule.isClosed) {
        for (const w of prevSchedule.windows) {
          if (w.isOvernight && w.endMinutes > 1440) {
            const spilloverEnd = w.endMinutes - 1440;
            if (curMins < spilloverEnd) {
              return true;
            }
          }
        }
      }

      return false;
    },

    isOpenSpan(date: Date | string, startMinutes: number, durationMinutes: number): boolean {
      const d = typeof date === 'string' ? new Date(date) : date;
      const targetDay = isNaN(d.getTime()) ? 1 : d.getDay();
      const endMinutes = startMinutes + durationMinutes;

      const curSchedule = days[targetDay];
      if (curSchedule?.isClosed) return false;
      if (curSchedule?.isOpen24Hours) return true;

      // Check if [startMinutes, endMinutes] fits completely inside any active window for today
      for (const w of curSchedule.windows) {
        if (startMinutes >= w.startMinutes && endMinutes <= w.endMinutes) {
          return true;
        }
      }

      // Also check if [startMinutes, endMinutes] fits within previous day's overnight window
      const prevDay = (targetDay + 6) % 7;
      const prevSchedule = days[prevDay];
      if (prevSchedule && !prevSchedule.isClosed) {
        for (const w of prevSchedule.windows) {
          if (w.isOvernight && w.endMinutes > 1440) {
            const spilloverEnd = w.endMinutes - 1440;
            if (startMinutes >= 0 && endMinutes <= spilloverEnd) {
              return true;
            }
          }
        }
      }

      return false;
    },

    getWindowsForDate(date: Date | string): TimeWindow[] {
      const d = typeof date === 'string' ? new Date(date) : date;
      const targetDay = isNaN(d.getTime()) ? 1 : d.getDay();
      const curSchedule = days[targetDay];
      if (!curSchedule || curSchedule.isClosed) return [];
      return curSchedule.windows;
    },
  };
}

