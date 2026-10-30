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
}
