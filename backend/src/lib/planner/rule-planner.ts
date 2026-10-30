import { Place } from '../schemas/place';
import { ExpenseSummary, ItineraryModel, ItineraryStop } from '../schemas/itinerary';
import { MultiDayItineraryModel } from '../schemas/multi-day-itinerary';

export interface PlanOptions {
  city: string;
  date?: string;
  startDate?: string;
  endDate?: string;
  numberOfDays?: number;
  startTime: string; // "HH:MM"
  endTime: string;   // "HH:MM"
  interests: string[];
  travelMode: string; // driving, walking, transit
  pace: string;       // relaxed, moderate, fast
  age?: number | null;
  travelers?: number | null;
  budget?: number | null;
  userId?: string;
}

// Haversine distance in km
export function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in km
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

// Estimate travel minutes based on mode and distance
export function estimateTravelMinutes(distKm: number, mode: string): number {
  if (distKm <= 0.1) return 5;
  switch (mode.toLowerCase()) {
    case 'walking':
      return Math.round((distKm / 4.5) * 60);
    case 'transit':
      return Math.round((distKm / 18) * 60) + 8; // transit wait buffer
    case 'driving':
    default:
      return Math.round((distKm / 25) * 60) + 5; // city traffic buffer
  }
}

// Convert "HH:MM" to minutes from midnight
export function timeToMinutes(t: string): number {
  const parts = t.split(':');
  if (parts.length < 2) return 540; // 09:00 default
  return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
}

// Convert minutes from midnight to "HH:MM"
export function minutesToTime(m: number): string {
  const normalized = Math.max(0, Math.min(1439, Math.round(m)));
  const hrs = Math.floor(normalized / 60);
  const mins = normalized % 60;
  return `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`;
}

export class RuleBasedPlanner {
  private getPaceMultiplier(pace: string): number {
    switch (pace.toLowerCase()) {
      case 'relaxed':
        return 1.3;
      case 'fast':
        return 0.75;
      case 'moderate':
      default:
        return 1.0;
    }
  }

  private estimateCost(category: string): number {
    switch (category) {
      case 'food':
        return 300;
      case 'heritage':
      case 'temples':
        return 150;
      case 'markets':
        return 200;
      case 'nature':
        return 80;
      default:
        return 120;
    }
  }

  // Hard filter candidates
  private hardFilter(candidates: Place[], city: string): Place[] {
    const seenNames = new Set<string>();
    const filtered: Place[] = [];

    for (const c of candidates) {
      if (!c.name || c.latitude === 0 || c.longitude === 0) continue;
      const normalizedName = c.name.toLowerCase().trim();
      if (seenNames.has(normalizedName)) continue;
      seenNames.add(normalizedName);
      filtered.push(c);
    }
    return filtered;
  }

  // Score candidate
  private scoreCandidate(place: Place, interests: string[]): number {
    let score = 50; // base score

    // Interest match
    const lowerInterests = interests.map((i) => i.toLowerCase());
    const cat = place.category.toLowerCase();
    if (lowerInterests.some((i) => i.includes(cat) || cat.includes(i))) {
      score += 40;
    }
    for (const tag of place.tags) {
      if (lowerInterests.some((i) => tag.toLowerCase().includes(i))) {
        score += 15;
      }
    }

    // Popularity via rating & review count (neutral if missing)
    if (typeof place.rating === 'number') {
      score += (place.rating - 3) * 10; // 5.0 -> +20, 3.0 -> 0
    }
    if (typeof place.reviewCount === 'number') {
      score += Math.min(15, Math.log10(place.reviewCount + 1) * 5);
    }

    return score;
  }

