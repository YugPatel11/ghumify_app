import { getDb } from '../db';
import { RoutingProvider } from '../notifications/routing-provider';

export interface HospitalInfo {
  id: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
  distanceMeters: number;
  phone?: string;
  hasEmergencyDepartment: boolean;
  isOpen24Hours: boolean;
  navigationUrl: string;
}

export class HospitalProvider {
  /**
   * Curated high-reliability fallback hospitals across key regions for instant offline availability.
   */
  private static readonly REGIONAL_FALLBACK_HOSPITALS: HospitalInfo[] = [
    {
      id: 'hosp_jaipur_sms',
      name: 'Sawai Man Singh (SMS) Hospital',
      address: 'JLN Marg, Ashok Nagar, Jaipur, Rajasthan 302004',
      lat: 26.8997,
      lng: 75.8166,
      distanceMeters: 0,
      phone: '+91-141-2560291',
      hasEmergencyDepartment: true,
      isOpen24Hours: true,
      navigationUrl: 'https://www.google.com/maps/dir/?api=1&destination=26.8997,75.8166',
    },
    {
      id: 'hosp_jaipur_fortis',
      name: 'Fortis Escorts Hospital',
      address: 'Jawaharlal Nehru Marg, Malviya Nagar, Jaipur, Rajasthan 302017',
      lat: 26.8523,
      lng: 75.8078,
      distanceMeters: 0,
      phone: '+91-141-2547000',
      hasEmergencyDepartment: true,
      isOpen24Hours: true,
      navigationUrl: 'https://www.google.com/maps/dir/?api=1&destination=26.8523,75.8078',
    },
    {
      id: 'hosp_indore_my',
      name: 'Maharaja Yeshwantrao (MY) Hospital',
      address: 'Sanyogitaganj, Indore, Madhya Pradesh 452001',
      lat: 22.7153,
      lng: 75.8756,
      distanceMeters: 0,
      phone: '+91-731-2527383',
      hasEmergencyDepartment: true,
      isOpen24Hours: true,
      navigationUrl: 'https://www.google.com/maps/dir/?api=1&destination=22.7153,75.8756',
    },
    {
      id: 'hosp_indore_medanta',
      name: 'Medanta Hospital Indore',
      address: 'Sector B, Scheme No 54, Vijay Nagar, Indore, Madhya Pradesh 452010',
      lat: 22.7533,
      lng: 75.8937,
      distanceMeters: 0,
      phone: '+91-731-774444',
      hasEmergencyDepartment: true,
      isOpen24Hours: true,
      navigationUrl: 'https://www.google.com/maps/dir/?api=1&destination=22.7533,75.8937',
    },
    {
      id: 'hosp_delhi_aiims',
      name: 'AIIMS New Delhi',
      address: 'Sri Aurobindo Marg, Ansari Nagar, New Delhi 110029',
      lat: 28.5672,
      lng: 77.2100,
      distanceMeters: 0,
      phone: '+91-11-26588500',
      hasEmergencyDepartment: true,
      isOpen24Hours: true,
      navigationUrl: 'https://www.google.com/maps/dir/?api=1&destination=28.5672,77.2100',
    },
    {
      id: 'hosp_varanasi_bhu',
      name: 'Sir Sunderlal Hospital, BHU',
      address: 'Banaras Hindu University Campus, Varanasi, UP 221005',
      lat: 25.2755,
      lng: 82.9996,
      distanceMeters: 0,
      phone: '+91-542-2307500',
      hasEmergencyDepartment: true,
      isOpen24Hours: true,
      navigationUrl: 'https://www.google.com/maps/dir/?api=1&destination=25.2755,82.9996',
    },
  ];

  /**
   * Generates a 2-decimal rounded grid cell key for cache grouping (~1.1 km resolution).
   */
  public static makeGeoCellKey(lat: number, lng: number): string {
    return `${lat.toFixed(2)}_${lng.toFixed(2)}`;
  }

