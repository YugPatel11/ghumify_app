import { NextResponse } from 'next/server';
import { SosEngine } from '@/lib/sos/sos-engine';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: sosId } = await params;
    const body = await request.json();
    const { lat, lng, accuracy_m = 10 } = body;

    if (typeof lat !== 'number' || typeof lng !== 'number') {
      return NextResponse.json(
        { code: 'INVALID_COORDINATES', error: 'Numeric lat and lng coordinates required.' },
        { status: 400 }
      );
    }

    const success = SosEngine.updateLocation(sosId, lat, lng, accuracy_m);

    return NextResponse.json({
      success,
      sosId,
      updatedAt: new Date().toISOString(),
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'UPDATE_LOCATION_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
