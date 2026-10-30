import { getDb } from '../db';
import { FcmClient, FcmMessageSpec } from './fcm-client';

export interface AlertNotificationSpec {
  tripId: string;
  stopId: string;
  type: 'heads_up' | 'leave_now' | 'go_to_next' | 'overdue_nag' | 'late_warning';
  notificationKey: string;
  fireAtUtc: string;
  params: {
    place?: string;
    nextPlace?: string;
    minutes?: number;
    travelMinutes?: number;
    arrivalTime?: string;
  };
}

export interface SendResult {
  sentCount: number;
  failureCount: number;
  inboxId: string;
  skippedQuietHours?: boolean;
}

export class NotificationService {
  /**
   * Localized templates for notifications.
   */
  private static readonly TEMPLATES: Record<
    string,
    Record<string, { title: string; body: string }>
  > = {
    en: {
      heads_up: {
        title: 'Trip Alert: Prepare to Leave',
        body: 'Heads up! Prepare to leave {place} in {minutes} min.',
      },
      leave_now: {
        title: 'Time to Leave!',
        body: 'It is time to leave {place}.',
      },
      go_to_next: {
        title: 'Time to Head Out!',
        body: 'Depart now for {next_place} to arrive on time ({travelMinutes} min travel).',
      },
      overdue_nag: {
        title: 'Still at {place}?',
        body: 'You are {minutes} min past departure time. Tap "I\'m leaving" when ready.',
      },
      late_warning: {
        title: 'Running Behind Schedule',
        body: 'Departure delay puts arrival at {next_place} {minutes} min late.',
      },
    },
    hi: {
      heads_up: {
        title: 'यात्रा सूचना: निकलने की तैयारी करें',
        body: 'ध्यान दें! {minutes} मिनट में {place} से निकलने की तैयारी करें।',
      },
      leave_now: {
        title: 'निकलने का समय हो गया!',
        body: '{place} से निकलने का समय आ गया है।',
      },
      go_to_next: {
        title: 'अगले स्थान के लिए निकलें!',
        body: 'समय पर पहुँचने के लिए {next_place} के लिए अभी प्रस्थान करें ({travelMinutes} मिनट यात्रा)।',
      },
      overdue_nag: {
        title: 'क्या आप अभी भी {place} पर हैं?',
        body: 'आप प्रस्थान समय से {minutes} मिनट देर हैं। तैयार होने पर "मैं निकल रहा हूँ" दबाएँ।',
      },
      late_warning: {
        title: 'शेड्यूल से पीछे चल रहे हैं',
        body: 'देरी के कारण {next_place} पहुँचने में {minutes} मिनट की देरी हो सकती है।',
      },
    },
    es: {
      heads_up: {
        title: 'Alerta de Viaje: Prepárate',
        body: '¡Atención! Prepárate para salir de {place} en {minutes} min.',
      },
      leave_now: {
        title: '¡Hora de Salir!',
        body: 'Es hora de salir de {place}.',
      },
      go_to_next: {
        title: '¡Hora de Ir al Siguiente Lugar!',
        body: 'Sal ahora hacia {next_place} para llegar a tiempo ({travelMinutes} min de viaje).',
      },
      overdue_nag: {
        title: '¿Sigues en {place}?',
        body: 'Llevas {minutes} min de retraso. Toca "Me voy" cuando estés listo.',
      },
      late_warning: {
        title: 'Retraso en el Itinerario',
        body: 'La demora pone en riesgo tu llegada a {next_place} con {minutes} min de retraso.',
      },
    },
    ar: {
      heads_up: {
        title: 'تنبيه الرحلة: استعد للمغادرة',
        body: 'تنبيه! استعد لمغادرة {place} خلال {minutes} دقائق.',
      },
      leave_now: {
        title: 'حان وقت المغادرة!',
        body: 'حان وقت مغادرة {place}.',
      },
      go_to_next: {
        title: 'حان وقت الذهاب للوجهة التالية!',
        body: 'انطلق الآن إلى {next_place} لتصل في الوقت المحدد ({travelMinutes} دقيقة سفر).',
      },
      overdue_nag: {
        title: 'هل ما زلت في {place}؟',
        body: 'لقد تأخرت {minutes} دقائق عن موعد المغادرة. اضغط "أنا مغادر" عند الاستعداد.',
      },
      late_warning: {
        title: 'تأخر عن الجدول المحدد',
        body: 'التأخير سيجعل وصولك إلى {next_place} متأخرًا بمقدار {minutes} دقيقة.',
      },
    },
  };

