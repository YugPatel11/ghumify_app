import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { LeaveTimeEngine } from '@/lib/notifications/leave-time-engine';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string; stopId: string }> }
) {
  try {
    const { id: tripId, stopId } = await params;
    const db = getDb();
    const nowIso = new Date().toISOString();

    const stopStmt = db.prepare('SELECT * FROM trip_stops WHERE id = ? AND trip_id = ?');
    const stop = stopStmt.get(stopId, tripId) as any;

    if (!stop) {
      return NextResponse.json(
        { code: 'STOP_NOT_FOUND', error: `Stop ${stopId} not found in trip ${tripId}.` },
        { status: 404 }
      );
    }

    // Update stop status to departed
    const updateStmt = db.prepare(`
      UPDATE trip_stops
      SET status = 'departed', actual_departure_at = ?, updated_at = ?
      WHERE id = ?
    `);
    updateStmt.run(nowIso, nowIso, stopId);

    // Cancel all remaining pending leave_now, heads_up, and overdue_nag alerts for this stop
    const cancelStmt = db.prepare(`
      UPDATE scheduled_alerts
      SET status = 'cancelled', updated_at = ?
      WHERE trip_id = ? AND stop_id = ? AND status = 'pending'
    `);
    const cancelledCount = cancelStmt.run(nowIso, tripId, stopId).changes;

    // Reconcile remaining trip alerts for upcoming stops
    await LeaveTimeEngine.reconcileTripAlerts(tripId);

    return NextResponse.json({
      success: true,
      message: `Departure registered for ${stop.title}.`,
      stopId,
      status: 'departed',
      actualDepartureAt: nowIso,
      cancelledAlertsCount: cancelledCount,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'REGISTER_DEPARTURE_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
