/**
 * Central Configuration for Ghumify Crowd-Aware Recommendation Engine
 * All weights, factors, category default hourly profiles, and level thresholds live here.
 */

export type CrowdLevel = 'low' | 'moderate' | 'busy' | 'very_busy';
export type CrowdConfidence = 'low' | 'medium';

export interface CrowdLevelThreshold {
  min: number;
  max: number;
  level: CrowdLevel;
  label: string;
}

export interface RankingWeights {
  interest: number;       // I: User interest match
  budget: number;         // B: Budget fit
  foodFamily: number;     // F: Dietary & family suitability
  distance: number;       // Dist: Proximity / travel efficiency
  crowdPenalty: number;   // (100 - C): Low crowd preference
}

export const CROWD_CONFIG = {
  // 1. Level thresholds: 0-30 Low, 31-50 Moderate, 51-75 Busy, 76-100 Very Busy
  levels: [
    { min: 0, max: 30, level: 'low' as CrowdLevel, label: 'Low' },
    { min: 31, max: 50, level: 'moderate' as CrowdLevel, label: 'Moderate' },
    { min: 51, max: 75, level: 'busy' as CrowdLevel, label: 'Busy' },
    { min: 76, max: 100, level: 'very_busy' as CrowdLevel, label: 'Very Busy' },
  ],

  // 2. Base Crowd Calculation
  base: {
    defaultPopularity: 50,
    capacityMultipliers: {
      small: 1.25,
      medium: 1.0,
      large: 0.8,
    } as Record<string, number>,
  },

  // 3. Category Default 24-Hour Profiles (Hours 0 through 23)
  // Reflects typical Indian city crowd distributions
  categoryHourlyProfiles: {
    // Dawn (5-7 AM) + Evening (17-20 PM) aarti/darshan peaks
    temple: [
      0.1, 0.1, 0.1, 0.1, 0.3, 1.4, 1.6, 1.4, 1.0, 0.9, 0.8, 0.6,
      0.5, 0.4, 0.4, 0.7, 1.2, 1.6, 1.8, 1.6, 1.0, 0.5, 0.2, 0.1
    ],
    // Forts / Monuments / Museums: Late morning to afternoon peaks (10-15 PM)
    fort: [
      0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.2, 0.3, 0.6, 1.0, 1.5, 1.7,
      1.6, 1.5, 1.5, 1.4, 1.1, 0.7, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1
    ],
    heritage: [
      0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.2, 0.3, 0.6, 1.0, 1.5, 1.7,
      1.6, 1.5, 1.5, 1.4, 1.1, 0.7, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1
    ],
    // Markets / Bazaars: Evening rush peaks (17-21 PM)
    market: [
      0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.2, 0.3, 0.6, 0.8, 0.9,
      1.0, 0.9, 0.8, 1.0, 1.3, 1.7, 1.9, 1.9, 1.7, 1.1, 0.4, 0.2
    ],
    // Food Streets & Restaurants: Lunch (12-14) + Evening/Night (19-22 PM) peaks
    food: [
      0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.2, 0.5, 0.7, 0.8, 0.9, 1.1,
      1.6, 1.6, 1.1, 0.7, 0.7, 0.9, 1.3, 1.8, 2.0, 1.8, 1.2, 0.4
    ],
    // Nature, Parks, Lakes: Morning (6-9 AM) & Late Afternoon (16-18 PM) sunset
    nature: [
      0.1, 0.1, 0.1, 0.1, 0.2, 0.7, 1.5, 1.7, 1.4, 0.9, 0.6, 0.4,
      0.4, 0.3, 0.4, 0.7, 1.3, 1.7, 1.6, 1.0, 0.5, 0.2, 0.1, 0.1
    ],
    // Culture & Galleries
    culture: [
      0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.2, 0.4, 0.8, 1.2, 1.3,
      1.3, 1.2, 1.2, 1.3, 1.4, 1.2, 0.9, 0.5, 0.2, 0.1, 0.1, 0.1
    ],
    // Generic Default Fallback
    default: [
      0.2, 0.2, 0.2, 0.2, 0.2, 0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 1.3,
      1.3, 1.2, 1.2, 1.2, 1.4, 1.5, 1.5, 1.4, 1.1, 0.7, 0.4, 0.2
    ],
  } as Record<string, number[]>,

  // 4. Day of Week Multipliers (0 = Sun, 1 = Mon ... 6 = Sat)
  dayFactors: {
    0: 1.35, // Sunday peak
    1: 0.85, // Monday quiet
    2: 0.85, // Tuesday quiet
    3: 0.90, // Wednesday
    4: 0.95, // Thursday
    5: 1.10, // Friday evening buildup
    6: 1.30, // Saturday busy
  } as Record<number, number>,

  // 5. Environmental Multipliers
  holidayFactor: 1.40,
  eventFactor: 1.45,
  seasonFactors: {
    peak: 1.30,
    regular: 1.00,
    offPeak: 0.75,
  },

  // 6. Ranking Weights
  // Standard: R = 0.30*I + 0.20*B + 0.15*F + 0.15*Dist + 0.20*(100 - C)
  standardWeights: {
    interest: 0.30,
    budget: 0.20,
    foodFamily: 0.15,
    distance: 0.15,
    crowdPenalty: 0.20,
  } as RankingWeights,

  // Avoid Crowds: Crowd weight = 0.40, remaining weights rescaled proportionally (total = 1.0)
  avoidCrowdsWeights: {
    interest: 0.225,     // 0.30 * 0.75
    budget: 0.150,       // 0.20 * 0.75
    foodFamily: 0.1125,  // 0.15 * 0.75
    distance: 0.1125,    // 0.15 * 0.75
    crowdPenalty: 0.400, // 0.40
  } as RankingWeights,

  // Neutral score for missing input metrics (never 0)
  neutralScore: 50,
};

