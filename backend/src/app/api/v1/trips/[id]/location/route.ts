import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { RoutingProvider } from '@/lib/notifications/routing-provider';
import { LeaveTimeEngine } from '@/lib/notifications/leave-time-engine';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: tripId } = await params;
    const body = await request.json();
    const { lat, lng } = body;

    if (typeof lat !== 'number' || typeof lng !== 'number') {
      return NextResponse.json(
        { code: 'INVALID_COORDINATES', error: 'Numeric lat and lng coordinates required.' },
        { status: 400 }
      );
    }

    const db = getDb();
    const nowIso = new Date().toISOString();

    // Fetch upcoming stops for this trip
    const stopsStmt = db.prepare(`
      SELECT * FROM trip_stops
      WHERE trip_id = ? AND status IN ('upcoming', 'arrived')
      ORDER BY stop_order ASC
    `);
    const stops = stopsStmt.all(tripId) as any[];

    if (stops.length === 0) {
      return NextResponse.json({
        success: true,
        message: 'No active upcoming stops for trip.',
      });
    }

    const currentCoords = { lat, lng };
    let triggeredEvent: string | null = null;
    let targetStopTitle: string | null = null;

    // Check geofence proximity (150m radius)
    for (const stop of stops) {
      if (stop.lat != null && stop.lng != null) {
        const stopCoords = { lat: stop.lat, lng: stop.lng };
        const distMeters = RoutingProvider.haversineMeters(currentCoords, stopCoords);

        // Case 1: Arrived at upcoming stop (< 150m)
        if (stop.status === 'upcoming' && distMeters <= 150) {
          const arrStmt = db.prepare(`
            UPDATE trip_stops
            SET status = 'arrived', actual_arrival_at = ?, updated_at = ?
            WHERE id = ?
          `);
          arrStmt.run(nowIso, nowIso, stop.id);

          // Cancel travel alert
          db.prepare(`
            UPDATE scheduled_alerts
            SET status = 'cancelled', updated_at = ?
            WHERE trip_id = ? AND stop_id = ? AND type = 'go_to_next' AND status = 'pending'
          `).run(nowIso, tripId, stop.id);

          triggeredEvent = 'arrived_via_geofence';
          targetStopTitle = stop.title;
          break;
        }

        // Case 2: Left current stop early (> 300m away after having arrived)
        if (stop.status === 'arrived' && distMeters > 300) {
          const depStmt = db.prepare(`
            UPDATE trip_stops
            SET status = 'departed', actual_departure_at = ?, updated_at = ?
            WHERE id = ?
          `);
          depStmt.run(nowIso, nowIso, stop.id);

          // Cancel pending leave now and nags
          db.prepare(`
            UPDATE scheduled_alerts
            SET status = 'cancelled', updated_at = ?
            WHERE trip_id = ? AND stop_id = ? AND status = 'pending'
          `).run(nowIso, tripId, stop.id);

          triggeredEvent = 'departed_early_via_geofence';
          targetStopTitle = stop.title;

          // Reconcile remaining alerts
          await LeaveTimeEngine.reconcileTripAlerts(tripId);
          break;
        }
      }
    }

    return NextResponse.json({
      success: true,
      smartModeEvent: triggeredEvent,
      stopTitle: targetStopTitle,
      timestamp: nowIso,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'LOCATION_PROCESSING_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
