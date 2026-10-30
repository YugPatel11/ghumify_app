import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId') || 'user_demo';

    const db = getDb();
    const stmt = db.prepare('SELECT * FROM user_sos_settings WHERE user_id = ?');
    let row = stmt.get(userId) as any;

    if (!row) {
      const now = new Date().toISOString();
      db.prepare(`
        INSERT INTO user_sos_settings (
          user_id, countdown_seconds, trigger_method, update_interval_minutes,
          expiry_hours, include_medical_info, share_itinerary_snapshot,
          auto_call_emergency, emergency_number, send_hospital_info, daily_sms_cap, updated_at
        ) VALUES (?, 5, 'hold', 3, 6, 0, 1, 0, '112', 1, 30, ?)
      `).run(userId, now);
      row = stmt.get(userId);
    }

    return NextResponse.json({
      success: true,
      settings: {
        userId: row.user_id,
        countdownSeconds: row.countdown_seconds,
        triggerMethod: row.trigger_method,
        updateIntervalMinutes: row.update_interval_minutes,
        expiryHours: row.expiry_hours,
        includeMedicalInfo: Boolean(row.include_medical_info),
        shareItinerarySnapshot: Boolean(row.share_itinerary_snapshot),
        autoCallEmergency: Boolean(row.auto_call_emergency),
        emergencyNumber: row.emergency_number,
        sendHospitalInfo: Boolean(row.send_hospital_info),
        dailySmsCap: row.daily_sms_cap,
        updatedAt: row.updated_at,
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'FETCH_SOS_SETTINGS_FAILED', error: err.message },
      { status: 500 }
    );
  }
}

export async function PUT(request: Request) {
  try {
    const body = await request.json();
    const {
      userId = 'user_demo',
      countdownSeconds = 5,
      triggerMethod = 'hold',
      updateIntervalMinutes = 3,
      expiryHours = 6,
      includeMedicalInfo = false,
      shareItinerarySnapshot = true,
      autoCallEmergency = false,
      emergencyNumber = '112',
      sendHospitalInfo = true,
    } = body;

    const db = getDb();
    const nowIso = new Date().toISOString();

    const upsertStmt = db.prepare(`
      INSERT INTO user_sos_settings (
        user_id, countdown_seconds, trigger_method, update_interval_minutes,
        expiry_hours, include_medical_info, share_itinerary_snapshot,
        auto_call_emergency, emergency_number, send_hospital_info, daily_sms_cap, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 30, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        countdown_seconds = excluded.countdown_seconds,
        trigger_method = excluded.trigger_method,
        update_interval_minutes = excluded.update_interval_minutes,
        expiry_hours = excluded.expiry_hours,
        include_medical_info = excluded.include_medical_info,
        share_itinerary_snapshot = excluded.share_itinerary_snapshot,
        auto_call_emergency = excluded.auto_call_emergency,
        emergency_number = excluded.emergency_number,
        send_hospital_info = excluded.send_hospital_info,
        updated_at = excluded.updated_at
    `);

    upsertStmt.run(
      userId,
      Math.min(10, Math.max(0, countdownSeconds)),
      triggerMethod,
      Math.min(15, Math.max(1, updateIntervalMinutes)),
      Math.min(24, Math.max(1, expiryHours)),
      includeMedicalInfo ? 1 : 0,
      shareItinerarySnapshot ? 1 : 0,
      autoCallEmergency ? 1 : 0,
      emergencyNumber,
      sendHospitalInfo ? 1 : 0,
      nowIso
    );

    return NextResponse.json({
      success: true,
      message: 'SOS settings updated successfully.',
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'UPDATE_SOS_SETTINGS_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
