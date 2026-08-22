import { Itinerary, ItineraryStop, Place, Category, WeatherInfo } from './types';
import { GRADIENTS } from './theme';
import { getPlacesByCity, getPlace } from './data';

// ─── Time helpers ─────────────────────────────────────────────
function timeToMin(t: string): number {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + m;
}

function minToTime(min: number): string {
  const h24 = Math.floor(min / 60) % 24;
  const m = Math.round(min % 60);
  return `${String(h24).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function formatTime(t: string): string {
  const [h, m] = t.split(':').map(Number);
  const period = h >= 12 ? 'PM' : 'AM';
  let h12 = h % 12;
  if (h12 === 0) h12 = 12;
  return `${h12}:${String(m).padStart(2, '0')} ${period}`;
}

function isOpen(place: Place, currentMin: number): boolean {
  const open = timeToMin(place.timings.open);
  let close = timeToMin(place.timings.close);
  // Handles closing past midnight (e.g., 02:00)
  if (close <= open) close += 24 * 60;
  let c = currentMin;
  if (c < open) c += 24 * 60;
  return c >= open && c <= close;
}

function travelMinutes(distanceKm: number): number {
  return Math.max(10, Math.round(distanceKm * 2.5));
}

// ─── Scoring heuristic ────────────────────────────────────────
function scorePlace(place: Place, interests: Category[], weather: WeatherInfo): number {
  let score = place.rating * 10;

  // Boost by category match
  if (interests.includes(place.category)) score += 15;

  // Closer is better (less travel time)
  score += Math.max(0, 20 - place.distanceKm * 0.8);

  // Events are a bonus
  if (place.events && place.events.length > 0) score += 8;

  // In weather-aware mode, prefer indoor places if rain is likely
  if (weather.rainChance > 50 && !place.isOutdoor) score += 10;
  if (weather.rainChance <= 50 && place.isOutdoor) score += 3;

  return score;
}

// ─── Time-of-day fit ──────────────────────────────────────────
function timeFit(place: Place, hour: number): number {
  let fit = 0;
  if (place.category === 'food') {
    if (hour < 11) fit -= 14; // discourage food first thing in the morning
    else if (hour >= 11.5 && hour <= 14) fit += 12; // lunch window
    else if (hour >= 18) fit += 6; // dinner / evening
  }
  if (place.category === 'tourist' || place.category === 'culture') {
    if (hour < 11) fit += 6; // sightseeing is best in the morning
  }
  if (place.category === 'nature') {
    if (hour < 11) fit += 5;
    if (hour >= 17) fit -= 10; // gets dark
  }
  if (place.category === 'market') {
    if (hour >= 17) fit += 10; // markets come alive in the evening
    else if (hour < 12) fit -= 5;
  }
  if (place.category === 'hidden') fit += 2;
  return fit;
}

function bestPick(
  pool: { place: Place; score: number }[],
  usedIds: Set<string>,
  cursor: number,
  maxDuration: number,
  hour: number,
  weather: WeatherInfo,
): { place: Place; score: number } | null {
  let best: { place: Place; score: number } | null = null;
  let bestScore = -Infinity;
  for (const item of pool) {
    if (usedIds.has(item.place.id)) continue;
    if (!isOpen(item.place, cursor)) continue;
    if (item.place.durationMin > maxDuration) continue;
    const dynamic = item.score + timeFit(item.place, hour);
    if (dynamic > bestScore) {
      bestScore = dynamic;
      best = item;
    }
  }
  return best;
}

// ─── Main generator ───────────────────────────────────────────
export function generateItinerary(
  cityId: string,
  cityName: string,
  startTimeStr: string,
  durationHours: number,
  interests: Category[],
  weather: WeatherInfo,
  overridePlaces?: Place[],
): Itinerary {
  const startMin = timeToMin(startTimeStr);
  const totalMin = Math.round(durationHours * 60);
  const endMin = startMin + totalMin;

  let allPlaces = overridePlaces || getPlacesByCity(cityId);

  // If interests are empty, use all categories
  const useInterests = interests.length > 0 ? interests : (['tourist', 'food', 'market', 'culture', 'nature', 'hidden'] as Category[]);

  // Filter & sort by score
  let pool = allPlaces
    .filter((p) => useInterests.includes(p.category))
    .map((p) => ({ place: p, score: scorePlace(p, useInterests, weather) }))
    .sort((a, b) => b.score - a.score);

  const stops: ItineraryStop[] = [];
  let cursor = startMin;
  let prevDistance = 0;
  const usedPlaceIds = new Set<string>();
  let lunchAdded = false;
  let dinnerAdded = false;

  const addStop = (stop: ItineraryStop) => {
    stops.push(stop);
  };

  // Build the timeline
  while (cursor < endMin - 15) {
    const remainingMin = endMin - cursor;

    // ── Lunch break (12:30–14:00) ──
    if (!lunchAdded && cursor >= timeToMin('12:00') && cursor <= timeToMin('14:00')) {
      const lunchFood = pool.find((p) => p.place.category === 'food' && !usedPlaceIds.has(p.place.id));
      const mealMin = 60;
      if (lunchFood && remainingMin >= mealMin) {
        addStop({
          id: `stop-${stops.length}`,
          startTime: minToTime(cursor),
          endTime: minToTime(cursor + mealMin),
          type: 'meal',
          title: lunchFood.place.name,
          subtitle: 'Lunch — try the local specialities',
          placeId: lunchFood.place.id,
          category: 'food',
          durationMin: mealMin,
          gradient: 'sunset',
          icon: 'fast-food',
          note: lunchFood.place.shortDesc,
        });
        usedPlaceIds.add(lunchFood.place.id);
        cursor += mealMin;
        lunchAdded = true;
        continue;
      }
    }

    // ── Dinner break (19:00–21:00) ──
    if (!dinnerAdded && cursor >= timeToMin('18:30') && cursor <= timeToMin('20:30')) {
      const dinnerFood = pool.find((p) => p.place.category === 'food' && !usedPlaceIds.has(p.place.id));
      const mealMin = 75;
      if (dinnerFood && remainingMin >= mealMin) {
        addStop({
          id: `stop-${stops.length}`,
          startTime: minToTime(cursor),
          endTime: minToTime(cursor + mealMin),
          type: 'meal',
          title: dinnerFood.place.name,
          subtitle: 'Dinner — end the day with local flavours',
          placeId: dinnerFood.place.id,
          category: 'food',
          durationMin: mealMin,
          gradient: 'sunset',
          icon: 'fast-food',
          note: dinnerFood.place.shortDesc,
        });
        usedPlaceIds.add(dinnerFood.place.id);
        cursor += mealMin;
        dinnerAdded = true;
        continue;
      }
    }

    // ── Pick the next best place that is open (time-aware) ──
    const hour = cursor / 60; // current hour (0–24)
    const candidate = bestPick(pool, usedPlaceIds, cursor, remainingMin, hour, weather);

    if (!candidate) {
      // Relax the "fits in remaining" constraint
      const fallback = bestPick(pool, usedPlaceIds, cursor, 9999, hour, weather);
      if (fallback) {
        const dur = Math.min(fallback.place.durationMin, remainingMin);
        addStop({
          id: `stop-${stops.length}`,
          startTime: minToTime(cursor),
          endTime: minToTime(cursor + dur),
          type: 'visit',
          title: fallback.place.name,
          subtitle: fallback.place.subcategory,
          placeId: fallback.place.id,
          category: fallback.place.category,
          durationMin: dur,
          gradient: fallback.place.gradient,
          icon: fallback.place.icon,
          note: fallback.place.shortDesc,
        });
        usedPlaceIds.add(fallback.place.id);
        cursor += dur;
        // Add travel time
        const travel = travelMinutes(fallback.place.distanceKm);
        if (cursor + travel <= endMin) {
          addStop({
            id: `stop-${stops.length}`,
            startTime: minToTime(cursor),
            endTime: minToTime(cursor + travel),
            type: 'travel',
            title: 'Travel',
            subtitle: `Head to the next destination`,
            durationMin: travel,
            distanceKm: fallback.place.distanceKm,
            gradient: 'indigo',
            icon: 'navigate',
          });
          cursor += travel;
        }
        continue;
      }

      // Nothing open — add a free-time / rest stop
      if (remainingMin >= 30) {
        addStop({
          id: `stop-${stops.length}`,
          startTime: minToTime(cursor),
          endTime: minToTime(cursor + 30),
          type: 'travel',
          title: 'Break',
          subtitle: 'Rest or explore the surroundings',
          durationMin: 30,
          gradient: 'teal',
          icon: 'cafe',
        });
        cursor += 30;
        continue;
      }
      break;
    }

    // ── Add the visit ──
    const place = candidate.place;
    const dur = Math.min(place.durationMin, remainingMin);
    addStop({
      id: `stop-${stops.length}`,
      startTime: minToTime(cursor),
      endTime: minToTime(cursor + dur),
      type: 'visit',
      title: place.name,
      subtitle: place.subcategory,
      placeId: place.id,
      category: place.category,
      durationMin: dur,
      gradient: place.gradient,
      icon: place.icon,
      note: place.shortDesc,
    });
    usedPlaceIds.add(place.id);
    cursor += dur;

    // ── Special event overlay ──
    if (place.events) {
      for (const ev of place.events) {
        const evMin = timeToMin(ev.time);
        if (evMin >= startMin && evMin <= endMin) {
          addStop({
            id: `stop-${stops.length}`,
            startTime: ev.time,
            endTime: minToTime(evMin + 20),
            type: 'event',
            title: ev.name,
            subtitle: place.name,
            placeId: place.id,
            category: place.category,
            durationMin: 20,
            gradient: place.gradient,
            icon: 'star',
            note: ev.description,
          });
        }
      }
    }

    // ── Travel to next ──
    if (cursor < endMin - 15) {
      const travel = travelMinutes(Math.abs(place.distanceKm - prevDistance));
      const adjusted = Math.max(10, Math.min(travel, 45));
      if (cursor + adjusted <= endMin) {
        addStop({
          id: `stop-${stops.length}`,
          startTime: minToTime(cursor),
          endTime: minToTime(cursor + adjusted),
          type: 'travel',
          title: 'Travel',
          subtitle: 'On the way to the next stop',
          durationMin: adjusted,
          distanceKm: place.distanceKm,
          gradient: 'indigo',
          icon: 'navigate',
        });
        cursor += adjusted;
      }
      prevDistance = place.distanceKm;
    }
  }

  // ── Tips based on weather & context ──
  const tips: string[] = [];
  if (weather.rainChance > 50) {
    tips.push(`High chance of rain (${weather.rainChance}%). Carry an umbrella or raincoat, and outdoor sights are best visited in dry windows.`);
  } else if (weather.rainChance > 25) {
    tips.push(`Possible rain (${weather.rainChance}%). A small umbrella is a good idea.`);
  }
  if (weather.tempC >= 35 || weather.uvIndex >= 8) {
    tips.push(`It will be hot (${weather.tempC}°C, UV ${weather.uvIndex}). Carry water, sunscreen, a cap, and visit outdoor sights in cooler hours.`);
  } else if (weather.tempC <= 15) {
    tips.push(`It may be cool (${weather.tempC}°C). Carry a warm jacket or shawl.`);
  }
  tips.push('Carry a water bottle and stay hydrated throughout the day.');
  tips.push('Wear comfortable walking shoes — you will be on your feet a lot!');
  if (interests.includes('culture') || interests.includes('tourist')) {
    tips.push('Dress modestly when visiting temples and religious sites.');
  }

  // total distance estimate
  const totalDistance = stops
    .filter((s) => s.distanceKm)
    .reduce((sum, s) => sum + (s.distanceKm || 0), 0);

  // Sort stops by start time so events overlay correctly
  stops.sort((a, b) => timeToMin(a.startTime) - timeToMin(b.startTime));

  return {
    cityId,
    cityName,
    date: new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' }),
    startTime: formatTime(minToTime(startMin)),
    endTime: formatTime(minToTime(endMin)),
    stops,
    weather,
    tips,
    totalDistanceKm: Math.round(totalDistance),
  };
}

export { formatTime };
