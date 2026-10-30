import { getDb } from '../db';
import { NotificationService } from './notification-service';

export interface DueAlertRow {
  id: string;
  trip_id: string;
  stop_id: string;
  user_id: string;
  type: 'heads_up' | 'leave_now' | 'go_to_next' | 'overdue_nag' | 'late_warning';
  fire_at: string;
  notification_key: string;
  status: string;
  attempts: number;
}

export class AlertScheduler {
  private static timer: NodeJS.Timeout | null = null;
  private static isTicking = false;
  private static graceWindowMs = 15 * 60 * 1000; // 15 min grace window for server restart recovery

  /**
   * Initializes startup cleanup and runs catch-up verification.
   */
  public static async onStartup(): Promise<{ recovered: number; dropped: number }> {
    const db = getDb();
    const now = new Date();
    const nowIso = now.toISOString();
    const staleThresholdIso = new Date(now.getTime() - this.graceWindowMs).toISOString();

    // 1. Recover alerts stuck in 'processing' from an unexpected server crash
    const stuckStmt = db.prepare(`
      UPDATE scheduled_alerts
      SET status = 'pending', updated_at = ?
      WHERE status = 'processing'
    `);
    const recovered = stuckStmt.run(nowIso).changes;

    // 2. Drop or mark 'skipped' alerts that became severely stale while server was down
    const staleStmt = db.prepare(`
      UPDATE scheduled_alerts
      SET status = 'skipped', error_message = 'stale_after_server_downtime', updated_at = ?
      WHERE status = 'pending' AND fire_at < ?
    `);
    const dropped = staleStmt.run(nowIso, staleThresholdIso).changes;

    console.log(
      `[AlertScheduler] Startup audit complete. Recovered stuck: ${recovered}, dropped stale: ${dropped}`
    );

    return { recovered, dropped };
  }

  /**
   * Atomically claims due alerts from SQLite to ensure single-worker execution.
   */
  public static claimDueAlerts(batchSize: number = 20): DueAlertRow[] {
    const db = getDb();
    const nowIso = new Date().toISOString();

    // Find due alerts that are pending
    const findStmt = db.prepare(`
      SELECT id, trip_id, stop_id, user_id, type, fire_at, notification_key, status, attempts
      FROM scheduled_alerts
      WHERE status = 'pending' AND fire_at <= ?
      ORDER BY fire_at ASC
      LIMIT ?
    `);
    const candidates = findStmt.all(nowIso, batchSize) as DueAlertRow[];

    const claimed: DueAlertRow[] = [];
    const claimStmt = db.prepare(`
      UPDATE scheduled_alerts
      SET status = 'processing', attempts = attempts + 1, updated_at = ?
      WHERE id = ? AND status = 'pending'
    `);

    for (const alert of candidates) {
      const res = claimStmt.run(nowIso, alert.id);
      if (res.changes > 0) {
        claimed.push(alert);
      }
    }

    return claimed;
  }

  /**
   * Processes a single claimed alert.
   */
  public static async processAlert(alert: DueAlertRow): Promise<boolean> {
    const db = getDb();
    const nowIso = new Date().toISOString();

    try {
      // Fetch stop details
      const stopStmt = db.prepare('SELECT * FROM trip_stops WHERE id = ?');
      const stop = stopStmt.get(alert.stop_id) as any;

      if (!stop || stop.status === 'departed' || stop.status === 'skipped') {
        // Stop is already departed or skipped, mark alert skipped
        const skipStmt = db.prepare(`
          UPDATE scheduled_alerts
          SET status = 'skipped', error_message = 'stop_already_departed_or_skipped', updated_at = ?
          WHERE id = ?
        `);
        skipStmt.run(nowIso, alert.id);
        return true;
      }

      // Fetch next stop if available
      const nextStopStmt = db.prepare(`
        SELECT * FROM trip_stops
        WHERE trip_id = ? AND stop_order > ? AND status != 'skipped'
        ORDER BY stop_order ASC LIMIT 1
      `);
      const nextStop = nextStopStmt.get(alert.trip_id, stop.stop_order) as any;

      // Fetch travel estimate if available
      let travelMinutes = 15;
      if (nextStop) {
        const estStmt = db.prepare(`
          SELECT duration_seconds FROM travel_estimates
          WHERE trip_id = ? AND from_stop_id = ? AND to_stop_id = ?
          ORDER BY computed_at DESC LIMIT 1
        `);
        const est = estStmt.get(alert.trip_id, stop.id, nextStop.id) as any;
        if (est?.duration_seconds) {
          travelMinutes = Math.round(est.duration_seconds / 60);
        }
      }

      // Dispatch notification
      const sendResult = await NotificationService.sendToUser(alert.user_id, {
        tripId: alert.trip_id,
        stopId: alert.stop_id,
        type: alert.type,
        notificationKey: alert.notification_key,
        fireAtUtc: alert.fire_at,
        params: {
          place: stop.title,
          nextPlace: nextStop?.title,
          travelMinutes,
          arrivalTime: nextStop?.planned_arrival_at,
        },
      });

      // Mark alert sent
      const updateSuccess = db.prepare(`
        UPDATE scheduled_alerts
        SET status = 'sent', sent_at = ?, updated_at = ?
        WHERE id = ?
      `);
      updateSuccess.run(nowIso, nowIso, alert.id);

      return true;
    } catch (err: any) {
      console.error(`[AlertScheduler] Error dispatching alert ${alert.id}:`, err);
      const updateFail = db.prepare(`
        UPDATE scheduled_alerts
        SET status = CASE WHEN attempts >= 3 THEN 'failed' ELSE 'pending' END,
            error_message = ?, updated_at = ?
        WHERE id = ?
      `);
      updateFail.run(err.message || 'Unknown send error', nowIso, alert.id);
      return false;
    }
  }

  /**
   * Single scheduler tick processing all due alerts.
   */
  public static async tick(): Promise<number> {
    if (this.isTicking) return 0;
    this.isTicking = true;

    try {
      const claimed = this.claimDueAlerts(15);
      for (const alert of claimed) {
        await this.processAlert(alert);
      }
      return claimed.length;
    } finally {
      this.isTicking = false;
    }
  }

  /**
   * Starts persistent periodic background worker.
   */
  public static start(intervalMs: number = 5000) {
    if (this.timer) return;
    this.onStartup();
    this.timer = setInterval(() => {
      this.tick().catch((e) => console.error('[AlertScheduler] Tick error:', e));
    }, intervalMs);
    console.log(`[AlertScheduler] Started persistent scheduler with interval ${intervalMs}ms`);
  }

  /**
   * Stops scheduler worker.
   */
  public static stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
      console.log('[AlertScheduler] Stopped persistent scheduler.');
    }
  }
}
