import { getDb } from '../db';

export interface Coordinates {
  lat: number;
  lng: number;
}

export type TransportMode = 'driving' | 'walk' | 'transit' | 'bike';

export interface TravelEstimateResult {
  durationSeconds: number;
  distanceMeters: number;
  source: 'google_matrix' | 'cached' | 'haversine_fallback';
  isApproximate: boolean;
  computedAt: string;
  expiresAt: string;
}

export class RoutingProvider {
  /**
   * Approximate speeds (in km/h) and detour factors for each mode.
   */
  private static readonly MODE_METRICS: Record<
    TransportMode,
    { speedKmh: number; detourFactor: number }
  > = {
    driving: { speedKmh: 40, detourFactor: 1.3 },
    walk: { speedKmh: 4.8, detourFactor: 1.2 },
    transit: { speedKmh: 25, detourFactor: 1.35 },
    bike: { speedKmh: 15, detourFactor: 1.25 },
  };

  /**
   * Calculate Haversine great-circle distance between two points in meters.
   */
  public static haversineMeters(origin: Coordinates, destination: Coordinates): number {
    const R = 6371000; // Radius of the Earth in meters
    const dLat = ((destination.lat - origin.lat) * Math.PI) / 180;
    const dLng = ((destination.lng - origin.lng) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((origin.lat * Math.PI) / 180) *
        Math.cos((destination.lat * Math.PI) / 180) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * Fallback estimation based on Haversine distance, mode speed, and detour factor.
   */
  public static calculateHaversineEstimate(
    origin: Coordinates,
    destination: Coordinates,
    mode: TransportMode
  ): TravelEstimateResult {
    const now = new Date();
    const expires = new Date(now.getTime() + 60 * 60 * 1000); // 1 hour TTL

    // If identical or nearly identical location (< 20m)
    const directMeters = this.haversineMeters(origin, destination);
    if (directMeters < 20) {
      return {
        durationSeconds: 0,
        distanceMeters: 0,
        source: 'haversine_fallback',
        isApproximate: false,
        computedAt: now.toISOString(),
        expiresAt: expires.toISOString(),
      };
    }

    const metric = this.MODE_METRICS[mode] || this.MODE_METRICS.driving;
    const roadMeters = directMeters * metric.detourFactor;
    const speedMps = (metric.speedKmh * 1000) / 3600;
    const durationSeconds = Math.round(roadMeters / speedMps);

    return {
      durationSeconds: Math.max(60, durationSeconds),
      distanceMeters: Math.round(roadMeters),
      source: 'haversine_fallback',
      isApproximate: true,
      computedAt: now.toISOString(),
      expiresAt: expires.toISOString(),
    };
  }

  /**
   * Fetch travel time using Google Maps Distance Matrix, with DB caching and Haversine fallback.
   */
  public static async getTravelTime(
    tripId: string,
    fromStopId: string,
    toStopId: string,
    origin: Coordinates | null,
    destination: Coordinates | null,
    mode: TransportMode = 'driving',
    departAtUtc?: string
  ): Promise<TravelEstimateResult> {
    const db = getDb();
    const nowIso = new Date().toISOString();

    // Edge case 1: Missing coordinates -> return safe default 15 min
    if (!origin || !destination) {
      return {
        durationSeconds: 15 * 60,
        distanceMeters: 5000,
        source: 'haversine_fallback',
        isApproximate: true,
        computedAt: nowIso,
        expiresAt: new Date(Date.now() + 3600000).toISOString(),
      };
    }

    // Edge case 2: Consecutive stops at identical coordinates
    if (
      Math.abs(origin.lat - destination.lat) < 0.0001 &&
      Math.abs(origin.lng - destination.lng) < 0.0001
    ) {
      return {
        durationSeconds: 0,
        distanceMeters: 0,
        source: 'haversine_fallback',
        isApproximate: false,
        computedAt: nowIso,
        expiresAt: new Date(Date.now() + 86400000).toISOString(),
      };
    }

    // Check DB cache for active, unexpired estimate
    const cachedStmt = db.prepare(`
      SELECT duration_seconds, distance_meters, source, traffic_aware, computed_at, expires_at
      FROM travel_estimates
      WHERE trip_id = ? AND from_stop_id = ? AND to_stop_id = ? AND mode = ?
      ORDER BY computed_at DESC LIMIT 1
    `);
    const cached = cachedStmt.get(tripId, fromStopId, toStopId, mode) as any;

    if (cached && new Date(cached.expires_at).getTime() > Date.now()) {
      return {
        durationSeconds: cached.duration_seconds,
        distanceMeters: cached.distance_meters,
        source: 'cached',
        isApproximate: cached.source === 'haversine_fallback',
        computedAt: cached.computed_at,
        expiresAt: cached.expires_at,
      };
    }

    // Try Google Maps Distance Matrix if API key exists
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (apiKey) {
      try {
        const googleMode = mode === 'walk' ? 'walking' : mode === 'bike' ? 'bicycling' : mode;
        let url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${origin.lat},${origin.lng}&destinations=${destination.lat},${destination.lng}&mode=${googleMode}&key=${apiKey}`;

        if (departAtUtc) {
          const departureEpoch = Math.floor(new Date(departAtUtc).getTime() / 1000);
          if (departureEpoch > Math.floor(Date.now() / 1000)) {
            url += `&departure_time=${departureEpoch}`;
          }
        }

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 6000);
        const res = await fetch(url, { signal: controller.signal });
        clearTimeout(timeout);

        if (res.ok) {
          const data = await res.json();
          if (
            data.status === 'OK' &&
            data.rows?.[0]?.elements?.[0]?.status === 'OK'
          ) {
            const element = data.rows[0].elements[0];
            const durationSec = element.duration_in_traffic?.value ?? element.duration.value;
            const distanceMeters = element.distance.value;

            // Cache in DB with 30-min TTL if near, or 2-hour TTL if far away
            const now = new Date();
            const departTime = departAtUtc ? new Date(departAtUtc).getTime() : now.getTime();
            const diffMin = (departTime - now.getTime()) / (60 * 1000);
            const ttlMs = diffMin < 60 ? 15 * 60 * 1000 : 120 * 60 * 1000;
            const expiresIso = new Date(now.getTime() + ttlMs).toISOString();

            const upsertEstimate = db.prepare(`
              INSERT INTO travel_estimates (
                id, trip_id, from_stop_id, to_stop_id, mode,
                duration_seconds, distance_meters, source, traffic_aware,
                computed_at, expires_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, 'google_matrix', 1, ?, ?)
            `);
            const estimateId = `est_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
            upsertEstimate.run(
              estimateId,
              tripId,
              fromStopId,
              toStopId,
              mode,
              durationSec,
              distanceMeters,
              now.toISOString(),
              expiresIso
            );

            return {
              durationSeconds: durationSec,
              distanceMeters: distanceMeters,
              source: 'google_matrix',
              isApproximate: false,
              computedAt: now.toISOString(),
              expiresAt: expiresIso,
            };
          }
        }
      } catch (err) {
        console.warn('Google Maps Distance Matrix call failed, using fallback:', err);
      }
    }

    // Provider failed or API key missing -> Fall back to last cached (even if expired)
    if (cached) {
      return {
        durationSeconds: cached.duration_seconds,
        distanceMeters: cached.distance_meters,
        source: 'cached',
        isApproximate: true,
        computedAt: cached.computed_at,
        expiresAt: cached.expires_at,
      };
    }

    // Final fallback: Haversine distance with mode speed and detour factor
    const fallback = this.calculateHaversineEstimate(origin, destination, mode);
    try {
      const saveFallback = db.prepare(`
        INSERT INTO travel_estimates (
          id, trip_id, from_stop_id, to_stop_id, mode,
          duration_seconds, distance_meters, source, traffic_aware,
          computed_at, expires_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 'haversine_fallback', 0, ?, ?)
      `);
      const fallbackId = `est_fb_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
      saveFallback.run(
        fallbackId,
        tripId,
        fromStopId,
        toStopId,
        mode,
        fallback.durationSeconds,
        fallback.distanceMeters,
        fallback.computedAt,
        fallback.expiresAt
      );
    } catch {
      // Ignored if tripId was mock/uncommitted during calculation
    }

    return fallback;
  }
}
