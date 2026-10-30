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
    const isFalseAlarm = Boolean(body.isFalseAlarm);

    const success = await SosEngine.cancelOrFalseAlarm(sosId, userId, isFalseAlarm);

    return NextResponse.json({
      success,
      message: isFalseAlarm ? 'Marked as false alarm.' : 'SOS cancelled.',
      sosId,
      status: isFalseAlarm ? 'false_alarm' : 'cancelled',
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'CANCEL_SOS_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
