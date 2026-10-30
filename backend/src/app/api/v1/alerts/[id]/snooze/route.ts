import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: alertId } = await params;
    const body = await request.json().catch(() => ({}));
    const snoozeMinutes = Math.min(60, Math.max(1, body.minutes || 10));

    const db = getDb();
    const alertStmt = db.prepare('SELECT * FROM scheduled_alerts WHERE id = ?');
    const alert = alertStmt.get(alertId) as any;

    if (!alert) {
      return NextResponse.json(
        { code: 'ALERT_NOT_FOUND', error: `Alert ${alertId} not found.` },
        { status: 404 }
      );
    }

    const newFireEpoch = Date.now() + snoozeMinutes * 60 * 1000;
    const newFireIso = new Date(newFireEpoch).toISOString();
    const nowIso = new Date().toISOString();

    const updateStmt = db.prepare(`
      UPDATE scheduled_alerts
      SET fire_at = ?, status = 'pending', attempts = 0, updated_at = ?
      WHERE id = ?
    `);
    updateStmt.run(newFireIso, nowIso, alertId);

    return NextResponse.json({
      success: true,
      message: `Alert snoozed for ${snoozeMinutes} minutes.`,
      alertId,
      newFireAt: newFireIso,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'SNOOZE_ALERT_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
