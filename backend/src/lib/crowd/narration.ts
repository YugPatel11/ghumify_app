
import { CrowdLevel } from './config';

export interface NarrationInputStop {
  placeId: string;
  name: string;
  category: string;
  suggestedStart: string;
  suggestedEnd: string;
  estimatedCrowdLevel: CrowdLevel | string;
  durationMinutes: number;
}

export interface NarrationInput {
  city: string;
  date: string;
  stops: NarrationInputStop[];
}

export interface StopNarration {
  placeId: string;
  name: string;
  description: string;
  tips: string[];
}

export interface NarrationResult {
  summary: string;
  stops: StopNarration[];
  source: 'gemini' | 'template_fallback';
}

export type GeminiCaller = (prompt: string, schema: any) => Promise<string>;

export const NARRATION_RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    summary: {
      type: 'STRING',
      description: 'Concise 1-2 sentence overall daily summary for sightseeing in the city.',
    },
    stops: {
      type: 'ARRAY',
      description: 'Exact list of stops matching the input order and names.',
      items: {
        type: 'OBJECT',
        properties: {
          placeId: { type: 'STRING', description: 'Exact placeId matching input' },
          name: { type: 'STRING', description: 'Exact name of the place' },
          description: {
            type: 'STRING',
            description: 'Engaging 1-2 sentence description of what to see and experience',
          },
          tips: {
            type: 'ARRAY',
            description: '2 practical tips tailored to timing and crowd conditions',
            items: { type: 'STRING' },
          },
        },
        required: ['placeId', 'name', 'description', 'tips'],
      },
    },
  },
  required: ['summary', 'stops'],
};

/**
 * Builds a strictly sanitized prompt containing ONLY selected stops, slots, order, and crowd labels.
 * NEVER includes userId, coordinates, device telemetry, or personal identity.
 */
export function buildSanitizedNarrationPrompt(input: NarrationInput): string {
  const sanitizedStops = input.stops.map((s, idx) => ({
    order: idx + 1,
    placeId: s.placeId,
    name: s.name,
    category: s.category,
    timeSlot: `${s.suggestedStart} - ${s.suggestedEnd}`,
    estimatedCrowdLevel: s.estimatedCrowdLevel,
  }));

  return `You are a helpful travel writer providing descriptions and tips for an itinerary in ${input.city} on ${input.date}.
The itinerary order, schedule, and crowd estimates are ALREADY FIXED and CANNOT be altered.
STRICT RULES:
1. Return descriptions and tips for EVERY stop in the EXACT order given below.
2. DO NOT alter stop order, replace stops, or invent new attractions.
3. Every stop's placeId and name must strictly match the input.
4. Output valid JSON adhering to the specified schema.

FIXED ITINERARY STOPS:
${JSON.stringify(sanitizedStops, null, 2)}`;
}

/**
 * Validates that every returned stop corresponds exactly to the input stop at the same index.
 * Rejects invented places, missing stops, reordered stops, or bad formats.
 */
export function validateNarrationOutput(
  rawJson: any,
  input: NarrationInput
): { valid: boolean; error?: string } {
  if (!rawJson || typeof rawJson !== 'object') {
    return { valid: false, error: 'Output is not a valid JSON object' };
  }

  if (typeof rawJson.summary !== 'string' || rawJson.summary.trim().length === 0) {
    return { valid: false, error: 'Missing or empty daily summary' };
  }

  if (!Array.isArray(rawJson.stops) || rawJson.stops.length !== input.stops.length) {
    return {
      valid: false,
      error: `Stop count mismatch: expected ${input.stops.length}, got ${rawJson.stops?.length}`,
    };
  }

  for (let i = 0; i < input.stops.length; i++) {
    const inputStop = input.stops[i];
    const outputStop = rawJson.stops[i];

    if (!outputStop || typeof outputStop !== 'object') {
      return { valid: false, error: `Stop at index ${i} is not an object` };
    }

    const idMatch =
      typeof outputStop.placeId === 'string' &&
      outputStop.placeId.trim() === inputStop.placeId.trim();

    const nameMatch =
      typeof outputStop.name === 'string' &&
      outputStop.name.trim().toLowerCase() === inputStop.name.trim().toLowerCase();

    // Must match either id or name at this exact slot position (rejects invented & reordered)
    if (!idMatch && !nameMatch) {
      return {
        valid: false,
        error: `Stop at index ${i} mismatch (invented or reordered): expected "${inputStop.name}" (${inputStop.placeId}), got "${outputStop.name}" (${outputStop.placeId})`,
      };
    }

    if (
      typeof outputStop.description !== 'string' ||
      outputStop.description.trim().length === 0
    ) {
      return { valid: false, error: `Stop at index ${i} missing description` };
    }

    if (!Array.isArray(outputStop.tips) || outputStop.tips.length === 0) {
      return { valid: false, error: `Stop at index ${i} missing tips array` };
    }
  }

  return { valid: true };
}

