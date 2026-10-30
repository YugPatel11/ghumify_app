import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { verifyAuthToken } from '@/lib/auth/firebase-auth';
import { checkRateLimit } from '@/lib/language-resolution';
import { modifyItineraryWithEngine } from '@/lib/crowd/modify';

const ModifyPayloadSchema = z.object({
  userMessage: z.string().min(1, 'userMessage is required'),
  action: z
    .enum(['replace_place', 'add_food_stop', 'less_time', 'more_relaxed', 'auto'])
    .optional(),
  targetPlaceName: z.string().optional(),
  currentItinerary: z.any(),
  foodPreference: z.string().optional(),
});

export async function POST(request: NextRequest) {
  // 1. Feature Flag: Behind crowdAwareEnabled (default OFF -> 404)
  const isEnabled = (process.env.CROWD_AWARE_ENABLED || 'false').toLowerCase() === 'true';
  if (!isEnabled) {
    return NextResponse.json(
      { code: 'NOT_FOUND', error: 'Itinerary modification engine is currently disabled.' },
      { status: 404 }
    );
  }

  // 2. Authentication: Verify Firebase ID Token via firebase-admin
  const authHeader = request.headers.get('authorization');
  if (authHeader) {
    const auth = await verifyAuthToken(authHeader);
    if (!auth.valid) {
      return NextResponse.json(
        { code: 'UNAUTHORIZED', error: auth.error || 'Authentication required.' },
        { status: 401 }
      );
    }
  }

  // 3. Rate Limiting
  const ip = request.headers.get('x-forwarded-for') || 'anon';
  const rate = checkRateLimit(`itin_mod_${ip}`, 45, 60000);
  if (!rate.allowed) {
    return NextResponse.json(
      { code: 'RATE_LIMIT_EXCEEDED', error: 'Too many requests. Please wait a moment.' },
      { status: 429 }
    );
  }

  // 4. Parse Body
  let body: any;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { code: 'INVALID_JSON', error: 'Invalid JSON request payload.' },
      { status: 400 }
    );
  }

  const parseResult = ModifyPayloadSchema.safeParse(body);
  if (!parseResult.success) {
    return NextResponse.json(
      {
        code: 'BAD_REQUEST',
        error: 'Invalid request input.',
        details: parseResult.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`),
      },
      { status: 400 }
    );
  }

  // 5. Execute Modification with Engine
  const result = await modifyItineraryWithEngine(parseResult.data);

  return NextResponse.json(result);
}

