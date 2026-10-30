import { NextRequest, NextResponse } from 'next/server';
import { checkRateLimit, resolveLanguage } from '@/lib/language-resolution';
import { validateAudioData } from '@/lib/speech/audio-validator';
import { speechToTextService } from '@/lib/speech/stt-provider';

export async function POST(request: NextRequest) {
  const ip = request.headers.get('x-forwarded-for') || '127.0.0.1';

  // 1. Rate Limiting (40 STT requests/minute per IP)
  const rate = checkRateLimit(`stt_${ip}`, 40, 60000);
  if (!rate.allowed) {
    return NextResponse.json(
      { code: 'RATE_LIMIT_EXCEEDED', error: 'Too many speech transcription requests.' },
      { status: 429 }
    );
  }

  // 2. Authentication check
  const userId = request.headers.get('x-user-id') || request.headers.get('authorization') || 'user_demo';

  // 3. Resolve target spoken language
  const contentType = request.headers.get('content-type') || '';
  let audioBuffer: Buffer | null = null;
  let mimeType = 'audio/webm';
  let requestedLang: string | null = null;

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
      requestedLang = (formData.get('language') as string) || null;
      mimeType = file.type || 'audio/webm';
      const arrayBuffer = await file.arrayBuffer();
      audioBuffer = Buffer.from(arrayBuffer);
    } else {
      const body = await request.json();
      requestedLang = body.language || null;
      mimeType = body.mime_type || body.mimeType || 'audio/webm';
      if (body.audio_base64) {
        audioBuffer = Buffer.from(body.audio_base64, 'base64');
      }
    }
  } catch (err) {
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

  // 4. Validate audio data and MIME type
  const validation = validateAudioData(audioBuffer, mimeType);
  if (!validation.valid) {
    return NextResponse.json(
      { code: validation.errorCode, error: validation.error },
      { status: 400 }
    );
  }

  // 5. Language resolution
  const resolvedLang = requestedLang || resolveLanguage({
    userId,
    acceptLanguageHeader: request.headers.get('accept-language'),
    headerLang: request.headers.get('x-language'),
  });

  const startTime = Date.now();

  try {
    const result = await speechToTextService.transcribe(
      audioBuffer,
      validation.normalizedMime,
      resolvedLang
    );

    const durationMs = Date.now() - startTime;

    // Zero disk retention - audioBuffer automatically collected by V8 GC
    return NextResponse.json({
      success: true,
      text: result.text,
      language_detected: result.languageDetected || resolvedLang,
      confidence: result.confidence,
      duration_ms: durationMs,
      provider: result.provider,
    });
  } catch (err: any) {
    console.error('[SpeechTranscribeAPI] Transcription error:', err?.message || err);
    return NextResponse.json(
      { code: 'TRANSCRIPTION_FAILED', error: err?.message || 'Speech-to-text transcription failed.' },
      { status: 500 }
    );
  }
}
