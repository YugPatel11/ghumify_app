import { NextResponse } from 'next/server';
import { SosEngine } from '@/lib/sos/sos-engine';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: sosId } = await params;
    const body = await request.json().catch(() => ({}));
    const userId = body.userId || 'user_demo';

    const success = await SosEngine.resolveSafe(sosId, userId);

    return NextResponse.json({
      success,
      message: 'Traveler marked safe. Emergency contacts notified.',
      sosId,
      resolvedAt: new Date().toISOString(),
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'RESOLVE_SAFE_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
