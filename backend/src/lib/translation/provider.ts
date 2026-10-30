import crypto from 'node:crypto';
import { maskPlaceholders, restorePlaceholders } from './placeholder';

export interface TranslationProvider {
  name: string;
  isAvailable(): boolean;
  translateBatch(texts: string[], sourceLang: string, targetLang: string): Promise<string[]>;
}

export function computeSourceHash(text: string): string {
  return crypto.createHash('sha256').update(text).digest('hex');
}

// DeepL Provider
export class DeepLProvider implements TranslationProvider {
  name = 'deepl';
  private apiKey: string;
  private endpoint: string;

  constructor() {
    this.apiKey = process.env.DEEPL_API_KEY || process.env.GOOGLE_TRANSLATE_API_KEY || '';
    this.endpoint = this.apiKey.endsWith(':fx')
      ? 'https://api-free.deepl.com/v2/translate'
      : 'https://api.deepl.com/v2/translate';
  }

  isAvailable(): boolean {
    return Boolean(this.apiKey && this.apiKey.length > 5 && !this.apiKey.startsWith('YOUR_'));
  }

  private mapLang(lang: string): string {
    const l = lang.toLowerCase();
    const map: Record<string, string> = {
      en: 'EN',
      hi: 'HI',
      es: 'ES',
      fr: 'FR',
      de: 'DE',
      pt: 'PT-PT',
      ar: 'AR',
      zh: 'ZH',
      ja: 'JA',
      ru: 'RU',
    };
    return map[l] || l.toUpperCase();
  }

  async translateBatch(texts: string[], sourceLang: string, targetLang: string): Promise<string[]> {
    if (!this.isAvailable()) {
      throw new Error('DeepL provider is not configured.');
    }

    const maskedData = texts.map((t) => maskPlaceholders(t));
    const payload = {
      text: maskedData.map((m) => m.masked),
      source_lang: this.mapLang(sourceLang),
      target_lang: this.mapLang(targetLang),
      preserve_formatting: true,
    };

    const res = await fetch(this.endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `DeepL-Auth-Key ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errBody = await res.text().catch(() => '');
      throw new Error(`DeepL API error (${res.status}): ${errBody}`);
    }

    const data = await res.json();
    const results: string[] = [];

    for (let i = 0; i < texts.length; i++) {
      const translated = data.translations?.[i]?.text || maskedData[i].masked;
      const { text, intact } = restorePlaceholders(translated, maskedData[i].tokens);
      if (!intact) {
        console.warn(`[DeepL] Placeholders corrupted for text "${texts[i]}". Falling back to source.`);
        results.push(texts[i]);
      } else {
        results.push(text);
      }
    }

    return results;
  }
}

// Gemini Provider
export class GeminiProvider implements TranslationProvider {
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

  async translateBatch(texts: string[], sourceLang: string, targetLang: string): Promise<string[]> {
    if (!this.isAvailable()) {
      throw new Error('Gemini provider is not configured.');
    }

    const maskedData = texts.map((t) => maskPlaceholders(t));
    const prompt = `You are a professional localization engine for a travel app.
Translate the following JSON array of strings from ${sourceLang} to ${targetLang}.
Preserve all special tokens like __PH_0__, __TAG_0__, __URL_0__, etc. exactly without modification or space insertion.
Output ONLY a raw valid JSON array of strings in the exact same length and order, with no markdown code fences and no extra text.

Input strings:
${JSON.stringify(maskedData.map((m) => m.masked))}`;

    let lastError: Error | null = null;

    // Try keys sequentially
    for (const key of this.keys) {
      try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${key}`;
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.1,
              responseMimeType: 'application/json',
            },
          }),
        });

        if (!res.ok) {
          const errText = await res.text().catch(() => '');
          lastError = new Error(`Gemini error (${res.status}): ${errText}`);
          continue;
        }

        const data = await res.json();
        const candidateText = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!candidateText) {
          lastError = new Error('Empty Gemini response');
          continue;
        }

        const cleaned = candidateText.trim().replace(/^```json/i, '').replace(/```$/i, '').trim();
        const parsed = JSON.parse(cleaned);

        if (!Array.isArray(parsed) || parsed.length !== texts.length) {
          lastError = new Error('Mismatched translation output length');
          continue;
        }

        const results: string[] = [];
        for (let i = 0; i < texts.length; i++) {
          const raw = String(parsed[i]);
          const { text, intact } = restorePlaceholders(raw, maskedData[i].tokens);
          results.push(intact ? text : texts[i]);
        }
        return results;
      } catch (err: any) {
        lastError = err;
      }
    }

    throw lastError || new Error('All Gemini keys failed.');
  }
}

// Composite Provider with In-Flight Request De-duplication and Circuit Breaker
export class CompositeTranslationService {
  private deepl = new DeepLProvider();
  private gemini = new GeminiProvider();
  private inFlight = new Map<string, Promise<string[]>>();
  private consecutiveFailures = 0;
  private circuitOpenUntil = 0;

  async translateBatchWithFallback(
    texts: string[],
    sourceLang: string,
    targetLang: string
  ): Promise<{ results: string[]; provider: string }> {
    if (texts.length === 0 || sourceLang.toLowerCase() === targetLang.toLowerCase()) {
      return { results: texts, provider: 'identity' };
    }

    // Circuit breaker check
    const now = Date.now();
    if (now < this.circuitOpenUntil) {
      console.warn('[CircuitBreaker] Circuit is OPEN. Falling back to source text.');
      return { results: texts, provider: 'fallback_circuit_open' };
    }

    // De-duplication key
    const flightKey = `${sourceLang}->${targetLang}:${texts.join('|||')}`;
    if (this.inFlight.has(flightKey)) {
      const results = await this.inFlight.get(flightKey)!;
      return { results, provider: 'cached_inflight' };
    }

    const task = (async () => {
      // 1. Try DeepL if available and target is supported
      if (this.deepl.isAvailable()) {
        try {
          const res = await this.deepl.translateBatch(texts, sourceLang, targetLang);
          this.consecutiveFailures = 0;
          return { results: res, provider: 'deepl' };
        } catch (err) {
          console.warn('[Translate] DeepL failed, trying Gemini:', err);
        }
      }

      // 2. Try Gemini
      if (this.gemini.isAvailable()) {
        try {
          const res = await this.gemini.translateBatch(texts, sourceLang, targetLang);
          this.consecutiveFailures = 0;
          return { results: res, provider: 'gemini' };
        } catch (err) {
          console.warn('[Translate] Gemini failed:', err);
        }
      }

      // 3. Fallback to source
      this.consecutiveFailures++;
      if (this.consecutiveFailures >= 5) {
        this.circuitOpenUntil = Date.now() + 30000; // Open for 30 seconds
      }
      return { results: texts, provider: 'fallback_source' };
    })();

    this.inFlight.set(flightKey, task.then((r) => r.results));
    try {
      return await task;
    } finally {
      this.inFlight.delete(flightKey);
    }
  }
}

export const translationService = new CompositeTranslationService();
