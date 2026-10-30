import { Platform, Linking } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

export interface EmergencyContact {
  id: string;
  name: string;
  phone: string;
  relationship: string;
  priority: number;
  preferredChannels: string[];
  language: string;
  email?: string;
  isVerified: boolean;
}

export interface NearbyHospital {
  id: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
  distanceMeters: number;
  phone?: string;
  hasEmergencyDepartment: boolean;
  isOpen24Hours: boolean;
  navigationUrl: string;
}

export interface DeliveryStatusItem {
  id: string;
  contactName: string;
  phone: string;
  channel: string;
  status: string;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
const OFFLINE_SOS_STORAGE = 'ghumify_offline_sos_queue';
const LAST_KNOWN_LOCATION_STORAGE = 'ghumify_last_known_location';

export class SosClient {
  private static liveInterval: NodeJS.Timeout | null = null;

  /**
   * Generates a standard RFC4122 v4 UUID for idempotent SOS identification.
   */
  public static generateUuid(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  /**
   * Saves last known good coordinates to local storage for instant fallback.
   */
  public static async saveLastKnownLocation(lat: number, lng: number, accuracyM: number = 10) {
    try {
      await AsyncStorage.setItem(
        LAST_KNOWN_LOCATION_STORAGE,
        JSON.stringify({ lat, lng, accuracyM, timestamp: Date.now() })
      );
    } catch {}
  }

  /**
   * Retrieves current GPS coordinates with fallback to cached last-known location.
   */
  public static async getCurrentLocation(): Promise<{ lat: number; lng: number; accuracyM: number; source: string }> {
    // 1. Try browser / React Native navigator.geolocation
    if (typeof navigator !== 'undefined' && navigator.geolocation) {
      try {
        const position = await new Promise<GeolocationPosition>((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, {
            enableHighAccuracy: true,
            timeout: 5000,
            maximumAge: 10000,
          });
        });
        const lat = position.coords.latitude;
        const lng = position.coords.longitude;
        const accuracyM = Math.round(position.coords.accuracy || 10);
        await this.saveLastKnownLocation(lat, lng, accuracyM);
        return { lat, lng, accuracyM, source: 'gps' };
      } catch {
        // GPS fix failed or timed out -> continue to fallback
      }
    }

    // 2. Check local storage last-known location
    try {
      const cachedRaw = await AsyncStorage.getItem(LAST_KNOWN_LOCATION_STORAGE);
      if (cachedRaw) {
        const cached = JSON.parse(cachedRaw);
        return {
          lat: cached.lat,
          lng: cached.lng,
          accuracyM: cached.accuracyM || 50,
          source: 'last_known',
        };
      }
    } catch {}

    // 3. Ultimate regional default: Jaipur heritage center
    return { lat: 26.9124, lng: 75.7873, accuracyM: 100, source: 'default_fallback' };
  }

  /**
   * Dials regional emergency phone number (112 in India/Europe, 911 in US, 999 in UK).
   */
  public static callEmergencyServices(emergencyNumber: string = '112') {
    const url = `tel:${emergencyNumber}`;
    Linking.canOpenURL(url).then((supported) => {
      if (supported) {
        Linking.openURL(url);
      }
    });
  }

  /**
   * Channel A: Prepares and fires device-side SMS to emergency contacts.
   */
  public static async sendDeviceSms(
    contacts: EmergencyContact[],
    lat: number,
    lng: number,
    userName: string = 'Traveler',
    currentStopName?: string
  ): Promise<boolean> {
    if (contacts.length === 0) return false;

    const phones = contacts.map((c) => c.phone).join(',');
    const mapUrl = `https://www.google.com/maps?q=${lat},${lng}`;
    let body = `EMERGENCY SOS from ${userName}! Location: ${mapUrl}`;
    if (currentStopName) {
      body += ` (near ${currentStopName})`;
    }
    body += `. Please help or call emergency services.`;

    const encodedBody = encodeURIComponent(body);
    const smsUrl =
      Platform.OS === 'ios'
        ? `sms:${phones}&body=${encodedBody}`
        : `sms:${phones}?body=${encodedBody}`;

    try {
      const supported = await Linking.canOpenURL(smsUrl);
      if (supported) {
        await Linking.openURL(smsUrl);
        return true;
      }
    } catch (e) {
      console.warn('[SosClient] Could not open SMS composer:', e);
    }
    return false;
  }

  /**
   * Triggers the SOS event on server with offline local queueing.
   */
  public static async triggerSos(params: {
    sosId: string;
    lat: number;
    lng: number;
    accuracyM: number;
    locationSource: string;
    tripId?: string;
    triggerSource?: string;
    batteryPercent?: number;
    clientSentSms?: string[];
  }): Promise<{ success: boolean; data?: any; isOfflineQueued?: boolean }> {
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/sos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(params),
      });

      if (res.ok) {
        const json = await res.json();
        return { success: true, data: json.sosEvent };
      }
      throw new Error(`Server returned ${res.status}`);
    } catch {
      // Queue offline
      await this.queueOfflineEvent(params);
      return { success: true, isOfflineQueued: true };
    }
  }

  /**
   * Starts periodic live location updates during active SOS.
   */
  public static startLiveLocationUpdates(sosId: string, intervalMinutes: number = 3) {
    if (this.liveInterval) clearInterval(this.liveInterval);

    this.liveInterval = setInterval(async () => {
      const loc = await this.getCurrentLocation();
      try {
        await fetch(`${BACKEND_URL}/api/v1/sos/${sosId}/location`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            lat: loc.lat,
            lng: loc.lng,
            accuracy_m: loc.accuracyM,
          }),
        });
      } catch {}
    }, intervalMinutes * 60 * 1000);
  }

  /**
   * Stops live updates and marks user safe.
   */
  public static async resolveSafe(sosId: string): Promise<boolean> {
    if (this.liveInterval) {
      clearInterval(this.liveInterval);
      this.liveInterval = null;
    }

    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/sos/${sosId}/safe`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      });
      return res.ok;
    } catch {
      return false;
    }
  }

  /**
   * Cancels SOS or marks false alarm.
   */
  public static async cancelSos(sosId: string, isFalseAlarm: boolean = false): Promise<boolean> {
    if (this.liveInterval) {
      clearInterval(this.liveInterval);
      this.liveInterval = null;
    }

    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/sos/${sosId}/cancel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isFalseAlarm }),
      });
      return res.ok;
    } catch {
      return false;
    }
  }

  /**
   * Queues an SOS payload locally when offline.
   */
  private static async queueOfflineEvent(eventPayload: any) {
    try {
      const raw = await AsyncStorage.getItem(OFFLINE_SOS_STORAGE);
      const queue = raw ? JSON.parse(raw) : [];
      queue.push(eventPayload);
      await AsyncStorage.setItem(OFFLINE_SOS_STORAGE, JSON.stringify(queue));
    } catch {}
  }

  /**
   * Synchronizes queued offline events when connection resumes.
   */
  public static async flushOfflineQueue() {
    try {
      const raw = await AsyncStorage.getItem(OFFLINE_SOS_STORAGE);
      if (!raw) return;
      const queue = JSON.parse(raw);
      if (!Array.isArray(queue) || queue.length === 0) return;

      const remaining = [];
      for (const item of queue) {
        try {
          await fetch(`${BACKEND_URL}/api/v1/sos`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(item),
          });
        } catch {
          remaining.push(item);
        }
      }

      await AsyncStorage.setItem(OFFLINE_SOS_STORAGE, JSON.stringify(remaining));
    } catch {}
  }
}
