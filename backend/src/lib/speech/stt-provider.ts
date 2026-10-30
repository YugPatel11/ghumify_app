import { getSpeechLocale } from './locale-map';
import { sanitizeTranscript } from './audio-validator';

export interface TranscriptionResult {
  text: string;
  languageDetected?: string;
  confidence: number;
  durationMs?: number;
  provider: string;
}

export interface SpeechToTextProvider {
  name: string;
  isAvailable(): boolean;
  transcribe(
    audioBuffer: Buffer,
    mimeType: string,
    languageCode?: string
  ): Promise<TranscriptionResult>;
}

// 1. Sarvam AI Provider (Specialized in Indic Speech)
export class SarvamSTTProvider implements SpeechToTextProvider {
  name = 'sarvam';
  private apiKey: string;

  constructor() {
    this.apiKey = process.env.SARVAM_API_KEY || '';
  }

  isAvailable(): boolean {
    return Boolean(this.apiKey && this.apiKey.length > 5 && !this.apiKey.startsWith('YOUR_'));
  }

  async transcribe(
    audioBuffer: Buffer,
    mimeType: string,
    languageCode: string = 'en'
  ): Promise<TranscriptionResult> {
    if (!this.isAvailable()) {
      throw new Error('Sarvam AI STT is not configured.');
    }

    const locale = getSpeechLocale(languageCode);
    const formData = new FormData();
    const blob = new Blob([new Uint8Array(audioBuffer)], { type: mimeType });
    formData.append('file', blob, 'audio.wav');
    formData.append('language_code', locale.split('-')[0]);
    formData.append('model', 'saarika:v2');

    const res = await fetch('https://api.sarvam.ai/speech-to-text', {
      method: 'POST',
      headers: {
        'api-subscription-key': this.apiKey,
      },
      body: formData,
    });

    if (!res.ok) {
      const err = await res.text().catch(() => '');
      throw new Error(`Sarvam STT failed (${res.status}): ${err}`);
    }

    const json = await res.json();
    return {
      text: sanitizeTranscript(json.transcript || ''),
      languageDetected: json.language_code || languageCode,
      confidence: 0.95,
      provider: 'sarvam',
    };
  }
}

// 2. Gemini 2.5 Flash Audio Provider
export class GeminiSTTProvider implements SpeechToTextProvider {
  name = 'gemini';
  private keys: string[];

  constructor() {
    this.keys = [
      process.env.GEMINI_API_KEY_1,
      process.env.GEMINI_API_KEY_2,
      process.env.GEMINI_API_KEY_3,
      process.env.GEMINI_API_KEY_4,
      process.env.GEMINI_API_KEY_5,
      process.env.GEMINI_API_KEY_6,
      process.env.GEMINI_API_KEY_7,
      process.env.GEMINI_API_KEY_8,
      process.env.GEMINI_API_KEY,
    ].filter((k): k is string => Boolean(k && k.length > 5 && !k.startsWith('YOUR_')));
  }

  isAvailable(): boolean {
    return this.keys.length > 0;
  }

  async transcribe(
    audioBuffer: Buffer,
    mimeType: string,
    languageCode: string = 'en'
  ): Promise<TranscriptionResult> {
    if (!this.isAvailable()) {
      throw new Error('Gemini STT provider is not configured.');
    }

    const base64Data = audioBuffer.toString('base64');
    const prompt = `You are an accurate, real-time speech-to-text engine for a travel companion app.
Listen carefully to the audio and transcribe exactly what is spoken.
The expected language or dialect hint is: "${languageCode}". If the speaker is speaking a different language, transcribe in that spoken language.
Output ONLY a JSON object with this exact format:
{
  "transcript": "the exact transcribed text",
  "language_detected": "language code such as en, hi, es, fr, ar, ur, etc.",
  "confidence": 0.95
}
Do NOT add explanations, formatting or markdown codeblocks.`;

    let lastError: Error | null = null;

    for (const key of this.keys) {
      try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${key}`;
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  { text: prompt },
                  {
                    inlineData: {
                      mimeType: mimeType.split(';')[0],
                      data: base64Data,
                    },
                  },
                ],
              },
            ],
            generationConfig: {
              temperature: 0.0,
              responseMimeType: 'application/json',
            },
          }),
        });

        if (!res.ok) {
          const errText = await res.text().catch(() => '');
          lastError = new Error(`Gemini audio STT error (${res.status}): ${errText}`);
          continue;
        }

        const data = await res.json();
        const candidate = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!candidate) {
          lastError = new Error('Empty transcript from Gemini');
          continue;
        }

        const cleaned = candidate.trim().replace(/^```json/i, '').replace(/```$/i, '').trim();
        const parsed = JSON.parse(cleaned);

        return {
          text: sanitizeTranscript(parsed.transcript || ''),
          languageDetected: parsed.language_detected || languageCode,
          confidence: typeof parsed.confidence === 'number' ? parsed.confidence : 0.92,
          provider: 'gemini',
        };
      } catch (err: any) {
        lastError = err;
      }
    }

    throw lastError || new Error('All Gemini keys failed during transcription.');
  }
}

// 3. Composite STT Service
export class CompositeSTTService {
  private sarvam = new SarvamSTTProvider();
  private gemini = new GeminiSTTProvider();

  async transcribe(
    audioBuffer: Buffer,
    mimeType: string,
    languageCode: string = 'en'
  ): Promise<TranscriptionResult> {
    const isIndic = ['hi', 'gu', 'mr', 'bn', 'ta', 'te', 'kn', 'ml', 'pa', 'ur'].includes(languageCode);

    // 1. If Sarvam is configured and language is Indic, try Sarvam first
    if (isIndic && this.sarvam.isAvailable()) {
      try {
        return await this.sarvam.transcribe(audioBuffer, mimeType, languageCode);
      } catch (err) {
        console.warn('[STT] Sarvam provider failed, falling back to Gemini:', err);
      }
    }

    // 2. Try Gemini
    if (this.gemini.isAvailable()) {
      return await this.gemini.transcribe(audioBuffer, mimeType, languageCode);
    }

    // 3. Try Sarvam for non-Indic if Gemini unavailable
    if (this.sarvam.isAvailable()) {
      return await this.sarvam.transcribe(audioBuffer, mimeType, languageCode);
    }

    throw new Error('No Speech-to-Text provider is available or configured.');
  }
}

export const speechToTextService = new CompositeSTTService();
