import { NextRequest, NextResponse } from 'next/server';
import { checkRateLimit, resolveLanguage } from '@/lib/language-resolution';
import { validateAudioData } from '@/lib/speech/audio-validator';
import { speechToTextService } from '@/lib/speech/stt-provider';
import { translationService } from '@/lib/translation/provider';
import { isLanguageSupported } from '@/lib/languages';

export async function POST(request: NextRequest) {
  const ip = request.headers.get('x-forwarded-for') || '127.0.0.1';

  // 1. Rate Limiting
  const rate = checkRateLimit(`stt_trans_${ip}`, 30, 60000);
  if (!rate.allowed) {
    return NextResponse.json(
      { code: 'RATE_LIMIT_EXCEEDED', error: 'Too many speech-to-translate requests.' },
      { status: 429 }
    );
  }

  const userId = request.headers.get('x-user-id') || 'user_demo';
  const contentType = request.headers.get('content-type') || '';
  let audioBuffer: Buffer | null = null;
  let mimeType = 'audio/webm';
  let sourceLang: string | null = null;
  let targetLang: string | null = null;

  try {
    if (contentType.includes('multipart/form-data')) {
      const formData = await request.formData();
      const file = (formData.get('file') || formData.get('audio')) as File | null;
      if (!file) {
        return NextResponse.json(
          { code: 'MISSING_FILE', error: 'No audio file provided in form data.' },
          { status: 400 }
        );
      }
      sourceLang = (formData.get('source_lang') || formData.get('language')) as string | null;
      targetLang = formData.get('target_lang') as string | null;
      mimeType = file.type || 'audio/webm';
      const arrayBuffer = await file.arrayBuffer();
      audioBuffer = Buffer.from(arrayBuffer);
    } else {
      const body = await request.json();
      sourceLang = body.source_lang || body.language || null;
      targetLang = body.target_lang || null;
      mimeType = body.mime_type || body.mimeType || 'audio/webm';
      if (body.audio_base64) {
        audioBuffer = Buffer.from(body.audio_base64, 'base64');
      }
    }
  } catch {
    return NextResponse.json(
      { code: 'INVALID_PAYLOAD', error: 'Failed to parse request audio payload.' },
      { status: 400 }
    );
  }

  if (!audioBuffer) {
    return NextResponse.json(
      { code: 'EMPTY_AUDIO', error: 'Audio data is missing or empty.' },
      { status: 400 }
    );
  }

  if (!targetLang || !isLanguageSupported(targetLang)) {
    return NextResponse.json(
      { code: 'INVALID_TARGET_LANG', error: `Target language "${targetLang}" is invalid or unsupported.` },
      { status: 400 }
    );
  }

  const validation = validateAudioData(audioBuffer, mimeType);
  if (!validation.valid) {
    return NextResponse.json(
      { code: validation.errorCode, error: validation.error },
      { status: 400 }
    );
  }

  const resolvedSource = sourceLang || resolveLanguage({
    userId,
    acceptLanguageHeader: request.headers.get('accept-language'),
  });

  try {
    // 1. Transcribe speech
    const transcriptRes = await speechToTextService.transcribe(
      audioBuffer,
      validation.normalizedMime,
      resolvedSource
    );

    const spokenText = transcriptRes.text;

    // 2. Translate transcribed text to target language
    let translatedText = spokenText;
    let translationProvider = 'none';

    if (spokenText && spokenText.trim().length > 0) {
      const detectedOrSource = transcriptRes.languageDetected || resolvedSource;
      const transRes = await translationService.translateBatchWithFallback(
        [spokenText],
        detectedOrSource,
        targetLang
      );
      translatedText = transRes.results[0] || spokenText;
      translationProvider = transRes.provider;
    }

    return NextResponse.json({
      success: true,
      transcript: spokenText,
      translation: translatedText,
      source_lang: transcriptRes.languageDetected || resolvedSource,
      target_lang: targetLang,
      confidence: transcriptRes.confidence,
      stt_provider: transcriptRes.provider,
      translation_provider: translationProvider,
    });
  } catch (err: any) {
    console.error('[SpeechTranscribeTranslateAPI] Error:', err?.message || err);
    return NextResponse.json(
      { code: 'PIPELINE_FAILED', error: err?.message || 'Speech-to-translation pipeline failed.' },
      { status: 500 }
    );
  }
}
