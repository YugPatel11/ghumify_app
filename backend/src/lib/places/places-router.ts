import { Place } from '../schemas/place';
import { NearbyService } from '../schemas/nearby-service';
import { CircuitBreaker } from '../circuit-breaker';
import { cacheStore, getPlacesFromCache, setPlacesInCache } from '../cache';
import { PlaceDetailsParams, PlaceNearbyParams, PlaceProvider, PlacesResult, PlaceSearchParams } from './types';
import { GooglePlaceProvider } from './google-provider';
import { GeoapifyPlaceProvider } from './geoapify-provider';
import { OsmPlaceProvider } from './osm-provider';

export class PlacesRouter {
  private providers = new Map<string, PlaceProvider>();
  private circuitBreaker = new CircuitBreaker({ failureThreshold: 3, cooldownMs: 60000 });

  constructor() {
    this.registerProvider(new GooglePlaceProvider());
    this.registerProvider(new GeoapifyPlaceProvider());
    this.registerProvider(new OsmPlaceProvider());
  }

  registerProvider(provider: PlaceProvider) {
    this.providers.set(provider.name, provider);
  }

  private getProviderOrder(): string[] {
    const orderEnv = process.env.PLACES_PROVIDER_ORDER || 'google,geoapify,osm';
    return orderEnv
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .filter((name) => this.providers.has(name));
  }

  private getSearchCacheKey(params: PlaceSearchParams): string {
    const city = params.city.trim().toLowerCase();
    const cat = params.category ? `_${params.category.trim().toLowerCase()}` : '';
    const q = params.query ? `_${params.query.trim().toLowerCase()}` : '';
    return `search_${city}${cat}${q}`;
  }

  async search(params: PlaceSearchParams): Promise<PlacesResult<Place[]>> {
    const cacheKey = this.getSearchCacheKey(params);

    // Track city requested for cron refresh
    if (params.city) {
      await cacheStore.recordCity(params.city);
    }

    // 1. Check cache for fresh result
    const cached = await getPlacesFromCache(cacheKey);
    if (cached && !cached.isStale && cached.data.length > 0) {
      return {
        data: cached.data,
        provider: 'cache',
        isStale: false,
        fetchedAt: cached.fetchedAt,
      };
    }

    // 2. Iterate through live providers in order
    const providerOrder = this.getProviderOrder();
    const errors: Array<{ provider: string; error: string }> = [];

    for (const name of providerOrder) {
      const provider = this.providers.get(name);
      if (!provider || !provider.isAvailable()) continue;

      if (!this.circuitBreaker.isAvailable(name)) {
        console.warn(`[PlacesRouter] Provider ${name} is in cooldown (circuit open)`);
        continue;
      }

      try {
        const places = await provider.search(params);
        if (places && places.length > 0) {
          this.circuitBreaker.recordSuccess(name);
          const now = new Date().toISOString();
          // Save to cache (7 days TTL)
          await setPlacesInCache(cacheKey, places, 86400 * 7);
          return {
            data: places,
            provider: name,
            isStale: false,
            fetchedAt: now,
          };
        }
      } catch (err: any) {
        console.warn(`[PlacesRouter] Provider ${name} search failed:`, err?.message || err);
        this.circuitBreaker.recordFailure(name);
        errors.push({ provider: name, error: err?.message || String(err) });
      }
    }

    // 3. Fallback: serve stale cache if available
    if (cached && cached.data.length > 0) {
      console.warn(`[PlacesRouter] Serving STALE places cache for ${cacheKey}`);
      return {
        data: cached.data,
        provider: 'stale_cache',
        isStale: true,
        fetchedAt: cached.fetchedAt,
      };
    }

    // 4. If all fail and no cache, throw error
    throw new Error(
      `All places providers failed for city "${params.city}". Diagnostics: ${errors.map((e) => `[${e.provider}: ${e.error}]`).join(', ')}`
    );
  }

  async nearby(params: PlaceNearbyParams): Promise<PlacesResult<Place[]>> {
    const cacheKey = `nearby_${params.latitude.toFixed(3)}_${params.longitude.toFixed(3)}_${params.type || 'all'}`;

    const cached = await getPlacesFromCache(cacheKey);
    if (cached && !cached.isStale && cached.data.length > 0) {
      return {
        data: cached.data,
        provider: 'cache',
        isStale: false,
        fetchedAt: cached.fetchedAt,
      };
    }

    const providerOrder = this.getProviderOrder();
    for (const name of providerOrder) {
      const provider = this.providers.get(name);
      if (!provider || !provider.isAvailable()) continue;
      if (!this.circuitBreaker.isAvailable(name)) continue;

      try {
        const places = await provider.nearby(params);
        if (places && places.length > 0) {
          this.circuitBreaker.recordSuccess(name);
          const now = new Date().toISOString();
          await setPlacesInCache(cacheKey, places, 86400 * 3);
          return {
            data: places,
            provider: name,
            isStale: false,
            fetchedAt: now,
          };
        }
      } catch (err) {
        this.circuitBreaker.recordFailure(name);
      }
    }

    if (cached && cached.data.length > 0) {
      return {
        data: cached.data,
        provider: 'stale_cache',
        isStale: true,
        fetchedAt: cached.fetchedAt,
      };
    }

    return {
      data: [],
      provider: 'none',
      isStale: false,
      fetchedAt: new Date().toISOString(),
    };
  }

  async searchEmergency(params: PlaceNearbyParams): Promise<PlacesResult<NearbyService[]>> {
    // For emergency services, default to OSM then Geoapify then Google
    const providerOrder = ['osm', 'geoapify', 'google'];

    for (const name of providerOrder) {
      const provider = this.providers.get(name);
      if (!provider || !provider.isAvailable()) continue;
      if (!this.circuitBreaker.isAvailable(name)) continue;

      try {
        const services = await provider.searchEmergency(params);
        if (services && services.length > 0) {
          this.circuitBreaker.recordSuccess(name);
          return {
            data: services,
            provider: name,
            isStale: false,
            fetchedAt: new Date().toISOString(),
          };
        }
      } catch (err) {
        this.circuitBreaker.recordFailure(name);
      }
    }

    return {
      data: [],
      provider: 'none',
      isStale: false,
      fetchedAt: new Date().toISOString(),
    };
  }
}

export const placesRouter = new PlacesRouter();

