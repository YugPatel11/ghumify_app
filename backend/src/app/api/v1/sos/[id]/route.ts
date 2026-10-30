import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { HospitalProvider } from '@/lib/sos/hospital-provider';

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: sosId } = await params;
    const db = getDb();

    const sosStmt = db.prepare('SELECT * FROM sos_events WHERE id = ?');
    const sos = sosStmt.get(sosId) as any;

    if (!sos) {
      return NextResponse.json({ code: 'NOT_FOUND', error: `SOS event ${sosId} not found.` }, { status: 404 });
    }

    // Fetch location updates
    const locStmt = db.prepare(`
      SELECT lat, lng, accuracy_m, recorded_at
      FROM sos_location_updates
      WHERE sos_id = ?
      ORDER BY recorded_at ASC
    `);
    const locations = locStmt.all(sosId) as any[];

    // Fetch deliveries
    const delivStmt = db.prepare(`
      SELECT sd.*, ec.name as contact_name, ec.phone_e164 as contact_phone
      FROM sos_deliveries sd
      LEFT JOIN emergency_contacts ec ON sd.contact_id = ec.id
      WHERE sd.sos_id = ?
      ORDER BY sd.sent_at ASC
    `);
    const deliveries = delivStmt.all(sosId) as any[];

    // Get current/latest location
    const latestLoc = locations[locations.length - 1] || {
      lat: sos.initial_lat,
      lng: sos.initial_lng,
    };

    const hospitals = await HospitalProvider.findNearby(latestLoc.lat, latestLoc.lng, 5000, 3);

    return NextResponse.json({
      success: true,
      sosEvent: {
        id: sos.id,
        status: sos.status,
        triggeredAt: sos.triggered_at,
        resolvedAt: sos.resolved_at,
        lat: latestLoc.lat,
        lng: latestLoc.lng,
        accuracyM: latestLoc.accuracy_m || sos.accuracy_m,
        batteryPercent: sos.battery_percent,
        itinerary: sos.itinerary_snapshot ? JSON.parse(sos.itinerary_snapshot) : null,
      },
      locations,
      deliveries: deliveries.map((d) => ({
        id: d.id,
        contactName: d.contact_name || 'Emergency Contact',
        phone: d.contact_phone || '***',
        channel: d.channel,
        provider: d.provider,
        status: d.status,
        sentAt: d.sent_at,
        kind: d.kind,
      })),
      hospitals,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_SOS_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
