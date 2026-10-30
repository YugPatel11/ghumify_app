import crypto from 'node:crypto';
import { CircuitBreaker } from '../circuit-breaker';
import { Place } from '../schemas/place';
import {
  RawSingleDayAIOutput,
  RawSingleDayAIOutputSchema,
} from '../schemas/itinerary';
import {
  RawMultiDayAIOutput,
  RawMultiDayAIOutputSchema,
} from '../schemas/multi-day-itinerary';
import { placesRouter } from '../places/places-router';
import { PlanOptions, rulePlanner } from '../planner/rule-planner';
import { buildGroundedPlacesSection, verifyStopsGrounded } from './grounding';
import { AIProvider, AIRouteResult, AITaskType } from './types';
import { GeminiAIProvider } from './gemini-provider';
import { GroqAIProvider } from './groq-provider';
import { OpenRouterAIProvider } from './openrouter-provider';
import { getItineraryFromCache, setItineraryInCache } from '../cache';

export interface GenerateItineraryRequest {
  city: string;
  isMultiDay?: boolean;
  startDate?: string;
  endDate?: string;
  numberOfDays?: number;
  date?: string;
  startTime?: string;
  endTime?: string;
  dailyStartTime?: string;
  dailyEndTime?: string;
  interests?: string[];
  travelMode?: string;
  pace?: string;
  age?: number | null;
  travelers?: number | null;
  budget?: number | null;
  userId?: string;
  prompt: string;
  taskType?: AITaskType;
  conversationHistory?: Array<{ role: string; content: string }>;
}

export class AIRouter {
  private providers = new Map<string, AIProvider>();
  private circuitBreaker = new CircuitBreaker({ failureThreshold: 3, cooldownMs: 60000 });

  constructor() {
    this.registerProvider(new GeminiAIProvider());
    this.registerProvider(new GroqAIProvider());
    this.registerProvider(new OpenRouterAIProvider());
  }

  registerProvider(provider: AIProvider) {
    this.providers.set(provider.name, provider);
  }

  private getProviderOrder(): string[] {
    const orderEnv = process.env.AI_PROVIDER_ORDER || 'gemini,groq,openrouter';
    return orderEnv
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .filter((name) => this.providers.has(name));
  }

  private cleanJsonString(raw: string): string {
    let clean = raw.trim();
    if (clean.startsWith('```json')) {
      clean = clean.substring(7);
    } else if (clean.startsWith('```')) {
      clean = clean.substring(3);
    }
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
    return clean.trim();
  }

  private computeInputHash(req: GenerateItineraryRequest): string {
    const normalized = {
      city: req.city.trim().toLowerCase(),
      isMultiDay: Boolean(req.isMultiDay),
      numberOfDays: req.numberOfDays || 1,
      startTime: req.startTime || req.dailyStartTime || '09:00',
      endTime: req.endTime || req.dailyEndTime || '18:00',
      interests: [...(req.interests || [])].sort(),
      travelMode: req.travelMode || 'driving',
      pace: req.pace || 'moderate',
      budget: req.budget || 0,
      age: req.age || null,
    };
    return crypto.createHash('sha256').update(JSON.stringify(normalized)).digest('hex');
  }

