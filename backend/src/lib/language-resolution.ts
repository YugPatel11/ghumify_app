import { getDb } from './db';
import { DEFAULT_LANGUAGE, isLanguageSupported, getLanguageMetadata } from './languages';

export interface ResolveOptions {
  userId?: string | null;
  queryLang?: string | null;
  headerLang?: string | null;
  acceptLanguageHeader?: string | null;
}

export function parseAcceptLanguage(header: string | null | undefined): string[] {
  if (!header) return [];
  // Parse format like: fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5
  return header
    .split(',')
    .map((part) => {
      const [lang, qPart] = part.trim().split(';');
      let q = 1.0;
      if (qPart && qPart.trim().startsWith('q=')) {
        const parsedQ = parseFloat(qPart.trim().substring(2));
        if (!isNaN(parsedQ)) q = parsedQ;
      }
      return { lang: lang.trim(), q };
    })
    .sort((a, b) => b.q - a.q)
    .map((item) => item.lang);
}

export function resolveLanguage(opts: ResolveOptions): string {
  // 1. Authenticated user preference
  if (opts.userId) {
    try {
      const db = getDb();
      const row = db.prepare('SELECT preferred_language FROM users WHERE id = ?').get(opts.userId) as any;
      if (row?.preferred_language && isLanguageSupported(row.preferred_language)) {
        return row.preferred_language;
      }
    } catch (err) {
      console.warn('[ResolveLanguage] Failed to query user language:', err);
    }
  }

  // 2. Query param ?lang= or X-Language header
  if (opts.queryLang) {
    const meta = getLanguageMetadata(opts.queryLang);
    if (meta) return meta.code;
  }
  if (opts.headerLang) {
    const meta = getLanguageMetadata(opts.headerLang);
    if (meta) return meta.code;
  }

  // 3. Accept-Language header
  if (opts.acceptLanguageHeader) {
    const candidates = parseAcceptLanguage(opts.acceptLanguageHeader);
    for (const cand of candidates) {
      const meta = getLanguageMetadata(cand);
      if (meta) {
        return meta.code;
      }
    }
  }

  // 4. Default language
  return DEFAULT_LANGUAGE;
}

// Rate Limiter
export function checkRateLimit(clientIp: string, maxRequests = 100, windowMs = 60000): { allowed: boolean; remaining: number } {
  try {
    const db = getDb();
    const now = Date.now();
    const row = db.prepare('SELECT request_count, window_start FROM rate_limits WHERE client_key = ?').get(clientIp) as any;

    if (!row) {
      db.prepare('INSERT INTO rate_limits (client_key, request_count, window_start) VALUES (?, 1, ?)').run(clientIp, now);
      return { allowed: true, remaining: maxRequests - 1 };
    }

    if (now - row.window_start > windowMs) {
      // Window expired, reset
      db.prepare('UPDATE rate_limits SET request_count = 1, window_start = ? WHERE client_key = ?').run(now, clientIp);
      return { allowed: true, remaining: maxRequests - 1 };
    }

    if (row.request_count >= maxRequests) {
      return { allowed: false, remaining: 0 };
    }

    const newCount = row.request_count + 1;
    db.prepare('UPDATE rate_limits SET request_count = ? WHERE client_key = ?').run(newCount, clientIp);
    return { allowed: true, remaining: maxRequests - newCount };
  } catch (err) {
    console.warn('[RateLimit] Error executing rate limit:', err);
    return { allowed: true, remaining: 999 };
  }
}
