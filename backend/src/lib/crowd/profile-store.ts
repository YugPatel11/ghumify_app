import { CROWD_CONFIG, CrowdConfidence, getCategoryHourlyProfile } from './config';

export interface CrowdProfileRecord {
  placeId: string;
  googlePlaceId?: string | null;
  name?: string;
  city?: string;
  category: string;
  capacity: 'small' | 'medium' | 'large' | number;
  hourlyProfile: number[]; // 24 values
  weekendMultiplier: number;
  seasonality: number[]; // 12 values (Jan..Dec)
  confidence: CrowdConfidence;
  updatedAt?: string;
}

export interface HolidayRecord {
  date: string; // "YYYY-MM-DD"
  name: string;
  multiplier: number;
}

/**
 * Built-in Curated Profiles for Jaipur, Delhi, and Agra
 * All marked confidence 'low' as required (curated heuristics, not live statistics)
 */
export const CURATED_CROWD_PROFILES: CrowdProfileRecord[] = [
  // --- JAIPUR ---
  {
    placeId: 'curated_hawa_mahal',
    googlePlaceId: 'ChIJ74-4bSjZOTkRQZf_yF1vXmI',
    name: 'Hawa Mahal',
    city: 'Jaipur',
    category: 'heritage',
    capacity: 'medium',
    hourlyProfile: getCategoryHourlyProfile('heritage'),
    weekendMultiplier: 1.35,
    seasonality: [1.3, 1.3, 1.1, 0.7, 0.6, 0.6, 0.8, 0.9, 1.0, 1.2, 1.3, 1.4],
    confidence: 'low',
  },
  {
    placeId: 'curated_amber_palace',
    googlePlaceId: 'ChIJm74b7H-WbTkRQY86iU88Gis',
    name: 'Amber Palace',
    city: 'Jaipur',
    category: 'fort',
    capacity: 'large',
    hourlyProfile: getCategoryHourlyProfile('fort'),
    weekendMultiplier: 1.40,
    seasonality: [1.4, 1.3, 1.1, 0.6, 0.5, 0.6, 0.9, 1.0, 1.1, 1.3, 1.4, 1.4],
    confidence: 'low',
  },
  {
    placeId: 'curated_city_palace_jaipur',
    googlePlaceId: 'ChIJz2x4WvbbOTkRO942W9s88QY',
    name: 'City Palace Jaipur',
    city: 'Jaipur',
    category: 'heritage',
    capacity: 'medium',
    hourlyProfile: getCategoryHourlyProfile('heritage'),
    weekendMultiplier: 1.30,
    seasonality: [1.3, 1.2, 1.1, 0.7, 0.6, 0.6, 0.8, 0.9, 1.0, 1.2, 1.3, 1.3],
    confidence: 'low',
  },
  {
    placeId: 'johari_bazar',
    name: 'Johari Bazar',
    city: 'Jaipur',
    category: 'market',
    capacity: 'large',
    hourlyProfile: getCategoryHourlyProfile('market'),
    weekendMultiplier: 1.45,
    seasonality: [1.2, 1.2, 1.1, 0.8, 0.7, 0.8, 1.0, 1.1, 1.2, 1.4, 1.5, 1.4],
    confidence: 'low',
  },
  {
    placeId: 'lmb_restaurant',
    name: 'LMB Laxmi Misthan Bhandar',
    city: 'Jaipur',
    category: 'food',
    capacity: 'medium',
    hourlyProfile: getCategoryHourlyProfile('food'),
    weekendMultiplier: 1.40,
    seasonality: [1.2, 1.2, 1.1, 0.9, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.4],
    confidence: 'low',
  },

  // --- NEW DELHI ---
  {
    placeId: 'curated_india_gate',
    googlePlaceId: 'ChIJd8BlQ2BZwokRAFUEab_V51Y',
    name: 'India Gate',
    city: 'New Delhi',
    category: 'heritage',
    capacity: 'large',
    hourlyProfile: [
      0.1, 0.1, 0.1, 0.1, 0.2, 0.6, 1.1, 1.2, 1.0, 0.8, 0.7, 0.6,
      0.6, 0.5, 0.6, 0.9, 1.4, 1.8, 2.0, 2.0, 1.8, 1.4, 0.7, 0.3
    ],
    weekendMultiplier: 1.50,
    seasonality: [1.3, 1.2, 1.0, 0.7, 0.6, 0.6, 0.8, 0.9, 1.0, 1.2, 1.4, 1.4],
    confidence: 'low',
  },
  {
    placeId: 'curated_red_fort',
    googlePlaceId: 'ChIJi8uTrBNuEmsR_542W9s88QY',
    name: 'Red Fort',
    city: 'New Delhi',
    category: 'fort',
    capacity: 'large',
    hourlyProfile: getCategoryHourlyProfile('fort'),
    weekendMultiplier: 1.45,
    seasonality: [1.3, 1.2, 1.0, 0.7, 0.6, 0.6, 0.8, 0.9, 1.0, 1.2, 1.3, 1.4],
    confidence: 'low',
  },
  {
    placeId: 'curated_qutub_minar',
    googlePlaceId: 'ChIJV4r3Wq4bDTkRQ842W9s88QY',
    name: 'Qutub Minar',
    city: 'New Delhi',
    category: 'heritage',
    capacity: 'large',
    hourlyProfile: getCategoryHourlyProfile('heritage'),
    weekendMultiplier: 1.40,
    seasonality: [1.3, 1.2, 1.0, 0.7, 0.6, 0.6, 0.8, 0.9, 1.0, 1.2, 1.3, 1.3],
    confidence: 'low',
  },
  {
    placeId: 'chandni_chowk',
    name: 'Chandni Chowk',
    city: 'New Delhi',
    category: 'market',
    capacity: 'large',
    hourlyProfile: getCategoryHourlyProfile('market'),
    weekendMultiplier: 1.50,
    seasonality: [1.2, 1.2, 1.0, 0.8, 0.7, 0.8, 0.9, 1.1, 1.2, 1.4, 1.4, 1.3],
    confidence: 'low',
  },

  // --- AGRA ---
  {
    placeId: 'curated_taj_mahal',
    googlePlaceId: 'ChIJk7fFf6P-DDkR3FqZ5g42W9s',
    name: 'Taj Mahal',
    city: 'Agra',
    category: 'heritage',
    capacity: 'large',
    // Dawn sunrise peak + afternoon sunset rush
    hourlyProfile: [
      0.1, 0.1, 0.1, 0.1, 0.2, 1.4, 1.8, 1.6, 1.3, 1.2, 1.3, 1.4,
      1.4, 1.3, 1.3, 1.5, 1.8, 1.7, 1.2, 0.3, 0.1, 0.1, 0.1, 0.1
    ],
    weekendMultiplier: 1.45,
    seasonality: [1.4, 1.3, 1.1, 0.7, 0.6, 0.6, 0.8, 0.9, 1.1, 1.3, 1.4, 1.5],
    confidence: 'low',
  },
  {
    placeId: 'agra_fort',
    googlePlaceId: 'ChIJ5z-Z9X_4DDkR5FqZ5g42W9s',
    name: 'Agra Fort',
    city: 'Agra',
    category: 'fort',
    capacity: 'large',
    hourlyProfile: getCategoryHourlyProfile('fort'),
    weekendMultiplier: 1.35,
    seasonality: [1.3, 1.3, 1.1, 0.7, 0.6, 0.6, 0.8, 0.9, 1.0, 1.2, 1.3, 1.4],
    confidence: 'low',
  },
];

