import { CROWD_CONFIG, RankingWeights } from './config';
import { CalendarContext, estimateCrowd } from './estimate';
import { normalizeOpeningHours } from './normalizeOpeningHours';

export interface CandidatePlace {
  id: string;
  name: string;
  category: string;
  latitude: number;
  longitude: number;
  openingHours?: any;
  entryFee?: number | null;
  rating?: number | null;
  reviewCount?: number | null;
  popularity?: number | null;
  capacity?: string | number | null;
  hourlyProfile?: number[] | null;
  durationMinutes?: number | null;
  hasStatistics?: boolean | null;
  scoreInputs?: {
    interest?: number | null;   // I: 0-100
    budget?: number | null;     // B: 0-100
    foodFamily?: number | null; // F: 0-100
    distance?: number | null;   // Dist: 0-100
    crowd?: number | null;      // C: 0-100
  };
}

export interface RankingContext {
  date: Date | string;
  visitStartHour?: number;
  visitStartMinutes?: number;
  visitDurationMinutes?: number;
  budgetCap?: number | null;
  avoidCrowds?: boolean;
  originCoords?: { latitude: number; longitude: number };
  calendarContext?: CalendarContext;
}

export interface ScoreBreakdown {
  interest: number;
  budget: number;
  foodFamily: number;
  distance: number;
  crowd: number;
  crowdPenaltyTerm: number;
  weights: RankingWeights;
}

export interface RankedCandidate<T extends CandidatePlace = CandidatePlace> {
  candidate: T;
  rankScore: number; // 0-100
  crowdScore: number; // 0-100
  breakdown: ScoreBreakdown;
  filterPass: boolean;
  filterReason?: string;
}

/**
 * Calculates Haversine distance in km between two coordinate pairs
 */
export function calculateHaversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Ranks candidates according to:
 * R = 0.30*I + 0.20*B + 0.15*F + 0.15*Dist + 0.20*(100 - C)
 * 
 * - When avoidCrowds is true: crowd weight is 0.40, other weights rescaled proportionally (total = 1.0).
 * - Hard filters: opening hours, budget cap, closed days.
 * - Missing inputs are neutral (50), never 0.
 */
