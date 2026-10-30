import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId') || 'user_demo';

    const db = getDb();
    const stmt = db.prepare(`
      SELECT id, trip_id, stop_id, type, title, body, data_payload, notification_key, is_read, created_at
      FROM notifications
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 50
    `);
    const rows = stmt.all(userId) as any[];

    const unreadCountStmt = db.prepare(`
      SELECT count(*) as count FROM notifications WHERE user_id = ? AND is_read = 0
    `);
    const unreadCount = (unreadCountStmt.get(userId) as any)?.count || 0;

    return NextResponse.json({
      success: true,
      unreadCount,
      notifications: rows.map((r) => ({
        id: r.id,
        tripId: r.trip_id,
        stopId: r.stop_id,
        type: r.type,
        title: r.title,
        body: r.body,
        data: r.data_payload ? JSON.parse(r.data_payload) : null,
        notificationKey: r.notification_key,
        isRead: Boolean(r.is_read),
        createdAt: r.created_at,
      })),
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_INBOX_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
