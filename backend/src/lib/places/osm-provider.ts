import { Place } from '../schemas/place';
import { NearbyService } from '../schemas/nearby-service';
import { PlaceDetailsParams, PlaceNearbyParams, PlaceProvider, PlaceSearchParams } from './types';

export class OsmPlaceProvider implements PlaceProvider {
  readonly name = 'osm';
  private overpassUrl = 'https://overpass-api.de/api/interpreter';
  private nominatimUrl = 'https://nominatim.openstreetmap.org/search';
  private userAgent = 'Ghumify-Backend/1.0 (travel-planner; contact@ghumify.app)';
  private lastRequestTime = 0;

  isAvailable(): boolean {
    return true; // Overpass is public and free
  }

  private async enforceRateLimit(): Promise<void> {
    const minInterval = 1000; // 1 second courtesy delay
    const now = Date.now();
    const elapsed = now - this.lastRequestTime;
    if (elapsed < minInterval) {
      await new Promise((r) => setTimeout(r, minInterval - elapsed));
    }
    this.lastRequestTime = Date.now();
  }

  private mapCategory(tags: Record<string, string>): string {
    if (tags['amenity'] === 'place_of_worship' || tags['religion']) {
      return 'temples';
    }
    if (tags['historic'] || tags['tourism'] === 'museum' || tags['tourism'] === 'gallery') {
      return 'heritage';
    }
    if (tags['leisure'] === 'park' || tags['natural'] || tags['leisure'] === 'garden') {
      return 'nature';
    }
    if (tags['amenity'] === 'restaurant' || tags['amenity'] === 'cafe' || tags['amenity'] === 'fast_food') {
      return 'food';
    }
    if (tags['amenity'] === 'marketplace' || tags['shop'] === 'mall') {
      return 'markets';
    }
    if (tags['tourism'] === 'attraction' || tags['tourism'] === 'viewpoint') {
      return 'heritage';
    }
    return 'culture';
  }

  private normalizeElement(el: any, city: string): Place | null {
    const tags = el.tags || {};
    const name = tags['name:en'] || tags['name'];
    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return null;
    }

    const lat = el.type === 'way' && el.center ? el.center.lat : el.lat;
    const lon = el.type === 'way' && el.center ? el.center.lon : el.lon;

    if (!lat || !lon) return null;

    const address = tags['addr:full'] || tags['addr:street']
      ? [tags['addr:housenumber'], tags['addr:street'], tags['addr:city'] || city].filter(Boolean).join(', ')
      : null;