  async generate(req: GenerateItineraryRequest): Promise<{
    result: any;
    provider: string;
    isDegraded: boolean;
    isCached: boolean;
    isPlacesStale: boolean;
  }> {
    const isItinerary =
      req.prompt.includes('"stops"') ||
      req.prompt.includes('itinerary') ||
      req.taskType === 'complexPlanning';

    const inputHash = this.computeInputHash(req);

    // 1. If not an itinerary task (e.g. general question, chat, place info), handle via normal AI chain
    if (!isItinerary) {
      const nonItineraryResult = await this.executeNonItinerary(req);
      return {
        result: nonItineraryResult.content,
        provider: nonItineraryResult.provider,
        isDegraded: false,
        isCached: false,
        isPlacesStale: false,
      };
    }

    // 2. Fetch real candidate places from PlacesRouter
    let candidates: Place[] = [];
    let isPlacesStale = false;
    try {
      const placesRes = await placesRouter.search({ city: req.city, limit: 35 });
      candidates = placesRes.data;
      isPlacesStale = placesRes.isStale;
    } catch (err) {
      console.warn('[AIRouter] PlacesRouter failed to find candidate places:', err);
    }

    // 3. Grounded prompt with candidates
    const groundedSection = buildGroundedPlacesSection(candidates);
    const fullPrompt = `${req.prompt}\n\n${groundedSection}`;

    // 4. Try AI Provider Chain
    const providerOrder = this.getProviderOrder();
    const taskType = req.taskType || 'complexPlanning';

    for (const name of providerOrder) {
      const provider = this.providers.get(name);
      if (!provider || !provider.isAvailable()) continue;
      if (!this.circuitBreaker.isAvailable(name)) continue;

      try {
        let rawOutput = await provider.generate(fullPrompt, taskType, req.conversationHistory);
        let parsed = this.parseAndValidate(rawOutput, req.isMultiDay, candidates);

        // If validation failed, try ONE repair attempt on the same provider
        if (!parsed.valid) {
          console.warn(`[AIRouter] ${name} validation failed: ${parsed.error}. Attempting repair.`);
          const repairPrompt = `${fullPrompt}\n\nERROR IN PREVIOUS ATTEMPT:\n${parsed.error}\nStrictly fix this and output valid JSON only.`;
          try {
            rawOutput = await provider.generate(repairPrompt, taskType, req.conversationHistory);
            parsed = this.parseAndValidate(rawOutput, req.isMultiDay, candidates);
          } catch (repairErr) {
            console.warn(`[AIRouter] ${name} repair attempt threw:`, repairErr);
          }
        }

        if (parsed.valid && parsed.data) {
          this.circuitBreaker.recordSuccess(name);
          // Cache finished itinerary
          await setItineraryInCache(inputHash, parsed.data);
          return {
            result: parsed.data,
            provider: name,
            isDegraded: false,
            isCached: false,
            isPlacesStale,
          };
        } else {
          console.warn(`[AIRouter] ${name} output remained invalid after repair.`);
          this.circuitBreaker.recordFailure(name);
        }
      } catch (err: any) {
        console.warn(`[AIRouter] ${name} error:`, err?.message || err);
        this.circuitBreaker.recordFailure(name);
      }
    }

    // 5. All AI providers failed -> Use Rule-Based Planner (last AI-free layer)
    console.warn('[AIRouter] All AI providers failed. Falling back to Rule-Based Planner.');
    const planOptions: PlanOptions = {
      city: req.city,
      date: req.date,
      startDate: req.startDate,
      endDate: req.endDate,
      numberOfDays: req.numberOfDays,
      startTime: req.startTime || req.dailyStartTime || '09:00',
      endTime: req.endTime || req.dailyEndTime || '18:00',
      interests: req.interests || [],
      travelMode: req.travelMode || 'driving',
      pace: req.pace || 'moderate',
      age: req.age,
      travelers: req.travelers,
      budget: req.budget,
      userId: req.userId,
    };

    if (candidates.length > 0) {
      const planned = req.isMultiDay
        ? rulePlanner.planMultiDay(candidates, planOptions)
        : rulePlanner.planSingleDay(candidates, planOptions);

      // Cache the rule-planned itinerary
      await setItineraryInCache(inputHash, planned);

      return {
        result: planned,
        provider: 'rule-planner',
        isDegraded: true,
        isCached: false,
        isPlacesStale,
      };
    }

    // 6. If even candidates were missing, check if stale itinerary cache exists
    const staleCached = await getItineraryFromCache(inputHash);
    if (staleCached && staleCached.data) {
      console.warn('[AIRouter] Serving stale cached itinerary');
      return {
        result: staleCached.data,
        provider: 'stale-cache',
        isDegraded: true,
        isCached: true,
        isPlacesStale: true,
      };
    }

    throw new Error('All AI providers and rule-based planner failed to generate itinerary.');
  }

  private parseAndValidate(
    rawText: string,
    isMultiDay: boolean | undefined,
    candidates: Place[]
  ): { valid: boolean; data?: any; error?: string } {
    try {
      const clean = this.cleanJsonString(rawText);
      const json = JSON.parse(clean);

      if (isMultiDay) {
        const validated = RawMultiDayAIOutputSchema.parse(json);
        // Verify stops across all days
        for (const day of validated.days) {
          const grounding = verifyStopsGrounded(day.stops, candidates);
          if (!grounding.valid) {
            return {
              valid: false,
              error: `Invented stops detected on Day ${day.dayNumber}: ${grounding.inventedStops.join(', ')}`,
            };
          }
        }
        return { valid: true, data: validated };
      } else {
        const validated = RawSingleDayAIOutputSchema.parse(json);
        const grounding = verifyStopsGrounded(validated.stops, candidates);
        if (!grounding.valid) {
          return {
            valid: false,
            error: `Invented stops detected: ${grounding.inventedStops.join(', ')}`,
          };
        }
        return { valid: true, data: validated };
      }
    } catch (e: any) {
      return { valid: false, error: e?.message || 'JSON schema validation failed' };
    }
  }

  private async executeNonItinerary(req: GenerateItineraryRequest): Promise<AIRouteResult> {
    const providerOrder = this.getProviderOrder();
    const taskType = req.taskType || 'chat';

    for (const name of providerOrder) {
      const provider = this.providers.get(name);
      if (!provider || !provider.isAvailable()) continue;
      if (!this.circuitBreaker.isAvailable(name)) continue;

      try {
        const text = await provider.generate(req.prompt, taskType, req.conversationHistory);
        if (text && text.trim().length > 0) {
          this.circuitBreaker.recordSuccess(name);
          return { content: text.trim(), provider: name, isDegraded: false };
        }
      } catch (err) {
        this.circuitBreaker.recordFailure(name);
      }
    }

    throw new Error('All AI providers failed for non-itinerary request.');
  }
}

export const aiRouter = new AIRouter();

