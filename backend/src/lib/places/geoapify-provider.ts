import { Place } from '../schemas/place';
import { NearbyService } from '../schemas/nearby-service';
import { PlaceDetailsParams, PlaceNearbyParams, PlaceProvider, PlaceSearchParams } from './types';

export class GeoapifyPlaceProvider implements PlaceProvider {
  readonly name = 'geoapify';
  private apiKey: string;

  constructor() {
    this.apiKey = process.env.GEOAPIFY_API_KEY || '';
  }

  isAvailable(): boolean {
    return Boolean(this.apiKey && this.apiKey.length > 5 && !this.apiKey.startsWith('YOUR_'));
  }

  private mapCategory(categories: string[] = []): string {
    const str = categories.join(' ').toLowerCase();
    if (str.includes('religion') || str.includes('place_of_worship') || str.includes('temple')) {
      return 'temples';
    }
    if (str.includes('heritage') || str.includes('historic') || str.includes('museum') || str.includes('attraction')) {
      return 'heritage';
    }
    if (str.includes('natural') || str.includes('park') || str.includes('garden')) {
      return 'nature';
    }
    if (str.includes('catering') || str.includes('restaurant') || str.includes('cafe')) {
      return 'food';
    }
    if (str.includes('commercial') || str.includes('marketplace') || str.includes('shopping')) {
      return 'markets';
    }
    return 'culture';
  }

  private normalizePlace(feature: any, city: string): Place {
    const props = feature.properties || {};
    const coords = feature.geometry?.coordinates || [0, 0];
    const lon = typeof coords[0] === 'number' ? coords[0] : 0;
    const lat = typeof coords[1] === 'number' ? coords[1] : 0;

    return {
      id: props.place_id ? `geoapify_${props.place_id}` : `geoapify_${lat}_${lon}`,
      name: props.name || props.formatted || 'Attraction',
      city: props.city || city,
      state: props.state || '',
      category: this.mapCategory(props.categories),
      description: props.formatted || props.address_line2 || '',
      history: '',
      latitude: lat,
      longitude: lon,
      address: props.formatted || props.address_line1 || null,
      openingHours: {},
      photoUrls: [],
      thumbnailUrl: null,
      avgVisitDurationMinutes: 60,
      rating: null,
      reviewCount: null,
      entryFee: null,
      tags: Array.isArray(props.categories) ? props.categories.slice(0, 5) : [],
      nearbyPlaceIds: [],
      googlePlaceId: null,
      isHiddenGem: false,
      specialNote: null,
      createdAt: new Date().toISOString(),
    };
  }

  private async geocodeCity(city: string): Promise<{ lat: number; lon: number } | null> {
    try {
      const url = `https://api.geoapify.com/v1/geocode/search?text=${encodeURIComponent(city)}&limit=1&apiKey=${this.apiKey}`;
      const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
      if (!res.ok) return null;
      const data = await res.json();
      const feature = data.features?.[0];
      if (!feature) return null;
      const coords = feature.geometry?.coordinates;
      return { lon: coords[0], lat: coords[1] };
    } catch {
      return null;
    }
  }

  async search(params: PlaceSearchParams): Promise<Place[]> {
    if (!this.isAvailable()) throw new Error('Geoapify API key is not configured.');

    let lat = params.lat;
    let lon = params.lng;

    if (!lat || !lon) {
      const geo = await this.geocodeCity(params.city);
      if (!geo) throw new Error(`Could not geocode city "${params.city}" on Geoapify.`);
      lat = geo.lat;
      lon = geo.lon;
    }

    const categories = 'tourism.attraction,tourism.sights,heritage,religion.place_of_worship,catering.restaurant,commercial.marketplace';
    const radius = params.radius || 15000;
    const limit = params.limit || 20;

    const url = `https://api.geoapify.com/v2/places?categories=${categories}&filter=circle:${lon},${lat},${radius}&bias=proximity:${lon},${lat}&limit=${limit}&apiKey=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Geoapify places search failed: ${res.statusText}`);

    const data = await res.json();
    const features = Array.isArray(data.features) ? data.features : [];

    return features
      .filter((f: any) => f.properties?.name)
      .map((f: any) => this.normalizePlace(f, params.city));
  }

  async nearby(params: PlaceNearbyParams): Promise<Place[]> {
    if (!this.isAvailable()) throw new Error('Geoapify API key is not configured.');

    const radius = params.radiusMeters || 5000;
    const categories = params.type ? params.type : 'tourism.attraction,catering.restaurant';
    const limit = params.limit || 20;

    const url = `https://api.geoapify.com/v2/places?categories=${categories}&filter=circle:${params.longitude},${params.latitude},${radius}&limit=${limit}&apiKey=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Geoapify nearby failed: ${res.statusText}`);

    const data = await res.json();
    const features = Array.isArray(data.features) ? data.features : [];
    return features.map((f: any) => this.normalizePlace(f, ''));
  }

  async details(params: PlaceDetailsParams): Promise<Place | null> {
    if (!this.isAvailable()) throw new Error('Geoapify API key is not configured.');

    const cleanId = params.placeId.replace(/^geoapify_/, '');
    const url = `https://api.geoapify.com/v2/place-details?id=${encodeURIComponent(cleanId)}&apiKey=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return null;

    const data = await res.json();
    const feature = data.features?.[0];
    return feature ? this.normalizePlace(feature, '') : null;
  }

  async searchEmergency(params: PlaceNearbyParams): Promise<NearbyService[]> {
    if (!this.isAvailable()) throw new Error('Geoapify API key is not configured.');

    const radius = params.radiusMeters || 5000;
    const categories = 'healthcare.hospital,service.police';
    const url = `https://api.geoapify.com/v2/places?categories=${categories}&filter=circle:${params.longitude},${params.latitude},${radius}&limit=${params.limit || 20}&apiKey=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Geoapify emergency search failed: ${res.statusText}`);

    const data = await res.json();
    const features = Array.isArray(data.features) ? data.features : [];

    return features.map((f: any) => {
      const p = f.properties || {};
      const coords = f.geometry?.coordinates || [0, 0];
      const isPolice = (p.categories || []).some((c: string) => c.includes('police'));
      return {
        name: p.name || (isPolice ? 'Police Station' : 'Hospital'),
        type: isPolice ? 'police' : 'hospital',
        latitude: coords[1] || 0,
        longitude: coords[0] || 0,
        address: p.formatted || null,
        distanceKm: p.distance ? Number((p.distance / 1000).toFixed(2)) : null,
      };
    });
  }
}

