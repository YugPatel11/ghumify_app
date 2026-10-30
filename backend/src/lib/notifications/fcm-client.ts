import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

export interface ServiceAccountCredentials {
  project_id: string;
  client_email: string;
  private_key: string;
}

export interface FcmMessageSpec {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
  priority?: 'high' | 'normal';
  ttlSeconds?: number;
  collapseKey?: string;
}

export interface FcmSendResult {
  success: boolean;
  messageId?: string;
  isUnregistered?: boolean;
  error?: string;
  simulated?: boolean;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

export class FcmClient {
  private static credentials: ServiceAccountCredentials | null = null;
  private static credentialsChecked = false;

  /**
   * Validates and loads service account credentials from env or filesystem.
   */
  public static loadCredentials(): ServiceAccountCredentials | null {
    if (this.credentialsChecked) {
      return this.credentials;
    }

    this.credentialsChecked = true;

    // 1. Check direct JSON string in env
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      try {
        const parsed = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        if (parsed.project_id && parsed.client_email && parsed.private_key) {
          this.credentials = parsed;
          return this.credentials;
        }
      } catch (e) {
        console.warn('[FCM] Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON env variable.');
      }
    }

    // 2. Check path in env
    const configuredPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    const searchPaths = [
      configuredPath,
      path.resolve(process.cwd(), '../firebase-service-account.json'),
      path.resolve(process.cwd(), 'firebase-service-account.json'),
    ].filter(Boolean) as string[];

    for (const p of searchPaths) {
      if (fs.existsSync(p)) {
        try {
          const raw = fs.readFileSync(p, 'utf-8');
          const parsed = JSON.parse(raw);
          if (parsed.project_id && parsed.client_email && parsed.private_key) {
            this.credentials = parsed;
            console.log(`[FCM] Loaded Firebase Service Account for project: ${parsed.project_id}`);
            return this.credentials;
          }
        } catch (e) {
          console.warn(`[FCM] Could not parse credentials at ${p}:`, e);
        }
      }
    }

    console.warn(
      '[FCM WARNING] No Firebase service account JSON found. Push notifications will run in SIMULATED / DRY-RUN mode. Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON to enable real FCM HTTP v1 dispatch.'
    );
    return null;
  }

  /**
   * Verifies system clock drift against Google time to avoid OAuth2 token exchange failure.
   */
  public static async checkClockSync(): Promise<{ inSync: boolean; driftSeconds: number }> {
    try {
      const start = Date.now();
      const res = await fetch('https://oauth2.googleapis.com', { method: 'HEAD' });
      const serverDateHeader = res.headers.get('date');
      if (serverDateHeader) {
        const googleTime = new Date(serverDateHeader).getTime();
        const localTime = start;
        const driftSec = Math.round(Math.abs(localTime - googleTime) / 1000);
        return { inSync: driftSec < 60, driftSeconds: driftSec };
      }
    } catch {
      // Network check failed
    }
    return { inSync: true, driftSeconds: 0 };
  }

  /**
   * Generates a Google OAuth2 access token for FCM HTTP v1 via signed JWT assertion.
   */
  private static async getAccessToken(creds: ServiceAccountCredentials): Promise<string> {
    const now = Math.floor(Date.now() / 1000);

    // Return cached token if valid for at least 5 more minutes
    if (cachedAccessToken && cachedAccessToken.expiresAt > now + 300) {
      return cachedAccessToken.token;
    }

    const header = { alg: 'RS256', typ: 'JWT' };
    const claim = {
      iss: creds.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now,
    };

    const b64Header = Buffer.from(JSON.stringify(header)).toString('base64url');
    const b64Claim = Buffer.from(JSON.stringify(claim)).toString('base64url');
    const unsigned = `${b64Header}.${b64Claim}`;

    const signer = crypto.createSign('RSA-SHA256');
    signer.update(unsigned);
    const signature = signer.sign(creds.private_key, 'base64url');
    const jwt = `${unsigned}.${signature}`;

    const params = new URLSearchParams();
    params.append('grant_type', 'urn:ietf:params:oauth:grant-type:jwt-bearer');
    params.append('assertion', jwt);

    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      throw new Error(`Google OAuth2 token exchange failed: ${tokenRes.status} ${errText}`);
    }

    const data = await tokenRes.json();
    cachedAccessToken = {
      token: data.access_token,
      expiresAt: now + (data.expires_in || 3600),
    };

    return cachedAccessToken.token;
  }

  /**
   * Send a single message via FCM HTTP v1 API.
   */
  public static async sendMessage(
    spec: FcmMessageSpec,
    validateOnly: boolean = false
  ): Promise<FcmSendResult> {
    const creds = this.loadCredentials();

    // If no credentials configured, simulate delivery cleanly for tests and offline local server
    if (!creds) {
      return {
        success: true,
        messageId: `simulated_msg_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        simulated: true,
      };
    }

    try {
      const accessToken = await this.getAccessToken(creds);
      const url = `https://fcm.googleapis.com/v1/projects/${creds.project_id}/messages:send`;

      const payload: any = {
        validate_only: validateOnly,
        message: {
          token: spec.token,
          notification: {
            title: spec.title,
            body: spec.body,
          },
          data: spec.data,
          android: {
            priority: spec.priority === 'high' ? 'high' : 'normal',
            ttl: `${spec.ttlSeconds || 1800}s`,
            collapse_key: spec.collapseKey,
            notification: {
              channel_id: 'trip_alerts',
              default_sound: true,
              default_vibrate_timings: true,
            },
          },
          apns: {
            headers: {
              'apns-priority': spec.priority === 'high' ? '10' : '5',
              'apns-push-type': 'alert',
            },
            payload: {
              aps: {
                sound: 'default',
                'interruption-level': 'time-sensitive',
                category: 'TRIP_ALERT_ACTIONS',
              },
            },
          },
        },
      };

      const res = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (res.ok) {
        const resData = await res.json();
        return {
          success: true,
          messageId: resData.name,
        };
      }

      const errData = await res.json().catch(() => ({}));
      const errorCode = errData?.error?.details?.[0]?.errorCode || errData?.error?.status || '';

      const isUnregistered =
        errorCode === 'UNREGISTERED' ||
        res.status === 404 ||
        errData?.error?.message?.includes('Requested entity was not found');

      return {
        success: false,
        isUnregistered,
        error: errData?.error?.message || `HTTP ${res.status}`,
      };
    } catch (err: any) {
      return {
        success: false,
        error: err.message,
      };
    }
  }
}
