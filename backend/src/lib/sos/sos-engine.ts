import { getDb } from '../db';
import { HospitalProvider, HospitalInfo } from './hospital-provider';
import { SmsProvider } from './sms-provider';
import { NotificationService } from '../notifications/notification-service';

export interface ItinerarySnapshot {
  tripId?: string;
  tripTitle?: string;
  cityName?: string;
  currentStop?: { id: string; title: string; plannedArrival: string; plannedDeparture: string };
  nextStop?: { id: string; title: string; plannedArrival: string };
  totalStopsCount: number;
}

export interface TriggerSosParams {
  sosId: string; // Client-generated UUID
  userId: string;
  lat: number;
  lng: number;
  accuracyM?: number;
  locationSource?: string;
  tripId?: string;
  triggerSource?: string;
  batteryPercent?: number;
  clientSentSmsContacts?: string[]; // Contact IDs already sent via device SMS
}

export interface ContactDeliveryReport {
  contactId: string;
  contactName: string;
  phone: string;
  channels: {
    channel: 'sms' | 'push' | 'whatsapp';
    status: 'sent' | 'delivered' | 'failed' | 'skipped_client_sent';
    providerMessageId?: string;
    error?: string;
  }[];
}

export interface SosEventSummary {
  sosId: string;
  status: string;
  triggeredAt: string;
  lat: number;
  lng: number;
  accuracyM: number;
  hospitals: HospitalInfo[];
  itinerarySnapshot: ItinerarySnapshot | null;
  deliveries: ContactDeliveryReport[];
}

export class SosEngine {
  /**
   * Builds an itinerary snapshot from database trip records.
   */
  public static buildItinerarySnapshot(tripId?: string, userId: string = 'user_demo'): ItinerarySnapshot | null {
    const db = getDb();
    let targetTripId = tripId;

    if (!targetTripId) {
      const activeTripStmt = db.prepare(`
        SELECT id FROM trips
        WHERE user_id = ? AND status = 'active'
        ORDER BY created_at DESC LIMIT 1
      `);
      const row = activeTripStmt.get(userId) as any;
      targetTripId = row?.id;
    }

    if (!targetTripId) return null;

    const tripStmt = db.prepare('SELECT title, city_name FROM trips WHERE id = ?');
    const trip = tripStmt.get(targetTripId) as any;
    if (!trip) return null;

    const stopsStmt = db.prepare(`
      SELECT id, title, planned_arrival_at, planned_departure_at, status
      FROM trip_stops
      WHERE trip_id = ?
      ORDER BY stop_order ASC
    `);
    const stops = stopsStmt.all(targetTripId) as any[];
    if (stops.length === 0) {
      return { tripId: targetTripId, tripTitle: trip.title, cityName: trip.city_name, totalStopsCount: 0 };
    }

    const current = stops.find((s) => s.status === 'arrived' || s.status === 'upcoming') || stops[0];
    const currentIndex = stops.findIndex((s) => s.id === current.id);
    const next = currentIndex + 1 < stops.length ? stops[currentIndex + 1] : undefined;

    return {
      tripId: targetTripId,
      tripTitle: trip.title,
      cityName: trip.city_name,
      currentStop: {
        id: current.id,
        title: current.title,
        plannedArrival: current.planned_arrival_at,
        plannedDeparture: current.planned_departure_at,
      },
      nextStop: next ? { id: next.id, title: next.title, plannedArrival: next.planned_arrival_at } : undefined,
      totalStopsCount: stops.length,
    };
  }

