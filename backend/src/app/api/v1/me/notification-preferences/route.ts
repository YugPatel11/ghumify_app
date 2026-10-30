import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId') || 'user_demo';

    const db = getDb();
    const stmt = db.prepare('SELECT * FROM notification_preferences WHERE user_id = ?');
    let prefs = stmt.get(userId) as any;

    if (!prefs) {
      const now = new Date().toISOString();
      const insert = db.prepare(`
        INSERT INTO notification_preferences (
          user_id, push_enabled, heads_up_enabled, heads_up_lead_minutes,
          leave_now_enabled, go_to_next_enabled, overdue_nag_enabled, late_warning_enabled,
          safety_buffer_minutes, default_transport_mode, quiet_hours_enabled,
          quiet_hours_start, quiet_hours_end, allow_trip_override_quiet_hours,
          location_smart_mode_enabled, max_overdue_nags, updated_at
        ) VALUES (?, 1, 1, 15, 1, 1, 1, 1, 10, 'driving', 0, '22:00', '07:00', 1, 0, 3, ?)
      `);
      insert.run(userId, now);
      prefs = stmt.get(userId);
    }

    return NextResponse.json({
      success: true,
      preferences: {
        userId: prefs.user_id,
        pushEnabled: Boolean(prefs.push_enabled),
        headsUpEnabled: Boolean(prefs.heads_up_enabled),
        headsUpLeadMinutes: prefs.heads_up_lead_minutes,
        leaveNowEnabled: Boolean(prefs.leave_now_enabled),
        goToNextEnabled: Boolean(prefs.go_to_next_enabled),
        overdueNagEnabled: Boolean(prefs.overdue_nag_enabled),
        lateWarningEnabled: Boolean(prefs.late_warning_enabled),
        safetyBufferMinutes: prefs.safety_buffer_minutes,
        defaultTransportMode: prefs.default_transport_mode,
        quietHoursEnabled: Boolean(prefs.quiet_hours_enabled),
        quietHoursStart: prefs.quiet_hours_start,
        quietHoursEnd: prefs.quiet_hours_end,
        allowTripOverrideQuietHours: Boolean(prefs.allow_trip_override_quiet_hours),
        locationSmartModeEnabled: Boolean(prefs.location_smart_mode_enabled),
        maxOverdueNags: prefs.max_overdue_nags,
        updatedAt: prefs.updated_at,
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_PREFERENCES_FAILED', error: err.message },
      { status: 500 }
    );
  }
}

export async function PUT(request: Request) {
  try {
    const body = await request.json();
    const userId = body.userId || 'user_demo';

    const db = getDb();
    const nowIso = new Date().toISOString();

    const existingStmt = db.prepare('SELECT user_id FROM notification_preferences WHERE user_id = ?');
    const existing = existingStmt.get(userId);

    const updateStmt = db.prepare(`
      INSERT INTO notification_preferences (
        user_id, push_enabled, heads_up_enabled, heads_up_lead_minutes,
        leave_now_enabled, go_to_next_enabled, overdue_nag_enabled, late_warning_enabled,
        safety_buffer_minutes, default_transport_mode, quiet_hours_enabled,
        quiet_hours_start, quiet_hours_end, allow_trip_override_quiet_hours,
        location_smart_mode_enabled, max_overdue_nags, updated_at
      ) VALUES (
        $userId, $pushEnabled, $headsUpEnabled, $headsUpLeadMinutes,
        $leaveNowEnabled, $goToNextEnabled, $overdueNagEnabled, $lateWarningEnabled,
        $safetyBufferMinutes, $defaultTransportMode, $quietHoursEnabled,
        $quietHoursStart, $quietHoursEnd, $allowTripOverrideQuietHours,
        $locationSmartModeEnabled, $maxOverdueNags, $now
      )
      ON CONFLICT(user_id) DO UPDATE SET
        push_enabled = excluded.push_enabled,
        heads_up_enabled = excluded.heads_up_enabled,
        heads_up_lead_minutes = excluded.heads_up_lead_minutes,
        leave_now_enabled = excluded.leave_now_enabled,
        go_to_next_enabled = excluded.go_to_next_enabled,
        overdue_nag_enabled = excluded.overdue_nag_enabled,
        late_warning_enabled = excluded.late_warning_enabled,
        safety_buffer_minutes = excluded.safety_buffer_minutes,
        default_transport_mode = excluded.default_transport_mode,
        quiet_hours_enabled = excluded.quiet_hours_enabled,
        quiet_hours_start = excluded.quiet_hours_start,
        quiet_hours_end = excluded.quiet_hours_end,
        allow_trip_override_quiet_hours = excluded.allow_trip_override_quiet_hours,
        location_smart_mode_enabled = excluded.location_smart_mode_enabled,
        max_overdue_nags = excluded.max_overdue_nags,
        updated_at = excluded.updated_at
    `);

    updateStmt.run({
      $userId: userId,
      $pushEnabled: body.pushEnabled !== undefined ? (body.pushEnabled ? 1 : 0) : 1,
      $headsUpEnabled: body.headsUpEnabled !== undefined ? (body.headsUpEnabled ? 1 : 0) : 1,
      $headsUpLeadMinutes: Math.min(60, Math.max(1, body.headsUpLeadMinutes || 15)),
      $leaveNowEnabled: body.leaveNowEnabled !== undefined ? (body.leaveNowEnabled ? 1 : 0) : 1,
      $goToNextEnabled: body.goToNextEnabled !== undefined ? (body.goToNextEnabled ? 1 : 0) : 1,
      $overdueNagEnabled: body.overdueNagEnabled !== undefined ? (body.overdueNagEnabled ? 1 : 0) : 1,
      $lateWarningEnabled: body.lateWarningEnabled !== undefined ? (body.lateWarningEnabled ? 1 : 0) : 1,
      $safetyBufferMinutes: Math.min(45, Math.max(0, body.safetyBufferMinutes ?? 10)),
      $defaultTransportMode: body.defaultTransportMode || 'driving',
      $quietHoursEnabled: body.quietHoursEnabled !== undefined ? (body.quietHoursEnabled ? 1 : 0) : 0,
      $quietHoursStart: body.quietHoursStart || '22:00',
      $quietHoursEnd: body.quietHoursEnd || '07:00',
      $allowTripOverrideQuietHours:
        body.allowTripOverrideQuietHours !== undefined
          ? body.allowTripOverrideQuietHours
            ? 1
            : 0
          : 1,
      $locationSmartModeEnabled:
        body.locationSmartModeEnabled !== undefined
          ? body.locationSmartModeEnabled
            ? 1
            : 0
          : 0,
      $maxOverdueNags: Math.min(5, Math.max(1, body.maxOverdueNags || 3)),
      $now: nowIso,
    });

    return NextResponse.json({
      success: true,
      message: 'Notification preferences updated successfully.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'UPDATE_PREFERENCES_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
