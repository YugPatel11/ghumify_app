import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: alertId } = await params;
    const db = getDb();
    const nowIso = new Date().toISOString();

    const updateStmt = db.prepare(`
      UPDATE scheduled_alerts
      SET status = 'cancelled', updated_at = ?
      WHERE id = ?
    `);
    const res = updateStmt.run(nowIso, alertId);

    if (res.changes === 0) {
      return NextResponse.json(
        { code: 'ALERT_NOT_FOUND', error: `Alert ${alertId} not found.` },
        { status: 404 }
      );
    }

    return NextResponse.json({
      success: true,
      message: `Alert ${alertId} dismissed.`,
      alertId,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'DISMISS_ALERT_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