  /**
   * Composes localized alert SMS message.
   */
  public static composeAlertMessage(
    userName: string,
    lat: number,
    lng: number,
    accuracyM: number,
    snapshot: ItinerarySnapshot | null,
    hospital: HospitalInfo | null,
    medicalText: string | null,
    language: string = 'en',
    batteryPercent?: number
  ): string {
    const mapUrl = `https://www.google.com/maps?q=${lat},${lng}`;
    const hospDistKm = hospital ? (hospital.distanceMeters / 1000).toFixed(1) : null;
    const timeStr = new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });

    if (language === 'hi') {
      let msg = `आपातकालीन सूचना: ${userName} को सहायता की आवश्यकता है!`;
      msg += `\nस्थान: ${mapUrl} (सटीकता ~${accuracyM}m, ${timeStr})`;
      if (snapshot?.currentStop) {
        msg += `\nयात्रा: ${snapshot.tripTitle || 'सफर'}, स्थान: ${snapshot.currentStop.title}`;
        if (snapshot.nextStop) msg += `, अगला: ${snapshot.nextStop.title}`;
      }
      if (hospital) {
        msg += `\nनिकटतम अस्पताल: ${hospital.name} (~${hospDistKm}km)`;
      }
      if (batteryPercent != null) {
        msg += `\nफ़ोन बैटरी: ${batteryPercent}%`;
      }
      if (medicalText) {
        msg += `\nस्वास्थ्य जानकारी: ${medicalText}`;
      }
      return msg;
    }

    let msg = `EMERGENCY ALERT: ${userName} may need urgent help!`;
    msg += `\nLocation: ${mapUrl} (accuracy ~${accuracyM}m at ${timeStr})`;
    if (snapshot?.currentStop) {
      msg += `\nTrip: ${snapshot.tripTitle || 'Trip'}, at: ${snapshot.currentStop.title}`;
      if (snapshot.nextStop) msg += `, next: ${snapshot.nextStop.title}`;
    }
    if (hospital) {
      msg += `\nNearest Hospital: ${hospital.name} (~${hospDistKm}km) - ${hospital.navigationUrl}`;
    }
    if (batteryPercent != null) {
      msg += `\nBattery: ${batteryPercent}%`;
    }
    if (medicalText) {
      msg += `\nMedical: ${medicalText}`;
    }

    return msg;
  }

  /**
   * Main SOS Trigger Handler.
   */
  public static async triggerSos(params: TriggerSosParams): Promise<SosEventSummary> {
    const db = getDb();
    const nowIso = new Date().toISOString();
    const {
      sosId,
      userId,
      lat,
      lng,
      accuracyM = 10,
      locationSource = 'gps',
      tripId,
      triggerSource = 'home',
      batteryPercent,
      clientSentSmsContacts = [],
    } = params;

    // 1. Idempotency Check: if event already exists, return existing record
    const existingStmt = db.prepare('SELECT * FROM sos_events WHERE id = ?');
    const existing = existingStmt.get(sosId) as any;

    if (existing) {
      const hospitals = await HospitalProvider.findNearby(existing.initial_lat, existing.initial_lng, 5000, 3);
      const delStmt = db.prepare(`
        SELECT d.*, c.name as contact_name, c.phone_e164
        FROM sos_deliveries d
        LEFT JOIN emergency_contacts c ON d.contact_id = c.id
        WHERE d.sos_id = ?
      `);
      const recorded = delStmt.all(sosId) as any[];
      const contactMap = new Map<string, ContactDeliveryReport>();
      for (const row of recorded) {
        if (!contactMap.has(row.contact_id)) {
          contactMap.set(row.contact_id, {
            contactId: row.contact_id,
            contactName: row.contact_name || 'Contact',
            phone: row.phone_e164 || '',
            channels: [],
          });
        }
        contactMap.get(row.contact_id)!.channels.push({
          channel: row.channel,
          status: row.status,
          providerMessageId: row.provider_message_id,
        });
      }

      return {
        sosId: existing.id,
        status: existing.status,
        triggeredAt: existing.triggered_at,
        lat: existing.initial_lat,
        lng: existing.initial_lng,
        accuracyM: existing.accuracy_m,
        hospitals,
        itinerarySnapshot: existing.itinerary_snapshot ? JSON.parse(existing.itinerary_snapshot) : null,
        deliveries: Array.from(contactMap.values()),
      };
    }

    // 2. Fetch User & Medical Info
    const userStmt = db.prepare('SELECT name, preferred_language FROM users WHERE id = ?');
    const user = (userStmt.get(userId) || { name: 'Traveler', preferred_language: 'en' }) as any;

    const medStmt = db.prepare('SELECT * FROM user_medical_profiles WHERE user_id = ?');
    const medProfile = medStmt.get(userId) as any;
    let medicalSummary: string | null = null;
    if (medProfile?.include_in_sos) {
      const parts = [];
      if (medProfile.blood_group) parts.push(`Blood: ${medProfile.blood_group}`);
      if (medProfile.allergies) parts.push(`Allergies: ${medProfile.allergies}`);
      if (medProfile.medical_conditions) parts.push(`Conditions: ${medProfile.medical_conditions}`);
      if (parts.length > 0) medicalSummary = parts.join(', ');
    }

    // 3. Build Itinerary Snapshot & Fetch Hospitals in parallel
    const snapshot = this.buildItinerarySnapshot(tripId, userId);
    const hospitals = await HospitalProvider.findNearby(lat, lng, 5000, 3);
    const topHospital = hospitals[0] || null;

    // 4. Save SOS Event & Initial Location Trail
    const insertSos = db.prepare(`
      INSERT INTO sos_events (
        id, user_id, trip_id, status, trigger_source, triggered_at,
        initial_lat, initial_lng, accuracy_m, location_source, battery_percent,
        itinerary_snapshot, medical_info_included, created_at, updated_at
      ) VALUES (?, ?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    insertSos.run(
      sosId,
      userId,
      tripId || snapshot?.tripId || null,
      triggerSource,
      nowIso,
      lat,
      lng,
      accuracyM,
      locationSource,
      batteryPercent ?? null,
      snapshot ? JSON.stringify(snapshot) : null,
      medicalSummary ? 1 : 0,
      nowIso,
      nowIso
    );

    const insertLoc = db.prepare(`
      INSERT INTO sos_location_updates (id, sos_id, lat, lng, accuracy_m, recorded_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    insertLoc.run(`loc_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`, sosId, lat, lng, accuracyM, nowIso);

    // 5. Query Emergency Contacts
    const contactsStmt = db.prepare(`
      SELECT * FROM emergency_contacts
      WHERE user_id = ?
      ORDER BY priority ASC
    `);
    const contacts = contactsStmt.all(userId) as any[];

    // 6. Multi-Channel Parallel Dispatching
    const deliveries: ContactDeliveryReport[] = [];
    const clientSentSet = new Set(clientSentSmsContacts);

    const insertDelivery = db.prepare(`
      INSERT INTO sos_deliveries (
        id, sos_id, contact_id, channel, provider, provider_message_id,
        status, error_code, sent_at, kind
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'initial')
    `);

    for (const c of contacts) {
      const contactReport: ContactDeliveryReport = {
        contactId: c.id,
        contactName: c.name,
        phone: c.phone_e164,
        channels: [],
      };

      const preferredChannels = (c.preferred_channels || 'sms,push').split(',');
      const contactLang = c.language || user.preferred_language || 'en';
      const alertText = this.composeAlertMessage(
        user.name,
        lat,
        lng,
        accuracyM,
        snapshot,
        topHospital,
        medicalSummary,
        contactLang,
        batteryPercent
      );

      // Channel B: Server SMS
      if (preferredChannels.includes('sms')) {
        if (clientSentSet.has(c.id)) {
          contactReport.channels.push({
            channel: 'sms',
            status: 'skipped_client_sent',
          });
        } else {
          const smsRes = await SmsProvider.send({
            to: c.phone_e164,
            body: alertText,
          });

          const deliveryId = `del_sms_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
          insertDelivery.run(
            deliveryId,
            sosId,
            c.id,
            'sms',
            smsRes.provider,
            smsRes.messageId || null,
            smsRes.success ? 'sent' : 'failed',
            smsRes.error || null,
            nowIso
          );

          contactReport.channels.push({
            channel: 'sms',
            status: smsRes.success ? 'sent' : 'failed',
            providerMessageId: smsRes.messageId,
            error: smsRes.error,
          });
        }
      }

      // Channel C: High Priority Push to Registered User Contacts
      if (preferredChannels.includes('push')) {
        const contactUserStmt = db.prepare('SELECT id FROM users WHERE email = ?');
        const contactUser = c.email ? (contactUserStmt.get(c.email) as any) : null;

        if (contactUser) {
          const pushRes = await NotificationService.sendToUser(contactUser.id, {
            tripId: tripId || 'sos_trip',
            stopId: 'sos_alert',
            type: 'late_warning',
            notificationKey: `sos:${sosId}:${c.id}`,
            fireAtUtc: nowIso,
            params: {
              place: `${user.name} - SOS Emergency Alert!`,
              nextPlace: snapshot?.currentStop?.title || 'Current Location',
            },
          });

          const deliveryId = `del_push_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
          insertDelivery.run(
            deliveryId,
            sosId,
            c.id,
            'push',
            'fcm_http_v1',
            pushRes.inboxId || null,
            pushRes.sentCount > 0 ? 'delivered' : 'failed',
            pushRes.failureCount > 0 ? 'FCM delivery failed' : null,
            nowIso
          );

          contactReport.channels.push({
            channel: 'push',
            status: pushRes.sentCount > 0 ? 'delivered' : 'failed',
            providerMessageId: pushRes.inboxId,
          });
        }
      }

      deliveries.push(contactReport);
    }

    return {
      sosId,
      status: 'active',
      triggeredAt: nowIso,
      lat,
      lng,
      accuracyM,
      hospitals,
      itinerarySnapshot: snapshot,
      deliveries,
    };
  }

  /**
   * Appends live location trail update during an active SOS.
   */
  public static updateLocation(sosId: string, lat: number, lng: number, accuracyM: number = 10): boolean {
    const db = getDb();
    const nowIso = new Date().toISOString();

    const check = db.prepare("SELECT id, status FROM sos_events WHERE id = ? AND status = 'active'").get(sosId);
    if (!check) return false;

    const insertLoc = db.prepare(`
      INSERT INTO sos_location_updates (id, sos_id, lat, lng, accuracy_m, recorded_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    insertLoc.run(`loc_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`, sosId, lat, lng, accuracyM, nowIso);

    db.prepare('UPDATE sos_events SET updated_at = ? WHERE id = ?').run(nowIso, sosId);
    return true;
  }

  /**
   * Marks user safe and notifies emergency contacts.
   */
  public static async resolveSafe(sosId: string, userId: string = 'user_demo'): Promise<boolean> {
    const db = getDb();
    const nowIso = new Date().toISOString();

    const updateStmt = db.prepare(`
      UPDATE sos_events
      SET status = 'resolved_safe', resolved_at = ?, updated_at = ?
      WHERE id = ? AND user_id = ?
    `);
    const res = updateStmt.run(nowIso, nowIso, sosId, userId);
    if (res.changes === 0) return false;

    // Send "I'm safe" notice to emergency contacts
    const contacts = db.prepare('SELECT phone_e164, language FROM emergency_contacts WHERE user_id = ?').all(userId) as any[];
    for (const c of contacts) {
      const safeMsg =
        c.language === 'hi'
          ? 'सूचना: यात्री सुरक्षित है। आपातकालीन अलर्ट समाप्त कर दिया गया है।'
          : 'UPDATE: Traveler has marked themselves SAFE. The emergency alert has ended.';
      await SmsProvider.send({ to: c.phone_e164, body: safeMsg });
    }

    return true;
  }

  /**
   * Cancels SOS during countdown or flags false alarm.
   */
  public static async cancelOrFalseAlarm(sosId: string, userId: string = 'user_demo', isFalseAlarm: boolean = false): Promise<boolean> {
    const db = getDb();
    const nowIso = new Date().toISOString();
    const newStatus = isFalseAlarm ? 'false_alarm' : 'cancelled';

    const updateStmt = db.prepare(`
      UPDATE sos_events
      SET status = ?, resolved_at = ?, updated_at = ?
      WHERE id = ? AND user_id = ?
    `);
    const res = updateStmt.run(newStatus, nowIso, nowIso, sosId, userId);
    if (res.changes === 0) return false;

    // Send false alarm message to contacts who got alerts
    const contacts = db.prepare('SELECT phone_e164, language FROM emergency_contacts WHERE user_id = ?').all(userId) as any[];
    for (const c of contacts) {
      const cancelMsg =
        c.language === 'hi'
          ? 'सूचना: पूर्व आपातकालीन अलर्ट रद्द कर दिया गया है (झूठा अलर्ट)। यात्री सुरक्षित है।'
          : 'NOTICE: Previous emergency alert was cancelled (false alarm). Traveler is safe.';
      await SmsProvider.send({ to: c.phone_e164, body: cancelMsg });
    }

    return true;
  }
}