  // Plan single day
  planSingleDay(candidates: Place[], options: PlanOptions): ItineraryModel {
    const city = options.city;
    const cleanCandidates = this.hardFilter(candidates, city);
    const startMins = timeToMinutes(options.startTime);
    const endMins = timeToMinutes(options.endTime);
    const totalAvailMins = Math.max(120, endMins - startMins);
    const paceFactor = this.getPaceMultiplier(options.pace);

    // Separate food candidates from attractions
    const foodCandidates = cleanCandidates.filter((c) => c.category === 'food');
    const attractionCandidates = cleanCandidates.filter((c) => c.category !== 'food');

    // Score attractions
    const scored = attractionCandidates
      .map((place) => ({ place, score: this.scoreCandidate(place, options.interests) }))
      .sort((a, b) => b.score - a.score);

    // Pick stops using nearest neighbor
    const selectedStops: ItineraryStop[] = [];
    let currentMins = startMins;
    let currentLat: number | null = null;
    let currentLon: number | null = null;
    const unvisited = [...scored];
    let foodUsedIndex = 0;
    let hasLunch = false;

    while (unvisited.length > 0 && currentMins + 45 <= endMins) {
      // Check if it's lunch time (between 12:30 and 14:00)
      if (!hasLunch && currentMins >= 12 * 60 + 30 && currentMins <= 14 * 60) {
        let lunchSpot = foodCandidates[foodUsedIndex++];
        if (lunchSpot) {
          const travelMins = currentLat && currentLon
            ? estimateTravelMinutes(haversineKm(currentLat, currentLon, lunchSpot.latitude, lunchSpot.longitude), options.travelMode)
            : 10;
          currentMins += travelMins;
          const stayMins = 50;
          const stopEnd = currentMins + stayMins;
          selectedStops.push({
            name: lunchSpot.name,
            type: 'food',
            placeId: lunchSpot.id,
            startTime: minutesToTime(currentMins),
            endTime: minutesToTime(stopEnd),
            durationMinutes: stayMins,
            latitude: lunchSpot.latitude,
            longitude: lunchSpot.longitude,
            description: lunchSpot.description || `Local dining break in ${city}`,
            photoUrl: lunchSpot.thumbnailUrl || null,
            travelMode: options.travelMode,
            travelMinutes: travelMins,
            tips: ['Enjoy famous local specialties.'],
            estimatedCost: this.estimateCost('food'),
          });
          currentMins = stopEnd;
          currentLat = lunchSpot.latitude;
          currentLon = lunchSpot.longitude;
          hasLunch = true;
          continue;
        }
      }

      // Find nearest neighbor
      let nextIndex = 0;
      let minDistance = Infinity;

      if (currentLat !== null && currentLon !== null) {
        for (let i = 0; i < unvisited.length; i++) {
          const p = unvisited[i].place;
          const dist = haversineKm(currentLat, currentLon, p.latitude, p.longitude);
          // Balance distance and score
          const costFactor = dist - unvisited[i].score * 0.05;
          if (costFactor < minDistance) {
            minDistance = costFactor;
            nextIndex = i;
          }
        }
      }

      const nextTarget = unvisited.splice(nextIndex, 1)[0].place;
      const dist = currentLat !== null && currentLon !== null
        ? haversineKm(currentLat, currentLon, nextTarget.latitude, nextTarget.longitude)
        : 0;
      const travelMins = currentLat !== null ? estimateTravelMinutes(dist, options.travelMode) : 0;

      const stayDuration = Math.round((nextTarget.avgVisitDurationMinutes || 60) * paceFactor);

      if (currentMins + travelMins + stayDuration > endMins + 15 && selectedStops.length >= 2) {
        break; // Out of time
      }

      currentMins += travelMins;
      const stopEnd = currentMins + stayDuration;

      selectedStops.push({
        name: nextTarget.name,
        type: nextTarget.category === 'markets' ? 'market' : 'place',
        placeId: nextTarget.id,
        startTime: minutesToTime(currentMins),
        endTime: minutesToTime(stopEnd),
        durationMinutes: stayDuration,
        latitude: nextTarget.latitude,
        longitude: nextTarget.longitude,
        description: nextTarget.description || `Explore ${nextTarget.name}`,
        photoUrl: nextTarget.thumbnailUrl || (nextTarget.photoUrls[0] ?? null),
        travelMode: options.travelMode,
        travelMinutes: travelMins,
        tips: nextTarget.specialNote ? [nextTarget.specialNote] : ['Respect local visitor guidelines.'],
        estimatedCost: this.estimateCost(nextTarget.category),
      });

      currentMins = stopEnd;
      currentLat = nextTarget.latitude;
      currentLon = nextTarget.longitude;
    }

    // Expense summary
    let foodCost = 0;
    let transportCost = Math.round(selectedStops.length * 75);
    let activitiesCost = 0;
    for (const s of selectedStops) {
      if (s.type === 'food') foodCost += s.estimatedCost || 300;
      else activitiesCost += s.estimatedCost || 150;
    }
    const totalCost = foodCost + transportCost + activitiesCost;
    const expenseSummary: ExpenseSummary = {
      food: foodCost,
      transport: transportCost,
      activities: activitiesCost,
      other: 100,
      total: totalCost + 100,
    };

    const remainingBudget = options.budget && options.budget > 0
      ? options.budget - expenseSummary.total
      : null;

    return {
      id: `itinerary_${Date.now()}`,
      userId: options.userId || 'user_demo',
      city,
      date: options.date || new Date().toISOString().split('T')[0],
      startTime: options.startTime,
      endTime: options.endTime,
      totalDurationMinutes: totalAvailMins,
      interests: options.interests,
      travelMode: options.travelMode,
      pace: options.pace,
      stops: selectedStops,
      weatherSummary: `Clear conditions planned for ${city}.`,
      whatToCarry: [
        '📱 Fully charged smartphone',
        '💧 Drinking water bottle',
        '💵 Cash for entry fees and local food',
        '🧢 Sun protection',
        '🎒 Comfortable backpack',
      ],
      aiSummary: `Curated ${options.pace} plan exploring top attractions and food in ${city}.`,
      isSaved: false,
      dayNumber: 1,
      createdAt: new Date().toISOString(),
      age: options.age,
      travelers: options.travelers || 1,
      budget: options.budget,
      currency: 'INR',
      estimatedTotalCost: expenseSummary.total,
      remainingBudget,
      expenseSummary,
    };
  }