  /**
   * Find nearby hospitals for given coordinates with automatic radius expansion.
   */
  public static async findNearby(
    lat: number,
    lng: number,
    initialRadiusMeters: number = 5000,
    limit: number = 5
  ): Promise<HospitalInfo[]> {
    const db = getDb();
    const cellKey = this.makeGeoCellKey(lat, lng);
    const nowEpoch = Date.now();
    const nowIso = new Date().toISOString();

    // 1. Check DB Cache
    try {
      const cacheStmt = db.prepare(`
        SELECT payload, expires_at FROM nearby_hospitals_cache
        WHERE geo_cell = ? AND expires_at > ?
        LIMIT 1
      `);
      const cached = cacheStmt.get(cellKey, nowIso) as any;
      if (cached?.payload) {
        const parsed = JSON.parse(cached.payload) as HospitalInfo[];
        return this.sortAndFormatDistance(lat, lng, parsed, limit);
      }
    } catch (e) {
      console.warn('[HospitalProvider] Cache lookup error:', e);
    }

    // 2. Query OpenStreetMap Overpass API if reachable
    try {
      const radiusOptions = [initialRadiusMeters, 15000, 30000];
      for (const radius of radiusOptions) {
        const query = `
          [out:json][timeout:5];
          (
            node["amenity"="hospital"](around:${radius},${lat},${lng});
            node["healthcare"="hospital"](around:${radius},${lat},${lng});
            way["amenity"="hospital"](around:${radius},${lat},${lng});
          );
          out center 10;
        `;
        const overpassUrl = `https://overpass-api.de/api/interpreter?data=${encodeURIComponent(query)}`;

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 4500);

        const res = await fetch(overpassUrl, { signal: controller.signal });
        clearTimeout(timeout);

        if (res.ok) {
          const data = await res.json();
          if (data.elements && data.elements.length > 0) {
            const hospitals: HospitalInfo[] = data.elements.map((el: any) => {
              const hLat = el.lat ?? el.center?.lat;
              const hLng = el.lon ?? el.center?.lon;
              const tags = el.tags || {};
              const name = tags.name || tags['name:en'] || 'General Hospital';
              const emergency = tags.emergency === 'yes' || tags['healthcare:speciality']?.includes('emergency');
              const is24h = tags.opening_hours === '24/7';

              return {
                id: `osm_${el.id}`,
                name,
                address: tags['addr:street']
                  ? `${tags['addr:street']}, ${tags['addr:city'] || ''}`
                  : `${name}, near ${hLat.toFixed(4)}, ${hLng.toFixed(4)}`,
                lat: hLat,
                lng: hLng,
                distanceMeters: Math.round(RoutingProvider.haversineMeters({ lat, lng }, { lat: hLat, lng: hLng })),
                phone: tags.phone || tags['contact:phone'] || undefined,
                hasEmergencyDepartment: emergency,
                isOpen24Hours: is24h,
                navigationUrl: `https://www.google.com/maps/dir/?api=1&destination=${hLat},${hLng}`,
              };
            });

            // Cache result in DB with 24-hour TTL
            try {
              const expiresIso = new Date(nowEpoch + 24 * 60 * 60 * 1000).toISOString();
              const insertCache = db.prepare(`
                INSERT INTO nearby_hospitals_cache (id, geo_cell, provider, payload, fetched_at, expires_at)
                VALUES (?, ?, 'osm_overpass', ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, expires_at = excluded.expires_at
              `);
              insertCache.run(`cache_${cellKey}`, cellKey, JSON.stringify(hospitals), nowIso, expiresIso);
            } catch {}

            return this.sortAndFormatDistance(lat, lng, hospitals, limit);
          }
        }
      }
    } catch (err) {
      console.warn('[HospitalProvider] External hospital fetch failed, falling back to curated registry:', err);
    }

    // 3. Fallback: Curated Regional Hospitals
    return this.sortAndFormatDistance(lat, lng, this.REGIONAL_FALLBACK_HOSPITALS, limit);
  }

  /**
   * Recalculates distances, sorts by emergency capability and proximity, and limits result count.
   */
  private static sortAndFormatDistance(
    originLat: number,
    originLng: number,
    hospitals: HospitalInfo[],
    limit: number
  ): HospitalInfo[] {
    const updated = hospitals.map((h) => ({
      ...h,
      distanceMeters: Math.round(
        RoutingProvider.haversineMeters({ lat: originLat, lng: originLng }, { lat: h.lat, lng: h.lng })
      ),
      navigationUrl: `https://www.google.com/maps/dir/?api=1&destination=${h.lat},${h.lng}`,
    }));

    // Sort: prioritize hospitals with emergency departments, then closest distance
    updated.sort((a, b) => {
      if (a.hasEmergencyDepartment && !b.hasEmergencyDepartment) return -1;
      if (!a.hasEmergencyDepartment && b.hasEmergencyDepartment) return 1;
      return a.distanceMeters - b.distanceMeters;
    });

    return updated.slice(0, limit);
  }
}