    return {
      id: `osm_${el.type}_${el.id}`,
      name: name.trim(),
      city,
      state: tags['addr:state'] || '',
      category: this.mapCategory(tags),
      description: tags['description'] || tags['historic'] || tags['tourism'] || `Attraction in ${city}`,
      history: tags['description:history'] || '',
      latitude: Number(lat),
      longitude: Number(lon),
      address,
      openingHours: tags['opening_hours'] ? { general: tags['opening_hours'] } : {},
      photoUrls: tags['image'] ? [tags['image']] : [],
      thumbnailUrl: tags['image'] || null,
      avgVisitDurationMinutes: 60,
      rating: null,
      reviewCount: null,
      entryFee: null,
      tags: [tags['tourism'], tags['historic'], tags['amenity']].filter(Boolean) as string[],
      nearbyPlaceIds: [],
      googlePlaceId: null,
      isHiddenGem: false,
      specialNote: null,
      createdAt: new Date().toISOString(),
    };
  }

  private async geocodeCity(city: string): Promise<{ lat: number; lon: number } | null> {
    try {
      await this.enforceRateLimit();
      const url = `${this.nominatimUrl}?q=${encodeURIComponent(city)}&format=json&limit=1`;
      const res = await fetch(url, {
        headers: { 'User-Agent': this.userAgent },
        signal: AbortSignal.timeout(8000),
      });
      if (!res.ok) return null;
      const data = await res.json();
      if (!Array.isArray(data) || data.length === 0) return null;
      return { lat: parseFloat(data[0].lat), lon: parseFloat(data[0].lon) };
    } catch {
      return null;
    }
  }

  async search(params: PlaceSearchParams): Promise<Place[]> {
    let lat = params.lat;
    let lon = params.lng;

    if (!lat || !lon) {
      const geo = await this.geocodeCity(params.city);
      if (!geo) throw new Error(`Could not locate city "${params.city}" via OSM.`);
      lat = geo.lat;
      lon = geo.lon;
    }

    const radius = params.radius || 15000;
    const query = `
      [out:json][timeout:15];
      (
        node["tourism"~"attraction|museum|viewpoint"](around:${radius},${lat},${lon});
        node["historic"](around:${radius},${lat},${lon});
        node["amenity"="place_of_worship"](around:${radius},${lat},${lon});
        node["amenity"="marketplace"](around:${radius},${lat},${lon});
        node["amenity"="restaurant"](around:${radius},${lat},${lon});
        way["tourism"~"attraction|museum"](around:${radius},${lat},${lon});
        way["historic"](around:${radius},${lat},${lon});
      );
      out center 40;
    `;

    await this.enforceRateLimit();

    const res = await fetch(this.overpassUrl, {
      method: 'POST',
      headers: {
        'User-Agent': this.userAgent,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: `data=${encodeURIComponent(query)}`,
      signal: AbortSignal.timeout(16000),
    });

    if (!res.ok) throw new Error(`OSM Overpass error: ${res.statusText}`);

    const data = await res.json();
    const elements = Array.isArray(data.elements) ? data.elements : [];

    const places: Place[] = [];
    const seenNames = new Set<string>();

    for (const el of elements) {
      const p = this.normalizeElement(el, params.city);
      if (p && !seenNames.has(p.name.toLowerCase())) {
        seenNames.add(p.name.toLowerCase());
        places.push(p);
      }
    }

    const limit = params.limit || 25;
    return places.slice(0, limit);
  }

  async nearby(params: PlaceNearbyParams): Promise<Place[]> {
    const radius = params.radiusMeters || 5000;
    const query = `
      [out:json][timeout:15];
      (
        node["tourism"](around:${radius},${params.latitude},${params.longitude});
        node["amenity"~"restaurant|cafe"](around:${radius},${params.latitude},${params.longitude});
      );
      out center 30;
    `;

    await this.enforceRateLimit();

    const res = await fetch(this.overpassUrl, {
      method: 'POST',
      headers: {
        'User-Agent': this.userAgent,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: `data=${encodeURIComponent(query)}`,
      signal: AbortSignal.timeout(16000),
    });

    if (!res.ok) throw new Error(`OSM Overpass error: ${res.statusText}`);

    const data = await res.json();
    const elements = Array.isArray(data.elements) ? data.elements : [];
    const places: Place[] = [];
    const seen = new Set<string>();

    for (const el of elements) {
      const p = this.normalizeElement(el, '');
      if (p && !seen.has(p.name.toLowerCase())) {
        seen.add(p.name.toLowerCase());
        places.push(p);
      }
    }
    return places.slice(0, params.limit || 20);
  }

  async details(params: PlaceDetailsParams): Promise<Place | null> {
    // OSM ID format: osm_node_1234 or osm_way_1234
    const parts = params.placeId.replace(/^osm_/, '').split('_');
    if (parts.length < 2) return null;
    const type = parts[0];
    const id = parts[1];

    const query = `[out:json][timeout:10]; ${type}(${id}); out center;`;
    await this.enforceRateLimit();

    const res = await fetch(this.overpassUrl, {
      method: 'POST',
      headers: {
        'User-Agent': this.userAgent,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: `data=${encodeURIComponent(query)}`,
      signal: AbortSignal.timeout(10000),
    });

    if (!res.ok) return null;
    const data = await res.json();
    const el = data.elements?.[0];
    return el ? this.normalizeElement(el, '') : null;
  }

  async searchEmergency(params: PlaceNearbyParams): Promise<NearbyService[]> {
    const radius = params.radiusMeters || 5000;
    const query = `
      [out:json][timeout:12];
      (
        node["amenity"="hospital"](around:${radius},${params.latitude},${params.longitude});
        node["amenity"="clinic"](around:${radius},${params.latitude},${params.longitude});
        node["amenity"="police"](around:${radius},${params.latitude},${params.longitude});
        way["amenity"="hospital"](around:${radius},${params.latitude},${params.longitude});
        way["amenity"="clinic"](around:${radius},${params.latitude},${params.longitude});
        way["amenity"="police"](around:${radius},${params.latitude},${params.longitude});
      );
      out center body;
    `;

    await this.enforceRateLimit();

    const res = await fetch(this.overpassUrl, {
      method: 'POST',
      headers: {
        'User-Agent': this.userAgent,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: `data=${encodeURIComponent(query)}`,
      signal: AbortSignal.timeout(15000),
    });

    if (!res.ok) throw new Error(`OSM Overpass emergency error: ${res.statusText}`);

    const data = await res.json();
    const elements = Array.isArray(data.elements) ? data.elements : [];

    const results: NearbyService[] = [];
    const seen = new Set<string>();

    for (const el of elements) {
      const tags = el.tags || {};
      const name = tags['name:en'] || tags['name'];
      if (!name) continue;
      if (seen.has(name.toLowerCase())) continue;
      seen.add(name.toLowerCase());

      const lat = el.type === 'way' && el.center ? el.center.lat : el.lat;
      const lon = el.type === 'way' && el.center ? el.center.lon : el.lon;
      if (!lat || !lon) continue;

      const amenity = tags['amenity'];
      results.push({
        name,
        type: amenity === 'police' ? 'police' : 'hospital',
        latitude: Number(lat),
        longitude: Number(lon),
        address: tags['addr:full'] || tags['addr:street'] || null,
        distanceKm: null,
      });
    }

    return results;
  }
}

