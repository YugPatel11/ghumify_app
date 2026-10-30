import { NextRequest, NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { SUPPORTED_LANGUAGES } from '@/lib/languages';
import { SOURCE_CATALOG } from '@/lib/source-catalog';
import { computeSourceHash, translationService } from '@/lib/translation/provider';

export async function POST(request: NextRequest) {
  let body: any = {};
  try {
    body = await request.json();
  } catch {}

  const { action = 'prewarm', languages } = body;
  const db = getDb();

  if (action === 'purge') {
    db.prepare('DELETE FROM translations WHERE is_manual = 0').run();
    return NextResponse.json({
      success: true,
      message: 'Automatic translation cache purged successfully.',
    });
  }

  if (action === 'prewarm') {
    const targetLangs = Array.isArray(languages) && languages.length > 0
      ? languages
      : SUPPORTED_LANGUAGES.filter((l) => l.enabled && l.code !== 'en').map((l) => l.code);

    const report: Record<string, number> = {};

    for (const lang of targetLangs) {
      const texts = SOURCE_CATALOG.map((i) => i.text);
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

      let count = 0;
      for (let i = 0; i < SOURCE_CATALOG.length; i++) {
        const item = SOURCE_CATALOG[i];
        const hash = computeSourceHash(item.text);
        const translated = results[i] || item.text;
        const id = `${item.key}_${lang}`;

        try {
          insertOrUpdate.run(
            id,
            item.namespace,
            item.key,
            hash,
            item.text,
            lang,
            translated,
            provider,
            now,
            now
          );
          count++;
        } catch {}
      }
      report[lang] = count;
    }

    return NextResponse.json({
      success: true,
      message: 'Translations pre-warmed successfully.',
      prewarmed: report,
    });
  }

  return NextResponse.json(
    { code: 'INVALID_ACTION', error: 'Action must be "prewarm" or "purge".' },
    { status: 400 }
  );
}
