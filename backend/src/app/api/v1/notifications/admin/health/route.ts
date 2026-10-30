import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { FcmClient } from '@/lib/notifications/fcm-client';

export async function GET() {
  try {
    const db = getDb();
    const creds = FcmClient.loadCredentials();
    const clock = await FcmClient.checkClockSync();

    // Query pending alerts count
    const pendingStmt = db.prepare("SELECT count(*) as count FROM scheduled_alerts WHERE status = 'pending'");
    const pendingCount = (pendingStmt.get() as any)?.count || 0;

    // Query active tokens count
    const tokensStmt = db.prepare("SELECT count(*) as count FROM device_tokens WHERE is_active = 1");
    const activeTokensCount = (tokensStmt.get() as any)?.count || 0;

    // Last successful send
    const lastSendStmt = db.prepare("SELECT sent_at FROM scheduled_alerts WHERE status = 'sent' ORDER BY sent_at DESC LIMIT 1");
    const lastSend = (lastSendStmt.get() as any)?.sent_at || null;

    return NextResponse.json({
      status: 'healthy',
      fcm: {
        configured: Boolean(creds),
        projectId: creds?.project_id || null,
        clientEmail: creds?.client_email || null,
        mode: creds ? 'fcm_http_v1' : 'simulated_local',
      },
      clock: {
        inSync: clock.inSync,
        driftSeconds: clock.driftSeconds,
      },
      scheduler: {
        queueDepthPending: pendingCount,
        activeDeviceTokens: activeTokensCount,
        lastSuccessfulSend: lastSend,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (err: any) {
    return NextResponse.json(
      { status: 'unhealthy', error: err.message },
      { status: 500 }
    );
  }
}
