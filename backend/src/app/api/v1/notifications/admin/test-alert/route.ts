import { NextResponse } from 'next/server';
import { NotificationService } from '@/lib/notifications/notification-service';

export async function POST(request: Request) {
  try {
    const body = await request.json().catch(() => ({}));
    const userId = body.userId || 'user_demo';
    const place = body.place || 'Amber Fort';

    const result = await NotificationService.sendToUser(userId, {
      tripId: 'test_trip',
      stopId: 'test_stop',
      type: 'leave_now',
      notificationKey: `test:leave_now:${Date.now()}`,
      fireAtUtc: new Date().toISOString(),
      params: {
        place,
        minutes: 0,
      },
    });

    return NextResponse.json({
      success: true,
      message: `Test notification sent for ${place}.`,
      sentCount: result.sentCount,
      failureCount: result.failureCount,
      inboxId: result.inboxId,
    });
  } catch (err: any) {
    return NextResponse.json(
      { code: 'TEST_ALERT_FAILED', error: err.message },
      { status: 500 }
    );
  }
}
