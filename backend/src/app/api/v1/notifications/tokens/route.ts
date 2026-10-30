import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { token, platform = 'android', language = 'en', timezone = 'UTC', userId = 'user_demo' } = body;

    if (!token || typeof token !== 'string') {
      return NextResponse.json(
        { code: 'TOKEN_REQUIRED', error: 'FCM device token is required.' },
        { status: 400 }
      );
    }

    const db = getDb();
    const nowIso = new Date().toISOString();

    // Check if token exists for any user (handle user re-assignment)
    const existing = db.prepare('SELECT id, user_id FROM device_tokens WHERE token = ?').get(token) as any;

    if (existing) {
      const updateStmt = db.prepare(`
        UPDATE device_tokens
        SET user_id = ?, platform = ?, language = ?, timezone = ?, is_active = 1, last_seen_at = ?
        WHERE token = ?
      `);
      updateStmt.run(userId, platform, language, timezone, nowIso, token);
    } else {
      const insertStmt = db.prepare(`
        INSERT INTO device_tokens (
          id, user_id, token, platform, language, timezone, last_seen_at, is_active, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
      `);
      const tokenId = `tok_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
      insertStmt.run(tokenId, userId, token, platform, language, timezone, nowIso, nowIso);
    }

    return NextResponse.json({
      success: true,
      message: 'Device token registered successfully.',
      userId,
      token: token.slice(0, 10) + '...',
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'TOKEN_REGISTRATION_FAILED', error: err.message },
      { status: 500 }
    );
  }
}

export async function DELETE(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const token = searchParams.get('token');

    if (!token) {
      return NextResponse.json(
        { code: 'TOKEN_REQUIRED', error: 'Token query parameter is required.' },
        { status: 400 }
      );
    }

    const db = getDb();
    const deactivateStmt = db.prepare(`
      UPDATE device_tokens
      SET is_active = 0, last_seen_at = ?
      WHERE token = ?
    `);
    const result = deactivateStmt.run(new Date().toISOString(), token);

    return NextResponse.json({
      success: true,
      unregistered: result.changes > 0,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'TOKEN_DELETE_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
