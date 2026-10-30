import { NextRequest, NextResponse } from 'next/server';
import { aiRouter, GenerateItineraryRequest } from '@/lib/ai/ai-router';
import { verifyAuthToken } from '@/lib/auth/firebase-auth';
import { checkRateLimit } from '@/lib/language-resolution';

export async function POST(request: NextRequest) {
  // 1. Verify Authentication
  const authHeader = request.headers.get('authorization');
  const auth = await verifyAuthToken(authHeader);
  if (!auth.valid) {
    return NextResponse.json(
      { code: 'UNAUTHORIZED', error: auth.error || 'Authentication required.' },
      { status: 401 }
    );
  }

  const userId = auth.userId || 'user_demo';

  // 2. Per-user Rate Limiting (30 requests/minute)
  const rate = checkRateLimit(`ai_gen_${userId}`, 30, 60000);
  if (!rate.allowed) {
    return NextResponse.json(
      { code: 'RATE_LIMIT_EXCEEDED', error: 'Too many requests. Please wait a moment.' },
      { status: 429 }
    );
  }

  // 3. Parse Body
  let body: any;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { code: 'INVALID_JSON', error: 'Invalid JSON request payload.' },
      { status: 400 }
    );
  }

  const {
    city,
    prompt,
    taskType,
    conversationHistory,
    isMultiDay,
    date,
    startDate,
    endDate,
    numberOfDays,
    startTime,
    endTime,
    dailyStartTime,
    dailyEndTime,
    interests,
    travelMode,
    pace,
    age,
    travelers,
    budget,
  } = body || {};

  if (!prompt || typeof prompt !== 'string') {
    return NextResponse.json(
      { code: 'MISSING_PROMPT', error: 'Field "prompt" is required.' },
      { status: 400 }
    );
  }

  const req: GenerateItineraryRequest = {
    city: city || 'Local City',
    prompt,
    taskType,
    conversationHistory,
    isMultiDay,
    date,
    startDate,
    endDate,
    numberOfDays,
    startTime,
    endTime,
    dailyStartTime,
    dailyEndTime,
    interests,
    travelMode,
    pace,
    age,
    travelers,
    budget,
    userId,
  };

  try {
    const outcome = await aiRouter.generate(req);

    // Format response content
    const responsePayload =
      typeof outcome.result === 'string'
        ? outcome.result
        : outcome.result;

    const response = NextResponse.json(responsePayload);

    // Set required metadata headers
    response.headers.set('X-AI-Provider', outcome.provider);
    response.headers.set('X-AI-Degraded', String(outcome.isDegraded));
    response.headers.set('X-AI-Cached', String(outcome.isCached));
    response.headers.set('X-Places-Stale', String(outcome.isPlacesStale));

    return response;
  } catch (error: any) {
    console.error('[AIGenerateRoute] Failure:', error?.message || error);
    return NextResponse.json(
      {
        code: 'GENERATION_FAILED',
        error: error?.message || 'Failed to generate content with AI router.',
      },
      { status: 500 }
    );
  }
}