export function rankCandidates<T extends CandidatePlace = CandidatePlace>(
  candidates: T[],
  context: RankingContext
): { ranked: RankedCandidate<T>[]; rejected: RankedCandidate<T>[] } {
  const avoidCrowds = Boolean(context.avoidCrowds);
  const weights: RankingWeights = avoidCrowds
    ? CROWD_CONFIG.avoidCrowdsWeights
    : CROWD_CONFIG.standardWeights;

  const ranked: RankedCandidate<T>[] = [];
  const rejected: RankedCandidate<T>[] = [];

  const visitHour = context.visitStartHour ?? (
    context.visitStartMinutes !== undefined
      ? Math.floor(context.visitStartMinutes / 60)
      : 12
  );
  const visitStartMins = context.visitStartMinutes ?? (visitHour * 60);
  const visitDurationMins = context.visitDurationMinutes ?? 60;

  for (const candidate of candidates) {
    // -------------------------------------------------------------
    // HARD FILTERS (Opening Hours, Budget Cap, Closed Days)
    // -------------------------------------------------------------
    const hours = normalizeOpeningHours(candidate.openingHours);

    // 1. Closed days filter
    const d = typeof context.date === 'string' ? new Date(context.date) : context.date;
    const dayOfWeek = isNaN(d.getTime()) ? 1 : d.getDay();
    const daySchedule = hours.days[dayOfWeek];

    if (daySchedule && daySchedule.isClosed) {
      rejected.push({
        candidate,
        rankScore: 0,
        crowdScore: 0,
        breakdown: createNeutralBreakdown(weights),
        filterPass: false,
        filterReason: `Place is closed on this day of the week (${dayOfWeek}).`,
      });
      continue;
    }

    // 2. Opening hours window filter
    if (context.visitStartMinutes !== undefined) {
      const isOpen = hours.isOpenSpan(context.date, visitStartMins, visitDurationMins);
      if (!isOpen) {
        rejected.push({
          candidate,
          rankScore: 0,
          crowdScore: 0,
          breakdown: createNeutralBreakdown(weights),
          filterPass: false,
          filterReason: 'Place is not open during the specified visit window.',
        });
        continue;
      }
    }

    // 3. Budget cap filter
    if (context.budgetCap !== undefined && context.budgetCap !== null) {
      const fee = candidate.entryFee ?? 0;
      if (fee > context.budgetCap) {
        rejected.push({
          candidate,
          rankScore: 0,
          crowdScore: 0,
          breakdown: createNeutralBreakdown(weights),
          filterPass: false,
          filterReason: `Entry fee (${fee}) exceeds budget cap (${context.budgetCap}).`,
        });
        continue;
      }
    }

    // -------------------------------------------------------------
    // SCORING (Missing inputs are NEUTRAL 50, never 0)
    // -------------------------------------------------------------
    const interestScore = candidate.scoreInputs?.interest ?? CROWD_CONFIG.neutralScore;
    const budgetScore = candidate.scoreInputs?.budget ?? CROWD_CONFIG.neutralScore;
    const foodFamilyScore = candidate.scoreInputs?.foodFamily ?? CROWD_CONFIG.neutralScore;

    // Distance score: if explicit score given, use it; otherwise compute from origin if available, else 50
    let distanceScore = CROWD_CONFIG.neutralScore;
    if (candidate.scoreInputs?.distance !== undefined && candidate.scoreInputs.distance !== null) {
      distanceScore = candidate.scoreInputs.distance;
    } else if (context.originCoords && candidate.latitude && candidate.longitude) {
      const distKm = calculateHaversineKm(
        context.originCoords.latitude,
        context.originCoords.longitude,
        candidate.latitude,
        candidate.longitude
      );
      // Pruning heuristic: 0 km -> 100 score, 25+ km -> 0 score
      distanceScore = Math.max(0, Math.min(100, Math.round(100 - (distKm / 25) * 100)));
    }

    // Crowd score: use provided or estimate at visit time
    let crowdScore: number;
    if (candidate.scoreInputs?.crowd !== undefined && candidate.scoreInputs.crowd !== null) {
      crowdScore = candidate.scoreInputs.crowd;
    } else {
      const estimate = estimateCrowd(
        candidate,
        context.date,
        visitHour,
        context.calendarContext
      );
      crowdScore = estimate.score;
    }

    // Neutral missing rule: if crowdScore cannot be computed, default to neutral 50
    if (isNaN(crowdScore)) crowdScore = CROWD_CONFIG.neutralScore;

    // Crowd penalty term: (100 - C)
    const crowdPenaltyTerm = 100 - crowdScore;

    // Weighted composite score:
    // R = w_I * I + w_B * B + w_F * F + w_Dist * Dist + w_Crowd * (100 - C)
    const rawRankScore =
      weights.interest * interestScore +
      weights.budget * budgetScore +
      weights.foodFamily * foodFamilyScore +
      weights.distance * distanceScore +
      weights.crowdPenalty * crowdPenaltyTerm;

    const rankScore = Math.max(0, Math.min(100, Math.round(rawRankScore * 10) / 10));

    ranked.push({
      candidate,
      rankScore,
      crowdScore,
      filterPass: true,
      breakdown: {
        interest: interestScore,
        budget: budgetScore,
        foodFamily: foodFamilyScore,
        distance: distanceScore,
        crowd: crowdScore,
        crowdPenaltyTerm,
        weights,
      },
    });
  }

  // Sort ranked candidates descending by final rankScore
  ranked.sort((a, b) => b.rankScore - a.rankScore);

  return { ranked, rejected };
}

function createNeutralBreakdown(weights: RankingWeights): ScoreBreakdown {
  return {
    interest: CROWD_CONFIG.neutralScore,
    budget: CROWD_CONFIG.neutralScore,
    foodFamily: CROWD_CONFIG.neutralScore,
    distance: CROWD_CONFIG.neutralScore,
    crowd: CROWD_CONFIG.neutralScore,
    crowdPenaltyTerm: 100 - CROWD_CONFIG.neutralScore,
    weights,
  };
}

