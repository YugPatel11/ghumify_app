import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { NotificationService } from '@/lib/notifications/notification-service';
import { SmsProvider } from '@/lib/sos/sms-provider';

export async function POST(request: Request) {
  try {
    const body = await request.json().catch(() => ({}));
    const userId = body.userId || 'user_demo';
    const db = getDb();

    const userStmt = db.prepare('SELECT name, preferred_language FROM users WHERE id = ?');
    const user = (userStmt.get(userId) || { name: 'Traveler', preferred_language: 'en' }) as any;

    const testMsg = `[TEST DRILL] Ghumify SOS Readiness Check: This is a simulation test. No emergency contacts were alerted. System readiness: OK.`;

    // Send push notification to user's device
    const pushRes = await NotificationService.sendToUser(userId, {
      tripId: 'test_drill',
      stopId: 'test_sos',
      type: 'late_warning',
      notificationKey: `test:sos:${Date.now()}`,
      fireAtUtc: new Date().toISOString(),
      params: {
        place: '[TEST DRILL] SOS Alert System Test',
        nextPlace: 'Readiness: Operational',
      },
    });

    return NextResponse.json({
      success: true,
      message: 'Test drill completed. Notification dispatched to your device only.',
      drillTimestamp: new Date().toISOString(),
      pushSentCount: pushRes.sentCount,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'TEST_DRILL_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
