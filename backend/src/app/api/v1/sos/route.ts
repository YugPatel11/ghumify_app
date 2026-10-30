import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { SosEngine } from '@/lib/sos/sos-engine';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const {
      sos_id,
      userId = 'user_demo',
      lat,
      lng,
      accuracy_m = 10,
      location_source = 'gps',
      trip_id,
      trigger_source = 'home',
      battery_percent,
      client_sent_sms = [],
    } = body;

    if (!sos_id || typeof lat !== 'number' || typeof lng !== 'number') {
      return NextResponse.json(
        { code: 'INVALID_PARAMETERS', error: 'sos_id, lat, and lng are required.' },
        { status: 400 }
      );
    }

    // Trigger SOS via engine
    const result = await SosEngine.triggerSos({
      sosId: sos_id,
      userId,
      lat,
      lng,
      accuracyM: accuracy_m,
      locationSource: location_source,
      tripId: trip_id,
      triggerSource: trigger_source,
      batteryPercent: battery_percent,
      clientSentSmsContacts: client_sent_sms,
    });

    return NextResponse.json({
      success: true,
      message: 'SOS emergency alert activated.',
      sosEvent: result,
    });
  } catch (err: any) {
    console.error('[API /api/v1/sos] Error:', err);
    return NextResponse.json(
      { code: 'SOS_TRIGGER_FAILED', error: err.message },
      { status: 500 }
    );
  }
}

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId') || 'user_demo';

    const db = getDb();
    const stmt = db.prepare(`
      SELECT id, status, trigger_source, triggered_at, resolved_at,
             initial_lat, initial_lng, accuracy_m, battery_percent, itinerary_snapshot
      FROM sos_events
      WHERE user_id = ?
      ORDER BY triggered_at DESC
      LIMIT 20
    `);
    const rows = stmt.all(userId) as any[];

    return NextResponse.json({
      success: true,
      history: rows.map((r) => ({
        id: r.id,
        status: r.status,
        triggerSource: r.trigger_source,
        triggeredAt: r.triggered_at,
        resolvedAt: r.resolved_at,
        lat: r.initial_lat,
        lng: r.initial_lng,
        accuracyM: r.accuracy_m,
        batteryPercent: r.battery_percent,
        itinerary: r.itinerary_snapshot ? JSON.parse(r.itinerary_snapshot) : null,
      })),
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_SOS_HISTORY_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
