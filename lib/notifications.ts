import { Platform, Linking } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

export interface AlertItem {
  id: string;
  stopId: string;
  stopTitle: string;
  stopOrder: number;
  type: 'heads_up' | 'leave_now' | 'go_to_next' | 'overdue_nag' | 'late_warning';
  fireAt: string;
  notificationKey: string;
  status: string;
}

export interface TravelEstimateItem {
  fromStopId: string;
  toStopId: string;
  mode: string;
  durationSeconds: number;
  distanceMeters: number;
  source: string;
  isApproximate: boolean;
}

export interface NotificationPreferences {
  userId: string;
  pushEnabled: boolean;
  headsUpEnabled: boolean;
  headsUpLeadMinutes: number;
  leaveNowEnabled: boolean;
  goToNextEnabled: boolean;
  overdueNagEnabled: boolean;
  lateWarningEnabled: boolean;
  safetyBufferMinutes: number;
  defaultTransportMode: string;
  quietHoursEnabled: boolean;
  quietHoursStart: string;
  quietHoursEnd: string;
  allowTripOverrideQuietHours: boolean;
  locationSmartModeEnabled: boolean;
  maxOverdueNags: number;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
const SHOWN_KEYS_STORAGE = 'ghumify_shown_notif_keys';
const OFFLINE_ACTIONS_QUEUE = 'ghumify_offline_actions';

export class NotificationClient {
  private static registeredToken: string | null = null;
  private static activeTimers: Map<string, NodeJS.Timeout> = new Map();

