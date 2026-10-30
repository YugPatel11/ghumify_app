import { NextResponse } from 'next/server';
import { HospitalProvider } from '@/lib/sos/hospital-provider';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const latStr = searchParams.get('lat');
    const lngStr = searchParams.get('lng');
    const limit = parseInt(searchParams.get('limit') || '5', 10);

    const lat = latStr ? parseFloat(latStr) : 26.9124; // Jaipur fallback
    const lng = lngStr ? parseFloat(lngStr) : 75.7873;

    const hospitals = await HospitalProvider.findNearby(lat, lng, 5000, limit);

    return NextResponse.json({
      success: true,
      origin: { lat, lng },
      count: hospitals.length,
      hospitals,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_HOSPITALS_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