  /**
   * Resolves template strings with parameter substitution.
   */
  public static renderTemplate(
    type: string,
    lang: string,
    params: Record<string, any>
  ): { title: string; body: string } {
    const langDict = this.TEMPLATES[lang] || this.TEMPLATES.en;
    const template = langDict[type] || this.TEMPLATES.en[type] || {
      title: 'Trip Alert',
      body: 'Time to make your next move.',
    };

    let title = template.title;
    let body = template.body;

    for (const [key, val] of Object.entries(params)) {
      if (val !== undefined && val !== null) {
        title = title.replaceAll(`{${key}}`, String(val));
        body = body.replaceAll(`{${key}}`, String(val));
      }
    }

    return { title, body };
  }

  /**
   * Checks whether the current time falls inside quiet hours.
   */
  public static isQuietHours(prefs: any): boolean {
    if (!prefs.quiet_hours_enabled) return false;
    const now = new Date();
    const currentMin = now.getHours() * 60 + now.getMinutes();

    const [startH, startM] = prefs.quiet_hours_start.split(':').map(Number);
    const [endH, endM] = prefs.quiet_hours_end.split(':').map(Number);
    const startMin = startH * 60 + startM;
    const endMin = endH * 60 + endM;

    if (startMin <= endMin) {
      return currentMin >= startMin && currentMin < endMin;
    } else {
      // Overnight (e.g. 22:00 to 07:00)
      return currentMin >= startMin || currentMin < endMin;
    }
  }

  /**
   * Sends an alert notification to a user's registered devices and writes to inbox.
   */
  public static async sendToUser(
    userId: string,
    spec: AlertNotificationSpec
  ): Promise<SendResult> {
    const db = getDb();

    // 1. Fetch user & preferences
    const userStmt = db.prepare('SELECT preferred_language FROM users WHERE id = ?');
    const user = userStmt.get(userId) as any;
    const userLang = user?.preferred_language || 'en';

    const prefsStmt = db.prepare('SELECT * FROM notification_preferences WHERE user_id = ?');
    const prefs = (prefsStmt.get(userId) || {
      push_enabled: 1,
      quiet_hours_enabled: 0,
      allow_trip_override_quiet_hours: 1,
    }) as any;

    if (!prefs.push_enabled) {
      return { sentCount: 0, failureCount: 0, inboxId: '' };
    }

    // Check quiet hours override
    if (this.isQuietHours(prefs) && !prefs.allow_trip_override_quiet_hours) {
      return { sentCount: 0, failureCount: 0, inboxId: '', skippedQuietHours: true };
    }

    // 2. Format localized title & body
    const { title, body } = this.renderTemplate(spec.type, userLang, {
      place: spec.params.place || 'Current place',
      next_place: spec.params.nextPlace || 'Next stop',
      minutes: spec.params.minutes || 15,
      travelMinutes: spec.params.travelMinutes || 20,
      arrivalTime: spec.params.arrivalTime || '',
    });

    // 3. Write to in-app inbox
    const inboxId = `notif_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    const nowIso = new Date().toISOString();
    const deepLink = `/trips/${spec.tripId}/stops/${spec.stopId}`;

    const dataPayload = {
      type: spec.type,
      tripId: spec.tripId,
      stopId: spec.stopId,
      notification_key: spec.notificationKey,
      leave_at: spec.fireAtUtc,
      deep_link: deepLink,
    };

    const insertInbox = db.prepare(`
      INSERT INTO notifications (
        id, user_id, trip_id, stop_id, type, title, body,
        data_payload, notification_key, is_read, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
    `);
    insertInbox.run(
      inboxId,
      userId,
      spec.tripId,
      spec.stopId,
      spec.type,
      title,
      body,
      JSON.stringify(dataPayload),
      spec.notificationKey,
      nowIso
    );

    // 4. Query active device tokens
    const tokensStmt = db.prepare(`
      SELECT id, token, platform FROM device_tokens
      WHERE user_id = ? AND is_active = 1
    `);
    const activeTokens = tokensStmt.all(userId) as any[];

    let sentCount = 0;
    let failureCount = 0;

    const deactivateStmt = db.prepare(`
      UPDATE device_tokens
      SET is_active = 0, last_seen_at = ?
      WHERE token = ?
    `);

    // 5. Dispatch to all active tokens
    for (const dt of activeTokens) {
      const msgSpec: FcmMessageSpec = {
        token: dt.token,
        title,
        body,
        data: dataPayload,
        priority: 'high',
        ttlSeconds: 900, // 15 minutes TTL for timely alerts
        collapseKey: `${spec.tripId}_${spec.stopId}`,
      };

      const result = await FcmClient.sendMessage(msgSpec);
      if (result.success) {
        sentCount++;
      } else {
        failureCount++;
        if (result.isUnregistered) {
          deactivateStmt.run(nowIso, dt.token);
        }
      }
    }

    return { sentCount, failureCount, inboxId };
  }
}
