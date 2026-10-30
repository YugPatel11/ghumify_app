import { getDb } from '../db';
import { RoutingProvider, TransportMode, Coordinates } from './routing-provider';

export interface TripStopRecord {
  id: string;
  trip_id: string;
  stop_order: number;
  title: string;
  subtitle?: string;
  place_id?: string;
  stop_type: string;
  planned_arrival_at: string; // ISO 8601 UTC
  planned_departure_at: string; // ISO 8601 UTC
  stay_duration_minutes: number;
  transport_mode: TransportMode;
  status: 'upcoming' | 'arrived' | 'departed' | 'skipped';
  lat?: number;
  lng?: number;
  timezone: string;
  actual_arrival_at?: string;
  actual_departure_at?: string;
}

export interface TransitionCalculation {
  currentStop: TripStopRecord;
  nextStop: TripStopRecord | null;
  travelDurationSeconds: number;
  travelDistanceMeters: number;
  isApproximate: boolean;
  routingSource: string;
  departureTimeUtc: string; // currentStop.planned_departure_at
  leaveTimeUtc: string; // nextStop.arrival - travel - safetyBuffer
  effectiveLeaveUtc: string; // min(departureTimeUtc, leaveTimeUtc)
  isImpossibleSchedule: boolean;
  delayRiskMinutes: number;
}

export interface AlertPlanItem {
  type: 'heads_up' | 'leave_now' | 'go_to_next' | 'overdue_nag' | 'late_warning';
  fireAtUtc: string;
  notificationKey: string;
  tripId: string;
  stopId: string;
  userId: string;
  context: {
    currentPlace: string;
    nextPlace?: string;
    minutesLead?: number;
    arrivalEstimateUtc?: string;
    travelDurationMin?: number;
  };
}

export class LeaveTimeEngine {
  /**
   * Generates a unique, deterministic notification key for idempotency.
   */
  public static makeNotificationKey(
    tripId: string,
    stopId: string,
    type: string,
    timestampIso: string
  ): string {
    const epochMinute = Math.floor(new Date(timestampIso).getTime() / (60 * 1000));
    return `${tripId}:${stopId}:${type}:${epochMinute}`;
  }

  /**
   * Calculate transition metrics between current stop and next stop.
   */
  public static async calculateTransition(
    tripId: string,
    currentStop: TripStopRecord,
    nextStop: TripStopRecord | null,
    safetyBufferMinutes: number = 10
  ): Promise<TransitionCalculation> {
    const depTime = new Date(currentStop.planned_departure_at).getTime();

    if (!nextStop) {
      // Last stop in the trip
      return {
        currentStop,
        nextStop: null,
        travelDurationSeconds: 0,
        travelDistanceMeters: 0,
        isApproximate: false,
        routingSource: 'none',
        departureTimeUtc: currentStop.planned_departure_at,
        leaveTimeUtc: currentStop.planned_departure_at,
        effectiveLeaveUtc: currentStop.planned_departure_at,
        isImpossibleSchedule: false,
        delayRiskMinutes: 0,
      };
    }

    const nextArrTime = new Date(nextStop.planned_arrival_at).getTime();
    const origin: Coordinates | null =
      currentStop.lat != null && currentStop.lng != null
        ? { lat: currentStop.lat, lng: currentStop.lng }
        : null;
    const dest: Coordinates | null =
      nextStop.lat != null && nextStop.lng != null
        ? { lat: nextStop.lat, lng: nextStop.lng }
        : null;

    const estimate = await RoutingProvider.getTravelTime(
      tripId,
      currentStop.id,
      nextStop.id,
      origin,
      dest,
      currentStop.transport_mode || 'driving',
      currentStop.planned_departure_at
    );

    const travelMs = estimate.durationSeconds * 1000;
    const safetyBufferMs = safetyBufferMinutes * 60 * 1000;

    // leave_at = next_stop.arrival_time - travel_time - safety_buffer
    const targetLeaveMs = nextArrTime - travelMs - safetyBufferMs;
    const leaveTimeUtc = new Date(targetLeaveMs).toISOString();

    // Check if departure time and leave time differ:
    // If user stay requires them to stay until depTime, effective leave is depTime.
    // If targetLeaveMs is earlier than depTime, the schedule is tight or impossible.
    const effectiveLeaveMs = Math.min(depTime, targetLeaveMs);
    const isImpossible = targetLeaveMs < depTime - 5 * 60 * 1000; // More than 5 min deficit
    const delayRiskMin = Math.max(0, Math.round((depTime - targetLeaveMs) / (60 * 1000)));

    return {
      currentStop,
      nextStop,
      travelDurationSeconds: estimate.durationSeconds,
      travelDistanceMeters: estimate.distanceMeters,
      isApproximate: estimate.isApproximate,
      routingSource: estimate.source,
      departureTimeUtc: currentStop.planned_departure_at,
      leaveTimeUtc,
      effectiveLeaveUtc: new Date(effectiveLeaveMs).toISOString(),
      isImpossibleSchedule: isImpossible,
      delayRiskMinutes: delayRiskMin,
    };
  }

