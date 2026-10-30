import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: notifId } = await params;
    const db = getDb();

    const update = db.prepare('UPDATE notifications SET is_read = 1 WHERE id = ?');
    const res = update.run(notifId);

    return NextResponse.json({
      success: true,
      updated: res.changes > 0,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'MARK_READ_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