/**
 * Common Public / National Holidays in India
 */
export const DEFAULT_HOLIDAYS: HolidayRecord[] = [
  { date: '2026-01-26', name: 'Republic Day', multiplier: 1.40 },
  { date: '2026-03-25', name: 'Holi', multiplier: 1.45 },
  { date: '2026-08-15', name: 'Independence Day', multiplier: 1.40 },
  { date: '2026-10-02', name: 'Gandhi Jayanti', multiplier: 1.35 },
  { date: '2026-11-08', name: 'Diwali', multiplier: 1.50 },
  { date: '2026-12-25', name: 'Christmas', multiplier: 1.35 },
];

/**
 * Resolves a crowd profile for a place by ID, googlePlaceId, or category default
 */
export function resolveCrowdProfile(params: {
  placeId?: string;
  googlePlaceId?: string | null;
  category?: string;
}): CrowdProfileRecord {
  // 1. Try finding in curated list by placeId
  if (params.placeId) {
    const match = CURATED_CROWD_PROFILES.find(
      (p) => p.placeId === params.placeId || (p.googlePlaceId && p.googlePlaceId === params.placeId)
    );
    if (match) return match;
  }

  // 2. Try finding by googlePlaceId
  if (params.googlePlaceId) {
    const match = CURATED_CROWD_PROFILES.find(
      (p) => p.googlePlaceId === params.googlePlaceId || p.placeId === params.googlePlaceId
    );
    if (match) return match;
  }

  // 3. Fallback to category default profile
  const category = params.category || 'heritage';
  return {
    placeId: params.placeId || `auto_${Math.random().toString(36).substring(2, 9)}`,
    googlePlaceId: params.googlePlaceId ?? null,
    category,
    capacity: 'medium',
    hourlyProfile: getCategoryHourlyProfile(category),
    weekendMultiplier: 1.30,
    seasonality: [1.2, 1.2, 1.0, 0.8, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.3],
    confidence: 'low',
  };
}

/**
 * Checks if a specific date is a configured holiday
 */
export function getHolidayForDate(dateStr: string): HolidayRecord | null {
  const normalized = dateStr.trim().split('T')[0];
  return DEFAULT_HOLIDAYS.find((h) => h.date === normalized) || null;
}