  /**
   * Plan all scheduled alerts for a trip transition.
   */
  public static async planAlertsForTrip(tripId: string): Promise<AlertPlanItem[]> {
    const db = getDb();
    const tripStmt = db.prepare('SELECT user_id FROM trips WHERE id = ?');
    const trip = tripStmt.get(tripId) as any;
    if (!trip) return [];

    const userId = trip.user_id;

    // Load user preferences
    const prefStmt = db.prepare('SELECT * FROM notification_preferences WHERE user_id = ?');
    const prefs = (prefStmt.get(userId) || {
      push_enabled: 1,
      heads_up_enabled: 1,
      heads_up_lead_minutes: 15,
      leave_now_enabled: 1,
      go_to_next_enabled: 1,
      overdue_nag_enabled: 1,
      late_warning_enabled: 1,
      safety_buffer_minutes: 10,
      max_overdue_nags: 3,
    }) as any;

    if (!prefs.push_enabled) return [];

    const stopsStmt = db.prepare(`
      SELECT * FROM trip_stops
      WHERE trip_id = ? AND status != 'skipped'
      ORDER BY stop_order ASC
    `);
    const stops = stopsStmt.all(tripId) as TripStopRecord[];
    if (stops.length === 0) return [];

    const alerts: AlertPlanItem[] = [];
    const nowEpoch = Date.now();

    for (let i = 0; i < stops.length; i++) {
      const current = stops[i];
      if (current.status === 'departed' || current.status === 'skipped') {
        continue;
      }

      const next = i + 1 < stops.length ? stops[i + 1] : null;
      const transition = await this.calculateTransition(
        tripId,
        current,
        next,
        prefs.safety_buffer_minutes
      );

      const effectiveLeaveEpoch = new Date(transition.effectiveLeaveUtc).getTime();
      const depEpoch = new Date(transition.departureTimeUtc).getTime();
      const travelMin = Math.round(transition.travelDurationSeconds / 60);

      // 1. Heads-Up alert (e.g. 15 minutes before leave time)
      if (prefs.heads_up_enabled) {
        const headsUpLeadMs = prefs.heads_up_lead_minutes * 60 * 1000;
        const headsUpEpoch = effectiveLeaveEpoch - headsUpLeadMs;
        if (headsUpEpoch > nowEpoch - 60 * 1000) {
          const fireAtIso = new Date(headsUpEpoch).toISOString();
          alerts.push({
            type: 'heads_up',
            fireAtUtc: fireAtIso,
            notificationKey: this.makeNotificationKey(tripId, current.id, 'heads_up', fireAtIso),
            tripId,
            stopId: current.id,
            userId,
            context: {
              currentPlace: current.title,
              nextPlace: next ? next.title : undefined,
              minutesLead: prefs.heads_up_lead_minutes,
              travelDurationMin: travelMin,
            },
          });
        }
      }

      // 2. Leave Now alert (at departure time or stay expiration)
      if (prefs.leave_now_enabled) {
        const leaveNowEpoch = Math.min(depEpoch, effectiveLeaveEpoch);
        if (leaveNowEpoch > nowEpoch - 60 * 1000) {
          const fireAtIso = new Date(leaveNowEpoch).toISOString();
          alerts.push({
            type: 'leave_now',
            fireAtUtc: fireAtIso,
            notificationKey: this.makeNotificationKey(tripId, current.id, 'leave_now', fireAtIso),
            tripId,
            stopId: current.id,
            userId,
            context: {
              currentPlace: current.title,
              nextPlace: next ? next.title : undefined,
              travelDurationMin: travelMin,
            },
          });
        }
      }

      // 3. Go to Next Location alert (when traveling must begin to arrive on time)
      if (next && prefs.go_to_next_enabled) {
        const goToNextEpoch = new Date(transition.leaveTimeUtc).getTime();
        // If goToNextEpoch differs from leaveNow by more than 2 minutes, schedule it separately
        if (Math.abs(goToNextEpoch - depEpoch) > 2 * 60 * 1000 && goToNextEpoch > nowEpoch - 60 * 1000) {
          const fireAtIso = new Date(goToNextEpoch).toISOString();
          alerts.push({
            type: 'go_to_next',
            fireAtUtc: fireAtIso,
            notificationKey: this.makeNotificationKey(tripId, current.id, 'go_to_next', fireAtIso),
            tripId,
            stopId: current.id,
            userId,
            context: {
              currentPlace: current.title,
              nextPlace: next.title,
              travelDurationMin: travelMin,
              arrivalEstimateUtc: next.planned_arrival_at,
            },
          });
        }
      }

      // 4. Overdue Nag (5 & 12 min after leave time if still at stop)
      if (prefs.overdue_nag_enabled) {
        const nagOffsets = [5, 12, 20];
        const maxNags = Math.min(prefs.max_overdue_nags, nagOffsets.length);
        for (let n = 0; n < maxNags; n++) {
          const nagEpoch = effectiveLeaveEpoch + nagOffsets[n] * 60 * 1000;
          if (nagEpoch > nowEpoch - 60 * 1000) {
            const fireAtIso = new Date(nagEpoch).toISOString();
            alerts.push({
              type: 'overdue_nag',
              fireAtUtc: fireAtIso,
              notificationKey: this.makeNotificationKey(tripId, current.id, `overdue_nag_${n + 1}`, fireAtIso),
              tripId,
              stopId: current.id,
              userId,
              context: {
                currentPlace: current.title,
                nextPlace: next ? next.title : undefined,
                minutesLead: nagOffsets[n],
              },
            });
          }
        }
      }

      // 5. Late Warning (if departure delay puts next stop at risk)
      if (next && prefs.late_warning_enabled && transition.delayRiskMinutes > 5) {
        const warnEpoch = effectiveLeaveEpoch;
        if (warnEpoch > nowEpoch - 60 * 1000) {
          const fireAtIso = new Date(warnEpoch).toISOString();
          alerts.push({
            type: 'late_warning',
            fireAtUtc: fireAtIso,
            notificationKey: this.makeNotificationKey(tripId, current.id, 'late_warning', fireAtIso),
            tripId,
            stopId: current.id,
            userId,
            context: {
              currentPlace: current.title,
              nextPlace: next.title,
              minutesLead: transition.delayRiskMinutes,
            },
          });
        }
      }
    }

    return alerts;
  }