  // Plan multi-day
  planMultiDay(candidates: Place[], options: PlanOptions): MultiDayItineraryModel {
    const numDays = Math.max(1, options.numberOfDays || 2);
    const cleanCandidates = this.hardFilter(candidates, options.city);

    // Geographically cluster candidates into numDays
    const sorted = [...cleanCandidates].sort((a, b) => a.latitude - b.latitude || a.longitude - b.longitude);
    const clusterSize = Math.ceil(sorted.length / numDays);

    const days: ItineraryModel[] = [];
    const startDate = options.startDate ? new Date(options.startDate) : new Date();

    let totalTripCost = 0;
    let totalFood = 0;
    let totalTransport = 0;
    let totalActivities = 0;
    let totalOther = 0;

    for (let d = 0; d < numDays; d++) {
      const daySlice = sorted.slice(d * clusterSize, (d + 1) * clusterSize);
      // Ensure we have candidates for this day
      const dayCandidates = daySlice.length >= 3 ? daySlice : cleanCandidates;

      const currentDate = new Date(startDate.getTime() + d * 86400000).toISOString().split('T')[0];

      const dayPlan = this.planSingleDay(dayCandidates, {
        ...options,
        date: currentDate,
        startTime: options.startTime,
        endTime: options.endTime,
        budget: options.budget ? Math.round(options.budget / numDays) : null,
      });

      const adjustedDay: ItineraryModel = {
        ...dayPlan,
        id: `itinerary_${Date.now()}_day${d + 1}`,
        dayNumber: d + 1,
        date: currentDate,
        aiSummary: `Day ${d + 1}: Highlights of ${options.city} curated for ${options.pace} pace.`,
      };

      days.push(adjustedDay);

      if (adjustedDay.expenseSummary) {
        totalFood += adjustedDay.expenseSummary.food;
        totalTransport += adjustedDay.expenseSummary.transport;
        totalActivities += adjustedDay.expenseSummary.activities;
        totalOther += adjustedDay.expenseSummary.other;
        totalTripCost += adjustedDay.expenseSummary.total;
      }
    }

    const overallExpenseSummary: ExpenseSummary = {
      food: totalFood,
      transport: totalTransport,
      activities: totalActivities,
      other: totalOther,
      total: totalTripCost,
    };

    return {
      id: `multiday_${Date.now()}`,
      userId: options.userId || 'user_demo',
      city: options.city,
      startDate: options.startDate || new Date().toISOString().split('T')[0],
      endDate: options.endDate || new Date().toISOString().split('T')[0],
      numberOfDays: numDays,
      dailyStartTime: options.startTime,
      dailyEndTime: options.endTime,
      interests: options.interests,
      travelMode: options.travelMode,
      pace: options.pace,
      days,
      overallSummary: `${numDays}-day complete travel itinerary for ${options.city}.`,
      weatherSummary: `Pleasant travel weather anticipated across ${numDays} days in ${options.city}.`,
      whatToCarry: [
        '📱 Fully charged phone & powerbank',
        '💧 Reusable water bottle',
        '💵 Cash & cards',
        '👟 Comfortable walking shoes',
        '🧴 Sunscreen & basic medications',
      ],
      isSaved: false,
      createdAt: new Date().toISOString(),
      age: options.age,
      travelers: options.travelers || 1,
      budget: options.budget,
      currency: 'INR',
      estimatedTotalCost: totalTripCost,
      remainingBudget: options.budget ? options.budget - totalTripCost : null,
      overallExpenseSummary,
    };
  }
}

export const rulePlanner = new RuleBasedPlanner();

