import { NextRequest, NextResponse } from 'next/server';
import crypto from 'node:crypto';
import { getDb } from '@/lib/db';
import { isLanguageSupported } from '@/lib/languages';
import { SOURCE_CATALOG } from '@/lib/source-catalog';
import { computeSourceHash, translationService } from '@/lib/translation/provider';
import { checkRateLimit } from '@/lib/language-resolution';

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ lang: string }> }
) {
  const { lang } = await context.params;
  const ip = request.headers.get('x-forwarded-for') || '127.0.0.1';

  // Rate check
  const rate = checkRateLimit(ip, 120, 60000);
  if (!rate.allowed) {
    return NextResponse.json(
      { code: 'RATE_LIMIT_EXCEEDED', error: 'Too many translation requests.' },
      { status: 429 }
    );
  }

  if (!isLanguageSupported(lang)) {
    return NextResponse.json(
      { code: 'UNSUPPORTED_LANGUAGE', error: `Language "${lang}" is not supported.` },
      { status: 400 }
    );
  }

  const url = new URL(request.url);
  const namespace = url.searchParams.get('namespace');

  // Filter items from source catalog
  const catalog = namespace
    ? SOURCE_CATALOG.filter((i) => i.namespace === namespace)
    : SOURCE_CATALOG;

  const db = getDb();
  const translations: Record<string, string> = {};

  if (lang.toLowerCase() === 'en') {
    for (const item of catalog) {
      translations[item.key] = item.text;
    }
  } else {
    // 1. Fetch existing cached translations from SQLite
    const stmt = db.prepare(`
      SELECT key, translated_text, source_hash, is_manual 
      FROM translations 
      WHERE language = ?
    `);
    const rows = stmt.all(lang) as any[];
    const cachedMap = new Map<string, { text: string; hash: string; isManual: boolean }>();
    for (const r of rows) {
      cachedMap.set(r.key, {
        text: r.translated_text,
        hash: r.source_hash,
        isManual: Boolean(r.is_manual),
      });
    }

    // 2. Identify missing or stale keys
    const toTranslate: { item: typeof SOURCE_CATALOG[0]; hash: string }[] = [];
    for (const item of catalog) {
      const currentHash = computeSourceHash(item.text);
      const cached = cachedMap.get(item.key);

      if (cached && (cached.isManual || cached.hash === currentHash)) {
        translations[item.key] = cached.text;
      } else {
        toTranslate.push({ item, hash: currentHash });
      }
    }

    // 3. Translate missing on demand
    if (toTranslate.length > 0) {
      const texts = toTranslate.map((t) => t.item.text);
      const { results, provider } = await translationService.translateBatchWithFallback(
        texts,
        'en',
        lang
      );

      const now = new Date().toISOString();
      const insertOrUpdate = db.prepare(`
        INSERT INTO translations (id, namespace, key, source_hash, source_text, language, translated_text, provider, is_manual, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
        ON CONFLICT(key, language) DO UPDATE SET
          translated_text = excluded.translated_text,
          source_hash = excluded.source_hash,
          source_text = excluded.source_text,
          provider = excluded.provider,
          updated_at = excluded.updated_at
        WHERE is_manual = 0
      `);

      for (let i = 0; i < toTranslate.length; i++) {
        const item = toTranslate[i].item;
        const hash = toTranslate[i].hash;
        const translatedText = results[i] || item.text;
        const id = `${item.key}_${lang}`;

        try {
          insertOrUpdate.run(
            id,
            item.namespace,
            item.key,
            hash,
            item.text,
            lang,
            translatedText,
            provider,
            now,
            now
          );
        } catch (err) {
          console.warn(`[TranslationsAPI] Failed to cache key ${item.key}:`, err);
        }

        translations[item.key] = translatedText;
      }
    }
  }

  // Generate ETag based on response content
  const payloadString = JSON.stringify(translations);
  const etag = `"${crypto.createHash('md5').update(payloadString).digest('hex')}"`;

  // Check If-None-Match header
  const ifNoneMatch = request.headers.get('if-none-match');
  if (ifNoneMatch === etag) {
    return new NextResponse(null, {
      status: 304,
      headers: {
        'ETag': etag,
        'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400',
      },
    });
  }

  return NextResponse.json(
    {
      success: true,
      language: lang,
      count: Object.keys(translations).length,
      translations,
    },
    {
      headers: {
        'ETag': etag,
        'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400',
      },
    }
  );
}