  /**
   * Reconciles scheduled_alerts table for a trip:
   * - Cancels or removes outdated pending alerts
   * - Inserts new planned alerts idempotently
   */
  public static async reconcileTripAlerts(tripId: string): Promise<number> {
    const db = getDb();
    const planned = await this.planAlertsForTrip(tripId);

    // Cancel pending alerts that are no longer in the plan
    const currentPendingStmt = db.prepare(`
      SELECT id, notification_key FROM scheduled_alerts
      WHERE trip_id = ? AND status = 'pending'
    `);
    const currentPending = currentPendingStmt.all(tripId) as any[];

    const plannedKeySet = new Set(planned.map((p) => p.notificationKey));
    const cancelStmt = db.prepare(`
      UPDATE scheduled_alerts
      SET status = 'cancelled', updated_at = ?
      WHERE id = ?
    `);

    const now = new Date().toISOString();
    for (const row of currentPending) {
      if (!plannedKeySet.has(row.notification_key)) {
        cancelStmt.run(now, row.id);
      }
    }

    // Insert new alerts idempotently (INSERT OR IGNORE via unique notification_key)
    const insertStmt = db.prepare(`
      INSERT OR IGNORE INTO scheduled_alerts (
        id, trip_id, stop_id, user_id, type, fire_at,
        notification_key, status, attempts, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', 0, ?, ?)
    `);

    let scheduledCount = 0;
    for (const a of planned) {
      const alertId = `alert_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
      const result = insertStmt.run(
        alertId,
        a.tripId,
        a.stopId,
        a.userId,
        a.type,
        a.fireAtUtc,
        a.notificationKey,
        now,
        now
      );
      if (result.changes > 0) {
        scheduledCount++;
      }
    }

    return scheduledCount;
  }
}
