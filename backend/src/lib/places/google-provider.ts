import { Place } from '../schemas/place';
import { NearbyService } from '../schemas/nearby-service';
import { PlaceDetailsParams, PlaceNearbyParams, PlaceProvider, PlaceSearchParams } from './types';

export class GooglePlaceProvider implements PlaceProvider {
  readonly name = 'google';
  private apiKey: string;

  constructor() {
    this.apiKey = process.env.GOOGLE_MAPS_API_KEY || '';
  }

  isAvailable(): boolean {
    return Boolean(this.apiKey && this.apiKey.length > 5 && !this.apiKey.startsWith('YOUR_'));
  }

  private mapCategory(types: string[] = []): string {
    const s = new Set(types);
    if (['hindu_temple', 'temple', 'church', 'mosque', 'place_of_worship'].some((t) => s.has(t))) {
      return 'temples';
    }
    if (['museum', 'art_gallery'].some((t) => s.has(t))) {
      return 'heritage';
    }
    if (['park', 'natural_feature', 'campground'].some((t) => s.has(t))) {
      return 'nature';
    }
    if (['restaurant', 'food', 'cafe', 'bakery', 'meal_delivery', 'meal_takeaway'].some((t) => s.has(t))) {
      return 'food';
    }
    if (['shopping_mall', 'store', 'clothing_store', 'jewelry_store'].some((t) => s.has(t))) {
      return 'markets';
    }
    if (s.has('tourist_attraction')) {
      return 'heritage';
    }
    return 'culture';
  }

  private normalizePlace(item: any, city: string): Place {
    const loc = item.geometry?.location || {};
    const photos = Array.isArray(item.photos)
      ? item.photos
          .slice(0, 5)
          .map((p: any) =>
            p.photo_reference
              ? `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${p.photo_reference}&key=${this.apiKey}`
              : ''
          )
          .filter(Boolean)
      : [];

    return {
      id: item.place_id || `google_${Math.random().toString(36).substring(2, 9)}`,
      name: item.name || '',
      city,
      state: '',
      category: this.mapCategory(item.types),
      description: item.vicinity || item.formatted_address || '',
      history: '',
      latitude: Number(loc.lat) || 0,
      longitude: Number(loc.lng) || 0,
      address: item.formatted_address || item.vicinity || null,
      openingHours: {},
      photoUrls: photos,
      thumbnailUrl: photos[0] || null,
      avgVisitDurationMinutes: 60,
      rating: typeof item.rating === 'number' ? item.rating : null,
      reviewCount: typeof item.user_ratings_total === 'number' ? item.user_ratings_total : null,
      entryFee: null,
      tags: Array.isArray(item.types) ? item.types.slice(0, 5) : [],
      nearbyPlaceIds: [],
      googlePlaceId: item.place_id || null,
      isHiddenGem: false,
      specialNote: null,
      createdAt: new Date().toISOString(),
    };
  }

  async search(params: PlaceSearchParams): Promise<Place[]> {
    if (!this.isAvailable()) throw new Error('Google Maps API key is not configured.');

    const query = params.query ? `${params.query} in ${params.city}` : `top tourist attractions in ${params.city}`;
    const url = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodeURIComponent(query)}&key=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Google Places search failed: ${res.statusText}`);

    const data = await res.json();
    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      throw new Error(`Google Places API status: ${data.status} - ${data.error_message || ''}`);
    }

    const results = Array.isArray(data.results) ? data.results : [];
    const limit = params.limit || 20;
    return results.slice(0, limit).map((r: any) => this.normalizePlace(r, params.city));
  }

  async nearby(params: PlaceNearbyParams): Promise<Place[]> {
    if (!this.isAvailable()) throw new Error('Google Maps API key is not configured.');

    const radius = params.radiusMeters || 5000;
    const typeQuery = params.type ? `&type=${encodeURIComponent(params.type)}` : '';
    const url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${params.latitude},${params.longitude}&radius=${radius}${typeQuery}&key=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Google Places nearby failed: ${res.statusText}`);

    const data = await res.json();
    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      throw new Error(`Google Places API status: ${data.status}`);
    }

    const results = Array.isArray(data.results) ? data.results : [];
    const limit = params.limit || 20;
    return results.slice(0, limit).map((r: any) => this.normalizePlace(r, ''));
  }

  async details(params: PlaceDetailsParams): Promise<Place | null> {
    if (!this.isAvailable()) throw new Error('Google Maps API key is not configured.');

    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${encodeURIComponent(params.placeId)}&fields=place_id,name,formatted_address,geometry,photos,rating,user_ratings_total,types,opening_hours&key=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Google Place details failed: ${res.statusText}`);

    const data = await res.json();
    if (!data.result) return null;

    const item = data.result;
    const place = this.normalizePlace(item, '');
    if (item.opening_hours?.weekday_text && Array.isArray(item.opening_hours.weekday_text)) {
      const hoursMap: Record<string, string> = {};
      for (const line of item.opening_hours.weekday_text) {
        const parts = line.split(': ');
        if (parts.length >= 2) {
          hoursMap[parts[0].toLowerCase().slice(0, 3)] = parts.slice(1).join(': ');
        }
      }
      place.openingHours = hoursMap;
    }
    return place;
  }

  async searchEmergency(params: PlaceNearbyParams): Promise<NearbyService[]> {
    if (!this.isAvailable()) throw new Error('Google Maps API key is not configured.');

    const radius = params.radiusMeters || 5000;
    const url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${params.latitude},${params.longitude}&radius=${radius}&type=hospital|police&key=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Google Places emergency failed: ${res.statusText}`);

    const data = await res.json();
    const results = Array.isArray(data.results) ? data.results : [];

    return results.map((item: any) => {
      const isPolice = Array.isArray(item.types) && item.types.includes('police');
      const loc = item.geometry?.location || {};
      return {
        name: item.name || (isPolice ? 'Police Station' : 'Hospital'),
        type: isPolice ? 'police' : 'hospital',
        latitude: Number(loc.lat) || 0,
        longitude: Number(loc.lng) || 0,
        address: item.vicinity || item.formatted_address || null,
        distanceKm: null,
      };
    });
  }
}

