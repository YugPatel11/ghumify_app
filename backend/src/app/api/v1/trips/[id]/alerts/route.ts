import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { LeaveTimeEngine } from '@/lib/notifications/leave-time-engine';

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: tripId } = await params;
    const db = getDb();

    // Verify trip exists
    const tripStmt = db.prepare('SELECT * FROM trips WHERE id = ?');
    const trip = tripStmt.get(tripId) as any;
    if (!trip) {
      return NextResponse.json(
        { code: 'TRIP_NOT_FOUND', error: `Trip with ID ${tripId} not found.` },
        { status: 404 }
      );
    }

    // Fetch all scheduled alerts for this trip
    const alertsStmt = db.prepare(`
      SELECT sa.*, ts.title as stop_title, ts.stop_order, ts.planned_arrival_at, ts.planned_departure_at
      FROM scheduled_alerts sa
      JOIN trip_stops ts ON sa.stop_id = ts.id
      WHERE sa.trip_id = ? AND sa.status != 'cancelled'
      ORDER BY sa.fire_at ASC
    `);
    const alerts = alertsStmt.all(tripId) as any[];

    // Fetch stops
    const stopsStmt = db.prepare(`
      SELECT * FROM trip_stops
      WHERE trip_id = ?
      ORDER BY stop_order ASC
    `);
    const stops = stopsStmt.all(tripId) as any[];

    // Fetch travel estimates
    const estimatesStmt = db.prepare(`
      SELECT * FROM travel_estimates
      WHERE trip_id = ?
    `);
    const estimates = estimatesStmt.all(tripId) as any[];

    return NextResponse.json({
      success: true,
      tripId,
      title: trip.title,
      alerts: alerts.map((a) => ({
        id: a.id,
        stopId: a.stop_id,
        stopTitle: a.stop_title,
        stopOrder: a.stop_order,
        type: a.type,
        fireAt: a.fire_at,
        notificationKey: a.notification_key,
        status: a.status,
        sentAt: a.sent_at,
      })),
      stops: stops.map((s) => ({
        id: s.id,
        order: s.stop_order,
        title: s.title,
        subtitle: s.subtitle,
        status: s.status,
        plannedArrivalAt: s.planned_arrival_at,
        plannedDepartureAt: s.planned_departure_at,
        stayDurationMinutes: s.stay_duration_minutes,
        lat: s.lat,
        lng: s.lng,
      })),
      travelEstimates: estimates.map((e) => ({
        fromStopId: e.from_stop_id,
        toStopId: e.to_stop_id,
        mode: e.mode,
        durationSeconds: e.duration_seconds,
        distanceMeters: e.distance_meters,
        source: e.source,
        isApproximate: e.source === 'haversine_fallback',
      })),
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_TRIP_ALERTS_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