/**
 * Maps a score (0-100) to its corresponding CrowdLevel
 */
export function getCrowdLevel(score: number): CrowdLevel {
  const clamped = Math.max(0, Math.min(100, Math.round(score)));
  for (const threshold of CROWD_CONFIG.levels) {
    if (clamped >= threshold.min && clamped <= threshold.max) {
      return threshold.level;
    }
  }
  return clamped <= 30 ? 'low' : 'very_busy';
}

/**
 * Returns the hourly profile for a given category with fallback to default
 */
export function getCategoryHourlyProfile(category?: string | null): number[] {
  if (!category) return CROWD_CONFIG.categoryHourlyProfiles.default;
  const normalized = category.trim().toLowerCase();
  
  if (normalized.includes('temple') || normalized.includes('worship') || normalized.includes('church') || normalized.includes('mosque')) {
    return CROWD_CONFIG.categoryHourlyProfiles.temple;
  }
  if (normalized.includes('fort') || normalized.includes('monument') || normalized.includes('palace')) {
    return CROWD_CONFIG.categoryHourlyProfiles.fort;
  }
  if (normalized.includes('heritage') || normalized.includes('museum')) {
    return CROWD_CONFIG.categoryHourlyProfiles.heritage;
  }
  if (normalized.includes('market') || normalized.includes('bazaar') || normalized.includes('mall') || normalized.includes('shop')) {
    return CROWD_CONFIG.categoryHourlyProfiles.market;
  }
  if (normalized.includes('food') || normalized.includes('restaurant') || normalized.includes('cafe') || normalized.includes('dining')) {
    return CROWD_CONFIG.categoryHourlyProfiles.food;
  }
  if (normalized.includes('nature') || normalized.includes('park') || normalized.includes('lake') || normalized.includes('garden')) {
    return CROWD_CONFIG.categoryHourlyProfiles.nature;
  }
  if (normalized.includes('culture') || normalized.includes('art') || normalized.includes('craft')) {
    return CROWD_CONFIG.categoryHourlyProfiles.culture;
  }

  return CROWD_CONFIG.categoryHourlyProfiles.default;
}

/**
 * Computes base crowd (0-100) from popularity and capacity
 */
export function computeBaseCrowd(popularity?: number | null, capacity?: string | number | null): number {
  const pop = typeof popularity === 'number' && !isNaN(popularity)
    ? Math.max(0, Math.min(100, popularity))
    : CROWD_CONFIG.base.defaultPopularity;

  let capMult = 1.0;
  if (typeof capacity === 'string') {
    capMult = CROWD_CONFIG.base.capacityMultipliers[capacity.toLowerCase()] ?? 1.0;
  } else if (typeof capacity === 'number') {
    if (capacity < 50) capMult = 1.25;
    else if (capacity > 500) capMult = 0.8;
  }

  return Math.max(10, Math.min(90, Math.round(pop * capMult)));
}