  /**
   * Initializes local notification listeners and registers device token.
   */
  public static async init(userId: string = 'user_demo', preferredLanguage: string = 'en') {
    try {
      // Generate or retrieve persistent pseudo-FCM token for local testing
      let token = await AsyncStorage.getItem('ghumify_fcm_token');
      if (!token) {
        token = `fcm_${Platform.OS}_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
        await AsyncStorage.setItem('ghumify_fcm_token', token);
      }
      this.registeredToken = token;

      // Register with backend
      await this.registerTokenWithBackend(token, userId, preferredLanguage);

      // Flush any queued offline actions
      await this.flushOfflineQueue();
    } catch (err) {
      console.warn('[NotificationClient] Init warning:', err);
    }
  }

  /**
   * Registers FCM token with backend.
   */
  public static async registerTokenWithBackend(
    token: string,
    userId: string = 'user_demo',
    language: string = 'en'
  ) {
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/notifications/tokens`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token,
          userId,
          platform: Platform.OS,
          language,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
        }),
      });
      return res.ok;
    } catch {
      return false;
    }
  }

  /**
   * Unregisters token on user logout.
   */
  public static async unregisterToken(): Promise<boolean> {
    if (!this.registeredToken) return true;
    try {
      await fetch(
        `${BACKEND_URL}/api/v1/notifications/tokens?token=${encodeURIComponent(this.registeredToken)}`,
        { method: 'DELETE' }
      );
      this.registeredToken = null;
      await AsyncStorage.removeItem('ghumify_fcm_token');
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Layer 2: Schedules local notification backup alarms for a trip's alerts.
   * Ensures deduplication via shared notificationKey.
   */
  public static async scheduleLocalBackupAlerts(
    tripId: string,
    alerts: AlertItem[],
    onTrigger?: (alert: AlertItem) => void
  ) {
    // Clear previously scheduled timers
    for (const timer of this.activeTimers.values()) {
      clearTimeout(timer);
    }
    this.activeTimers.clear();

    const now = Date.now();
    const shownRaw = await AsyncStorage.getItem(SHOWN_KEYS_STORAGE);
    const shownKeys: Set<string> = new Set(shownRaw ? JSON.parse(shownRaw) : []);

    for (const alert of alerts) {
      // Skip if already shown by push or previously triggered
      if (shownKeys.has(alert.notificationKey)) continue;

      const fireEpoch = new Date(alert.fireAt).getTime();
      const delayMs = fireEpoch - now;

      // Only schedule if within next 24 hours and not in the past
      if (delayMs > 0 && delayMs < 24 * 60 * 60 * 1000) {
        const timer = setTimeout(async () => {
          // Re-check deduplication
          const updatedShown = await AsyncStorage.getItem(SHOWN_KEYS_STORAGE);
          const currentSet: Set<string> = new Set(updatedShown ? JSON.parse(updatedShown) : []);
          if (!currentSet.has(alert.notificationKey)) {
            currentSet.add(alert.notificationKey);
            await AsyncStorage.setItem(SHOWN_KEYS_STORAGE, JSON.stringify([...currentSet]));

            if (onTrigger) {
              onTrigger(alert);
            }
          }
        }, delayMs);

        this.activeTimers.set(alert.notificationKey, timer);
      }
    }
  }

  /**
   * Marks a notification key as displayed (e.g. when FCM push arrives in foreground/background).
   */
  public static async recordPushDisplayed(notificationKey: string) {
    try {
      const shownRaw = await AsyncStorage.getItem(SHOWN_KEYS_STORAGE);
      const shownKeys: Set<string> = new Set(shownRaw ? JSON.parse(shownRaw) : []);
      shownKeys.add(notificationKey);
      await AsyncStorage.setItem(SHOWN_KEYS_STORAGE, JSON.stringify([...shownKeys]));

      // Cancel matching local timer if still waiting
      if (this.activeTimers.has(notificationKey)) {
        clearTimeout(this.activeTimers.get(notificationKey)!);
        this.activeTimers.delete(notificationKey);
      }
    } catch {}
  }

  /**
   * Action: "I'm leaving" -> calls departed endpoint or queues offline.
   */
  public static async handleDeparted(tripId: string, stopId: string): Promise<boolean> {
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/trips/${tripId}/stops/${stopId}/departed`, {
        method: 'POST',
      });
      if (res.ok) return true;
      throw new Error('Server returned non-200');
    } catch {
      await this.queueOfflineAction({
        action: 'departed',
        tripId,
        stopId,
        timestamp: new Date().toISOString(),
      });
      return false;
    }
  }

  /**
   * Action: "Arrived" -> calls arrived endpoint or queues offline.
   */
  public static async handleArrived(tripId: string, stopId: string): Promise<boolean> {
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/trips/${tripId}/stops/${stopId}/arrived`, {
        method: 'POST',
      });
      if (res.ok) return true;
      throw new Error('Server returned non-200');
    } catch {
      await this.queueOfflineAction({
        action: 'arrived',
        tripId,
        stopId,
        timestamp: new Date().toISOString(),
      });
      return false;
    }
  }

  /**
   * Action: "Snooze" -> calls snooze endpoint or queues offline.
   */
  public static async handleSnooze(alertId: string, minutes: number = 10): Promise<boolean> {
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/alerts/${alertId}/snooze`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ minutes }),
      });
      return res.ok;
    } catch {
      await this.queueOfflineAction({
        action: 'snooze',
        alertId,
        minutes,
        timestamp: new Date().toISOString(),
      });
      return false;
    }
  }

  /**
   * Action: "Navigate" -> opens native maps application with destination coordinates.
   */
  public static openNavigation(lat: number, lng: number, placeName?: string) {
    const label = encodeURIComponent(placeName || 'Destination');
    const url =
      Platform.OS === 'ios'
        ? `maps:0,0?q=${label}@${lat},${lng}`
        : `geo:0,0?q=${lat},${lng}(${label})`;

    const webFallback = `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`;

    Linking.canOpenURL(url).then((supported) => {
      if (supported) {
        Linking.openURL(url);
      } else {
        Linking.openURL(webFallback);
      }
    });
  }

  /**
   * Queues offline actions when phone cannot reach local server.
   */
  private static async queueOfflineAction(action: Record<string, any>) {
    try {
      const raw = await AsyncStorage.getItem(OFFLINE_ACTIONS_QUEUE);
      const queue = raw ? JSON.parse(raw) : [];
      queue.push(action);
      await AsyncStorage.setItem(OFFLINE_ACTIONS_QUEUE, JSON.stringify(queue));
    } catch {}
  }

  /**
   * Dispatches queued offline actions when connection resumes.
   */
  public static async flushOfflineQueue() {
    try {
      const raw = await AsyncStorage.getItem(OFFLINE_ACTIONS_QUEUE);
      if (!raw) return;
      const queue = JSON.parse(raw);
      if (!Array.isArray(queue) || queue.length === 0) return;

      const remaining = [];
      for (const item of queue) {
        try {
          if (item.action === 'departed') {
            await fetch(`${BACKEND_URL}/api/v1/trips/${item.tripId}/stops/${item.stopId}/departed`, {
              method: 'POST',
            });
          } else if (item.action === 'arrived') {
            await fetch(`${BACKEND_URL}/api/v1/trips/${item.tripId}/stops/${item.stopId}/arrived`, {
              method: 'POST',
            });
          } else if (item.action === 'snooze') {
            await fetch(`${BACKEND_URL}/api/v1/alerts/${item.alertId}/snooze`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ minutes: item.minutes }),
            });
          }
        } catch {
          remaining.push(item);
        }
      }

      await AsyncStorage.setItem(OFFLINE_ACTIONS_QUEUE, JSON.stringify(remaining));
    } catch {}
  }
}
