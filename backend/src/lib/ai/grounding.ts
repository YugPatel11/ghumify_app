import { Place } from '../schemas/place';
import { ItineraryStop } from '../schemas/itinerary';
import { haversineKm } from '../planner/rule-planner';

export function buildGroundedPlacesSection(candidates: Place[]): string {
  if (!candidates || candidates.length === 0) return '';

  const placesList = candidates
    .map(
      (p) =>
        `- [id: "${p.id}"] ${p.name} (${p.category}) at [${p.latitude.toFixed(4)}, ${p.longitude.toFixed(4)}]${
          p.rating ? ` Rating: ${p.rating}` : ''
        }${p.address ? ` Address: ${p.address}` : ''}`
    )
    .join('\n');

  return `
ALLOWED REAL PLACES (CRITICAL REQUIREMENT):
You MUST ONLY select, sequence, and describe places from the following list.
You MUST NOT invent, hallucinate, or recommend any place, attraction, or restaurant outside this list.
For every stop, you MUST include the matching "placeId", and exact "latitude" and "longitude" from this list:

${placesList}
`;
}

export function verifyStopsGrounded(
  stops: ItineraryStop[],
  candidates: Place[]
): { valid: boolean; inventedStops: string[] } {
  const inventedStops: string[] = [];

  for (const stop of stops) {
    // Breaks or generic transit connections don't represent destinations
    if (stop.type === 'travel' || stop.type === 'break') {
      continue;
    }

    let matched = false;

    // 1. Check placeId exact match
    if (stop.placeId) {
      const matchById = candidates.find(
        (c) => c.id === stop.placeId || (c.googlePlaceId && c.googlePlaceId === stop.placeId)
      );
      if (matchById) {
        matched = true;
      }
    }

    // 2. Check name similarity + coordinate proximity
    if (!matched) {
      const stopNameLower = stop.name.toLowerCase().trim();
      for (const c of candidates) {
        const candidateNameLower = c.name.toLowerCase().trim();
        const nameMatch =
          stopNameLower === candidateNameLower ||
          stopNameLower.includes(candidateNameLower) ||
          candidateNameLower.includes(stopNameLower);

        if (nameMatch) {
          if (stop.latitude && stop.longitude && c.latitude && c.longitude) {
            const dist = haversineKm(stop.latitude, stop.longitude, c.latitude, c.longitude);
            if (dist <= 2.0) {
              matched = true;
              break;
            }
          } else {
            matched = true;
            break;
          }
        }
      }
    }

    if (!matched) {
      inventedStops.push(stop.name);
    }
  }

  return {
    valid: inventedStops.length === 0,
    inventedStops,
  };
}