/**
 * Produces deterministic, safe fallback narration when Gemini fails or returns invalid data.
 */
export function generateTemplateFallback(input: NarrationInput): NarrationResult {
  const stopNames = input.stops.map((s) => s.name);
  const summary =
    input.stops.length > 0
      ? `A curated day in ${input.city} covering ${stopNames.slice(0, 3).join(', ')}${stopNames.length > 3 ? ' and more' : ''}, timed to avoid peak crowd periods.`
      : `An optimized day in ${input.city}.`;

  return {
    summary,
    source: 'template_fallback',
    stops: input.stops.map((s) => ({
      placeId: s.placeId,
      name: s.name,
      description: `Explore ${s.name}, a notable ${s.category} destination in ${input.city}, scheduled during ${s.suggestedStart} - ${s.suggestedEnd} (${s.estimatedCrowdLevel} crowd expected).`,
      tips: [
        `Optimal visit window: ${s.suggestedStart} - ${s.suggestedEnd}.`,
        'Keep comfortable walking shoes and stay hydrated.',
      ],
    })),
  };
}

function getGeminiKeys(): string[] {
  return [
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

function getGeminiModels(): string[] {
  const chain = process.env.GEMINI_MODEL_CHAIN || 'gemini-2.5-flash,gemini-1.5-flash';
  return chain.split(',').map((m) => m.trim()).filter(Boolean);
}

/**
 * Production Gemini caller using REST endpoint with schema constraint.
 */
async function defaultGeminiCaller(prompt: string, schema: any): Promise<string> {
  const keys = getGeminiKeys();
  const models = getGeminiModels();

  if (keys.length === 0) {
    throw new Error('No Gemini API keys configured');
  }

  let lastErr: Error | null = null;
  for (const model of models) {
    for (const key of keys) {
      try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.3,
              maxOutputTokens: 2048,
              responseMimeType: 'application/json',
              responseSchema: schema,
            },
          }),
          signal: AbortSignal.timeout(8000), // 8s timeout per provider
        });

        if (!res.ok) {
          lastErr = new Error(`Gemini status ${res.status}`);
          continue;
        }

        const data = await res.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text && text.trim().length > 0) {
          return text.trim();
        }
        lastErr = new Error('Empty Gemini response text');
      } catch (err: any) {
        lastErr = err;
      }
    }
  }

  throw lastErr || new Error('All Gemini keys failed');
}

/**
 * Narrates the finalized itinerary stops.
 * Retries once on failure, then falls back to template text.
 * The returned itinerary order, times, and crowd labels are NEVER changed.
 */
export async function narrateItinerary(
  input: NarrationInput,
  customCaller?: GeminiCaller
): Promise<NarrationResult> {
  if (input.stops.length === 0) {
    return generateTemplateFallback(input);
  }

  const prompt = buildSanitizedNarrationPrompt(input);
  const caller = customCaller || defaultGeminiCaller;

  let lastError: any = null;

  // Retry once on failure (total 2 attempts)
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const rawText = await caller(prompt, NARRATION_RESPONSE_SCHEMA);
      const cleanJson = rawText
        .replace(/^```json\s*/i, '')
        .replace(/```\s*$/i, '')
        .trim();

      const parsed = JSON.parse(cleanJson);
      const val = validateNarrationOutput(parsed, input);

      if (val.valid) {
        return {
          summary: parsed.summary.trim(),
          source: 'gemini',
          stops: input.stops.map((inputStop, idx) => {
            const out = parsed.stops[idx];
            return {
              placeId: inputStop.placeId,
              name: inputStop.name,
              description: String(out.description).trim(),
              tips: Array.isArray(out.tips)
                ? out.tips.map((t: any) => String(t).trim()).filter(Boolean)
                : [],
            };
          }),
        };
      } else {
        lastError = new Error(`Attempt ${attempt} validation failed: ${val.error}`);
      }
    } catch (err: any) {
      lastError = err;
    }
  }

  // Graceful degradation: fall back to template text
  console.warn(
    `[CrowdNarration] Gemini narration failed after 2 attempts (${lastError?.message || 'unknown error'}), using template fallback.`
  );
  return generateTemplateFallback(input);
}
