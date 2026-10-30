import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { LeaveTimeEngine } from '@/lib/notifications/leave-time-engine';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const {
      id: tripId,
      userId = 'user_demo',
      title = 'My Trip',
      cityId,
      cityName,
      startDate = new Date().toISOString().split('T')[0],
      endDate = new Date().toISOString().split('T')[0],
      stops = [],
    } = body;

    if (!tripId) {
      return NextResponse.json(
        { code: 'TRIP_ID_REQUIRED', error: 'Trip ID is required.' },
        { status: 400 }
      );
    }

    const db = getDb();
    const nowIso = new Date().toISOString();

    // 1. Upsert Trip
    const upsertTrip = db.prepare(`
      INSERT INTO trips (
        id, user_id, title, city_id, city_name, start_date, end_date, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        city_id = excluded.city_id,
        city_name = excluded.city_name,
        start_date = excluded.start_date,
        end_date = excluded.end_date,
        updated_at = excluded.updated_at
    `);
    upsertTrip.run(tripId, userId, title, cityId, cityName, startDate, endDate, nowIso, nowIso);

    // 2. Upsert Trip Stops
    const upsertStop = db.prepare(`
      INSERT INTO trip_stops (
        id, trip_id, stop_order, title, subtitle, place_id, stop_type,
        planned_arrival_at, planned_departure_at, stay_duration_minutes,
        transport_mode, status, lat, lng, timezone, created_at, updated_at
      ) VALUES (
        $id, $tripId, $stopOrder, $title, $subtitle, $placeId, $stopType,
        $plannedArrivalAt, $plannedDepartureAt, $stayDurationMinutes,
        $transportMode, $status, $lat, $lng, $timezone, $now, $now
      )
      ON CONFLICT(id) DO UPDATE SET
        stop_order = excluded.stop_order,
        title = excluded.title,
        subtitle = excluded.subtitle,
        stop_type = excluded.stop_type,
        planned_arrival_at = excluded.planned_arrival_at,
        planned_departure_at = excluded.planned_departure_at,
        stay_duration_minutes = excluded.stay_duration_minutes,
        transport_mode = excluded.transport_mode,
        lat = excluded.lat,
        lng = excluded.lng,
        updated_at = excluded.updated_at
    `);

    for (let i = 0; i < stops.length; i++) {
      const s = stops[i];
      upsertStop.run({
        $id: s.id,
        $tripId: tripId,
        $stopOrder: s.stopOrder ?? i + 1,
        $title: s.title,
        $subtitle: s.subtitle || '',
        $placeId: s.placeId || null,
        $stopType: s.stopType || 'visit',
        $plannedArrivalAt: s.plannedArrivalAt,
        $plannedDepartureAt: s.plannedDepartureAt,
        $stayDurationMinutes: s.stayDurationMinutes || 60,
        $transportMode: s.transportMode || 'driving',
        $status: s.status || 'upcoming',
        $lat: s.lat ?? null,
        $lng: s.lng ?? null,
        $timezone: s.timezone || 'UTC',
        $now: nowIso,
      });
    }

    // 3. Reconcile Alerts
    const scheduledCount = await LeaveTimeEngine.reconcileTripAlerts(tripId);

    return NextResponse.json({
      success: true,
      message: 'Trip synced and alerts reconciled successfully.',
      tripId,
      stopsCount: stops.length,
      scheduledAlertsCount: scheduledCount,
    });
  } catch (err: any) {
    console.error('Trip sync error:', err);
    return NextResponse.json(
      { code: 'TRIP_SYNC_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
