// @ts-ignore
import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';
import fs from 'node:fs';

const DB_DIR = path.join(process.cwd(), 'data');
const DB_PATH = path.join(DB_DIR, 'ghumify.db');

let dbInstance: DatabaseSync | null = null;

export function getDb(): DatabaseSync {
  if (!dbInstance) {
    if (!fs.existsSync(DB_DIR)) {
      fs.mkdirSync(DB_DIR, { recursive: true });
    }

    dbInstance = new DatabaseSync(DB_PATH);
    dbInstance.exec('PRAGMA journal_mode = WAL;');
    dbInstance.exec('PRAGMA foreign_keys = ON;');
    initSchema(dbInstance);
  }
  return dbInstance;
}

function initSchema(db: DatabaseSync) {
  // Users table
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      preferred_language TEXT NOT NULL DEFAULT 'en',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  // Translations cache table with unique constraint on (key, language)
  db.exec(`
    CREATE TABLE IF NOT EXISTS translations (
      id TEXT PRIMARY KEY,
      namespace TEXT NOT NULL DEFAULT 'common',
      key TEXT NOT NULL,
      source_hash TEXT NOT NULL,
      source_text TEXT NOT NULL,
      language TEXT NOT NULL,
      translated_text TEXT NOT NULL,
      provider TEXT NOT NULL DEFAULT 'system',
      is_manual INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(key, language)
    );
  `);

  // Rate limiting table for endpoints
  db.exec(`
    CREATE TABLE IF NOT EXISTS rate_limits (
      client_key TEXT PRIMARY KEY,
      request_count INTEGER NOT NULL DEFAULT 1,
      window_start INTEGER NOT NULL
    );
  `);

  // Performance Indexes
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_translations_lang ON translations(language);
    CREATE INDEX IF NOT EXISTS idx_translations_key ON translations(key);
    CREATE INDEX IF NOT EXISTS idx_translations_hash ON translations(source_hash);
    CREATE INDEX IF NOT EXISTS idx_translations_namespace ON translations(namespace);
  `);

  // Trips table
  db.exec(`
    CREATE TABLE IF NOT EXISTS trips (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      title TEXT NOT NULL,
      city_id TEXT,
      city_name TEXT,
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  // Trip stops table
  db.exec(`
    CREATE TABLE IF NOT EXISTS trip_stops (
      id TEXT PRIMARY KEY,
      trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
      stop_order INTEGER NOT NULL,
      title TEXT NOT NULL,
      subtitle TEXT,
      place_id TEXT,
      stop_type TEXT NOT NULL DEFAULT 'visit',
      planned_arrival_at TEXT NOT NULL,
      planned_departure_at TEXT NOT NULL,
      stay_duration_minutes INTEGER NOT NULL,
      transport_mode TEXT NOT NULL DEFAULT 'driving',
      status TEXT NOT NULL DEFAULT 'upcoming',
      lat REAL,
      lng REAL,
      timezone TEXT NOT NULL DEFAULT 'UTC',
      actual_arrival_at TEXT,
      actual_departure_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  // Travel estimates table
  db.exec(`
    CREATE TABLE IF NOT EXISTS travel_estimates (
      id TEXT PRIMARY KEY,
      trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
      from_stop_id TEXT NOT NULL,
      to_stop_id TEXT NOT NULL,
      mode TEXT NOT NULL,
      duration_seconds INTEGER NOT NULL,
      distance_meters REAL NOT NULL,
      source TEXT NOT NULL,
      traffic_aware INTEGER NOT NULL DEFAULT 0,
      computed_at TEXT NOT NULL,
      expires_at TEXT NOT NULL
    );
  `);

  // Scheduled alerts table (Persistent job queue)
  db.exec(`
    CREATE TABLE IF NOT EXISTS scheduled_alerts (
      id TEXT PRIMARY KEY,
      trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
      stop_id TEXT NOT NULL REFERENCES trip_stops(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id),
      type TEXT NOT NULL,
      fire_at TEXT NOT NULL,
      notification_key TEXT UNIQUE NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      sent_at TEXT,
      error_message TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  // Device tokens table (FCM registration)
  db.exec(`
    CREATE TABLE IF NOT EXISTS device_tokens (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      token TEXT UNIQUE NOT NULL,
      platform TEXT NOT NULL,
      language TEXT NOT NULL DEFAULT 'en',
      timezone TEXT NOT NULL DEFAULT 'UTC',
      last_seen_at TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    );
  `);

  // User notification preferences
  db.exec(`
    CREATE TABLE IF NOT EXISTS notification_preferences (
      user_id TEXT PRIMARY KEY REFERENCES users(id),
      push_enabled INTEGER NOT NULL DEFAULT 1,
      heads_up_enabled INTEGER NOT NULL DEFAULT 1,
      heads_up_lead_minutes INTEGER NOT NULL DEFAULT 15,
      leave_now_enabled INTEGER NOT NULL DEFAULT 1,
      go_to_next_enabled INTEGER NOT NULL DEFAULT 1,
      overdue_nag_enabled INTEGER NOT NULL DEFAULT 1,
      late_warning_enabled INTEGER NOT NULL DEFAULT 1,
      safety_buffer_minutes INTEGER NOT NULL DEFAULT 10,
      default_transport_mode TEXT NOT NULL DEFAULT 'driving',
      quiet_hours_enabled INTEGER NOT NULL DEFAULT 0,
      quiet_hours_start TEXT NOT NULL DEFAULT '22:00',
      quiet_hours_end TEXT NOT NULL DEFAULT '07:00',
      allow_trip_override_quiet_hours INTEGER NOT NULL DEFAULT 1,
      location_smart_mode_enabled INTEGER NOT NULL DEFAULT 0,
      max_overdue_nags INTEGER NOT NULL DEFAULT 3,
      updated_at TEXT NOT NULL
    );
  `);

  // Notifications (In-app inbox)
  db.exec(`
    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      trip_id TEXT,
      stop_id TEXT,
      type TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      data_payload TEXT,
      notification_key TEXT,
      is_read INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  `);

  // Indexes for high performance and fast job claiming
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_alerts_fire_status ON scheduled_alerts(fire_at, status);
    CREATE INDEX IF NOT EXISTS idx_alerts_trip_stop ON scheduled_alerts(trip_id, stop_id);
    CREATE INDEX IF NOT EXISTS idx_alerts_user ON scheduled_alerts(user_id);
    CREATE INDEX IF NOT EXISTS idx_trip_stops_trip ON trip_stops(trip_id, stop_order);
    CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id, is_active);
    CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at);
  `);

  // Emergency Contacts table
  db.exec(`
    CREATE TABLE IF NOT EXISTS emergency_contacts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      name TEXT NOT NULL,
      phone_e164 TEXT NOT NULL,
      relationship TEXT NOT NULL DEFAULT 'Family',
      priority INTEGER NOT NULL DEFAULT 1,
      preferred_channels TEXT NOT NULL DEFAULT 'sms,push',
      language TEXT NOT NULL DEFAULT 'en',
      email TEXT,
      is_verified INTEGER NOT NULL DEFAULT 0,
      verified_at TEXT,
      consent_notice_sent_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(user_id, phone_e164)
    );
  `);

  // Contact Verification Codes table
  db.exec(`
    CREATE TABLE IF NOT EXISTS emergency_contact_verifications (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL REFERENCES emergency_contacts(id) ON DELETE CASCADE,
      code_hash TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  `);

  // SOS Events table
  db.exec(`
    CREATE TABLE IF NOT EXISTS sos_events (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      trip_id TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      trigger_source TEXT NOT NULL DEFAULT 'home',
      triggered_at TEXT NOT NULL,
      resolved_at TEXT,
      initial_lat REAL NOT NULL,
      initial_lng REAL NOT NULL,
      accuracy_m REAL NOT NULL DEFAULT 10,
      location_source TEXT NOT NULL DEFAULT 'gps',
      battery_percent INTEGER,
      itinerary_snapshot TEXT,
      medical_info_included INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  // SOS Live Location Trail table
  db.exec(`
    CREATE TABLE IF NOT EXISTS sos_location_updates (
      id TEXT PRIMARY KEY,
      sos_id TEXT NOT NULL REFERENCES sos_events(id) ON DELETE CASCADE,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      accuracy_m REAL NOT NULL DEFAULT 10,
      recorded_at TEXT NOT NULL
    );
  `);

  // SOS Deliveries table (per-contact, per-channel audit log)
  db.exec(`
    CREATE TABLE IF NOT EXISTS sos_deliveries (
      id TEXT PRIMARY KEY,
      sos_id TEXT NOT NULL REFERENCES sos_events(id) ON DELETE CASCADE,
      contact_id TEXT,
      channel TEXT NOT NULL,
      provider TEXT NOT NULL,
      provider_message_id TEXT,
      status TEXT NOT NULL DEFAULT 'queued',
      error_code TEXT,
      attempts INTEGER NOT NULL DEFAULT 1,
      sent_at TEXT,
      delivered_at TEXT,
      kind TEXT NOT NULL DEFAULT 'initial'
    );
  `);

  // Nearby Hospitals Cache table
  db.exec(`
    CREATE TABLE IF NOT EXISTS nearby_hospitals_cache (
      id TEXT PRIMARY KEY,
      geo_cell TEXT NOT NULL,
      provider TEXT NOT NULL,
      payload TEXT NOT NULL,
      fetched_at TEXT NOT NULL,
      expires_at TEXT NOT NULL
    );
  `);

  // User Medical Profile
  db.exec(`
    CREATE TABLE IF NOT EXISTS user_medical_profiles (
      user_id TEXT PRIMARY KEY REFERENCES users(id),
      blood_group TEXT,
      allergies TEXT,
      medical_conditions TEXT,
      medications TEXT,
      include_in_sos INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    );
  `);

  // User SOS Settings
  db.exec(`
    CREATE TABLE IF NOT EXISTS user_sos_settings (
      user_id TEXT PRIMARY KEY REFERENCES users(id),
      countdown_seconds INTEGER NOT NULL DEFAULT 5,
      trigger_method TEXT NOT NULL DEFAULT 'hold',
      update_interval_minutes INTEGER NOT NULL DEFAULT 3,
      expiry_hours INTEGER NOT NULL DEFAULT 6,
      include_medical_info INTEGER NOT NULL DEFAULT 0,
      share_itinerary_snapshot INTEGER NOT NULL DEFAULT 1,
      auto_call_emergency INTEGER NOT NULL DEFAULT 0,
      emergency_number TEXT NOT NULL DEFAULT '112',
      send_hospital_info INTEGER NOT NULL DEFAULT 1,
      daily_sms_cap INTEGER NOT NULL DEFAULT 30,
      updated_at TEXT NOT NULL
    );
  `);

  // Indexes for SOS and Emergency tables
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_contacts_user ON emergency_contacts(user_id, priority);
    CREATE INDEX IF NOT EXISTS idx_sos_user_status ON sos_events(user_id, status);
    CREATE INDEX IF NOT EXISTS idx_sos_location_sos ON sos_location_updates(sos_id, recorded_at);
    CREATE INDEX IF NOT EXISTS idx_sos_deliveries_sos ON sos_deliveries(sos_id, contact_id, channel);
    CREATE INDEX IF NOT EXISTS idx_hospitals_cache_cell ON nearby_hospitals_cache(geo_cell);
  `);

  // Seed default demo user if absent
  const checkUser = db.prepare('SELECT id FROM users WHERE id = ?');
  const user = checkUser.get('user_demo');
  if (!user) {
    const now = new Date().toISOString();
    const insertUser = db.prepare(`
      INSERT INTO users (id, name, email, preferred_language, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    insertUser.run('user_demo', 'Ghumify Traveler', 'traveler@ghumify.app', 'en', now, now);
  }

  // Seed default notification preferences for demo user
  const checkPrefs = db.prepare('SELECT user_id FROM notification_preferences WHERE user_id = ?');
  const prefs = checkPrefs.get('user_demo');
  if (!prefs) {
    const now = new Date().toISOString();
    const insertPrefs = db.prepare(`
      INSERT INTO notification_preferences (
        user_id, push_enabled, heads_up_enabled, heads_up_lead_minutes,
        leave_now_enabled, go_to_next_enabled, overdue_nag_enabled, late_warning_enabled,
        safety_buffer_minutes, default_transport_mode, quiet_hours_enabled,
        quiet_hours_start, quiet_hours_end, allow_trip_override_quiet_hours,
        location_smart_mode_enabled, max_overdue_nags, updated_at
      ) VALUES (
        'user_demo', 1, 1, 15, 1, 1, 1, 1, 10, 'driving', 0, '22:00', '07:00', 1, 0, 3, ?
      )
    `);
    insertPrefs.run(now);
  }

  // Seed default SOS settings for demo user
  const checkSosSettings = db.prepare('SELECT user_id FROM user_sos_settings WHERE user_id = ?');
  const sosSettings = checkSosSettings.get('user_demo');
  if (!sosSettings) {
    const now = new Date().toISOString();
    const insertSos = db.prepare(`
      INSERT INTO user_sos_settings (
        user_id, countdown_seconds, trigger_method, update_interval_minutes,
        expiry_hours, include_medical_info, share_itinerary_snapshot,
        auto_call_emergency, emergency_number, send_hospital_info, daily_sms_cap, updated_at
      ) VALUES (
        'user_demo', 5, 'hold', 3, 6, 0, 1, 0, '112', 1, 30, ?
      )
    `);
    insertSos.run(now);
  }

  // Seed default demo emergency contact if none exists
  const checkContacts = db.prepare('SELECT count(*) as count FROM emergency_contacts WHERE user_id = ?');
  const count = (checkContacts.get('user_demo') as any)?.count || 0;
  if (count === 0) {
    const now = new Date().toISOString();
    const insertContact = db.prepare(`
      INSERT INTO emergency_contacts (
        id, user_id, name, phone_e164, relationship, priority, preferred_channels,
        language, email, is_verified, verified_at, created_at, updated_at
      ) VALUES (
        'contact_demo_1', 'user_demo', 'Aarav Sharma (Brother)', '+919876543210',
        'Brother', 1, 'sms,push', 'hi', 'aarav@example.com', 1, ?, ?, ?
      )
    `);
    insertContact.run(now, now, now);
  }
}
