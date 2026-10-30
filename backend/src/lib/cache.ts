import { getDb } from './db';
import { Place } from './schemas/place';

export interface CacheRecord<T> {
  data: T;
  fetchedAt: string;
  expiresAt: string;
  isStale: boolean;
}

export interface ICacheStore {
  get<T>(namespace: string, key: string): Promise<CacheRecord<T> | null>;
  set<T>(namespace: string, key: string, data: T, ttlSeconds: number): Promise<void>;
  recordCity(city: string): Promise<void>;
  getRequestedCities(limit?: number): Promise<string[]>;
}

class SqliteCacheStore implements ICacheStore {
  private initialized = false;

  private ensureSchema() {
    if (this.initialized) return;
    try {
      const db = getDb();
      db.exec(`
        CREATE TABLE IF NOT EXISTS general_cache (
          namespace TEXT NOT NULL,
          cache_key TEXT NOT NULL,
          payload TEXT NOT NULL,
          fetched_at TEXT NOT NULL,
          expires_at TEXT NOT NULL,
          PRIMARY KEY (namespace, cache_key)
        );
        CREATE INDEX IF NOT EXISTS idx_gen_cache_exp ON general_cache(namespace, expires_at);

        CREATE TABLE IF NOT EXISTS requested_cities (
          city TEXT PRIMARY KEY,
          requested_count INTEGER NOT NULL DEFAULT 1,
          last_requested_at TEXT NOT NULL
        );
      `);
      this.initialized = true;
    } catch (e) {
      console.error('[Cache] Failed to init cache tables:', e);
    }
  }

  async get<T>(namespace: string, key: string): Promise<CacheRecord<T> | null> {
    this.ensureSchema();
    try {
      const db = getDb();
      const stmt = db.prepare(`
        SELECT payload, fetched_at, expires_at
        FROM general_cache
        WHERE namespace = ? AND cache_key = ?
      `);
      const row = stmt.get(namespace, key) as { payload: string; fetched_at: string; expires_at: string } | undefined;
      if (!row) return null;

      const now = new Date().toISOString();
      const isStale = now > row.expires_at;
      const data = JSON.parse(row.payload) as T;

      return {
        data,
        fetchedAt: row.fetched_at,
        expiresAt: row.expires_at,
        isStale,
      };
    } catch (err) {
      console.warn('[Cache] Error getting key:', key, err);
      return null;
    }
  }

  async set<T>(namespace: string, key: string, data: T, ttlSeconds: number): Promise<void> {
    this.ensureSchema();
    try {
      const db = getDb();
      const now = new Date();
      const fetchedAt = now.toISOString();
      const expiresAt = new Date(now.getTime() + ttlSeconds * 1000).toISOString();
      const payload = JSON.stringify(data);

      const stmt = db.prepare(`
        INSERT INTO general_cache (namespace, cache_key, payload, fetched_at, expires_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(namespace, cache_key) DO UPDATE SET
          payload = excluded.payload,
          fetched_at = excluded.fetched_at,
          expires_at = excluded.expires_at
      `);
      stmt.run(namespace, key, payload, fetchedAt, expiresAt);
    } catch (err) {
      console.warn('[Cache] Error setting key:', key, err);
    }
  }

  async recordCity(city: string): Promise<void> {
    this.ensureSchema();
    try {
      const db = getDb();
      const now = new Date().toISOString();
      const normalized = city.trim().toLowerCase();
      if (!normalized) return;

      const stmt = db.prepare(`
        INSERT INTO requested_cities (city, requested_count, last_requested_at)
        VALUES (?, 1, ?)
        ON CONFLICT(city) DO UPDATE SET
          requested_count = requested_count + 1,
          last_requested_at = excluded.last_requested_at
      `);
      stmt.run(normalized, now);
    } catch (err) {
      console.warn('[Cache] Error recording city:', city, err);
    }
  }

  async getRequestedCities(limit: number = 50): Promise<string[]> {
    this.ensureSchema();
    try {
      const db = getDb();
      const stmt = db.prepare(`
        SELECT city FROM requested_cities
        ORDER BY requested_count DESC, last_requested_at DESC
        LIMIT ?
      `);
      const rows = stmt.all(limit) as Array<{ city: string }>;
      return rows.map((r) => r.city);
    } catch (err) {
      console.warn('[Cache] Error getting requested cities:', err);
      return [];
    }
  }
}

// Swappable instance (defaults to SQLite, can be swapped with FirestoreCacheStore)
export const cacheStore: ICacheStore = new SqliteCacheStore();

// High level helpers
export async function getPlacesFromCache(key: string): Promise<CacheRecord<Place[]> | null> {
  return cacheStore.get<Place[]>('places', key);
}

export async function setPlacesInCache(key: string, places: Place[], ttlSeconds: number = 86400 * 7): Promise<void> {
  // Default TTL: 7 days
  return cacheStore.set<Place[]>('places', key, places, ttlSeconds);
}

export async function getItineraryFromCache(key: string): Promise<CacheRecord<any> | null> {
  return cacheStore.get<any>('itineraries', key);
}

export async function setItineraryInCache(key: string, data: any, ttlSeconds: number = 86400 * 3): Promise<void> {
  // Default TTL: 3 days
  return cacheStore.set<any>('itineraries', key, data, ttlSeconds);
}

