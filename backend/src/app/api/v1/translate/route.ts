import { NextRequest, NextResponse } from 'next/server';
import { isLanguageSupported } from '@/lib/languages';
import { checkRateLimit } from '@/lib/language-resolution';
import { translationService } from '@/lib/translation/provider';

const MAX_BATCH_SIZE = 50;
const MAX_TOTAL_CHARS = 10000;

export async function POST(request: NextRequest) {
  const ip = request.headers.get('x-forwarded-for') || '127.0.0.1';

  // 1. Rate limiting
  const rate = checkRateLimit(ip, 60, 60000);
  if (!rate.allowed) {
    return NextResponse.json(
      { code: 'RATE_LIMIT_EXCEEDED', error: 'Too many translation requests.' },
      { status: 429 }
    );
  }

  // 2. Parse and validate body
  let body: any;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { code: 'INVALID_JSON', error: 'Invalid JSON request payload.' },
      { status: 400 }
    );
  }

  const { texts, target_lang, source_lang = 'en' } = body || {};

  if (!Array.isArray(texts) || texts.length === 0) {
    return NextResponse.json(
      { code: 'INVALID_INPUT', error: 'Field "texts" must be a non-empty array of strings.' },
      { status: 400 }
    );
  }

  if (texts.length > MAX_BATCH_SIZE) {
    return NextResponse.json(
      { code: 'BATCH_TOO_LARGE', error: `Batch size exceeds limit of ${MAX_BATCH_SIZE} items.` },
      { status: 400 }
    );
  }

  const sanitizedTexts = texts.map((t) => (typeof t === 'string' ? t.trim() : ''));
  const totalChars = sanitizedTexts.reduce((acc, t) => acc + t.length, 0);

  if (totalChars > MAX_TOTAL_CHARS) {
    return NextResponse.json(
      { code: 'CHAR_LIMIT_EXCEEDED', error: `Total characters exceed limit of ${MAX_TOTAL_CHARS}.` },
      { status: 400 }
    );
  }

  if (!isLanguageSupported(target_lang)) {
    return NextResponse.json(
      { code: 'UNSUPPORTED_LANGUAGE', error: `Target language "${target_lang}" is not supported.` },
      { status: 400 }
    );
  }

  try {
    const { results, provider } = await translationService.translateBatchWithFallback(
      sanitizedTexts,
      source_lang,
      target_lang
    );

    return NextResponse.json({
      success: true,
      source_lang,
      target_lang,
      count: results.length,
      translations: results,
      provider,
    });
  } catch (err: any) {
    console.error('[TranslateAPI] Translation error:', err);
    return NextResponse.json(
      { code: 'TRANSLATION_FAILED', error: 'Translation provider failed.', fallback: sanitizedTexts },
      { status: 500 }
    );
  }
}
