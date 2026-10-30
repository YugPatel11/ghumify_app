export interface SmsSendOptions {
  to: string; // E.164
  body: string;
  senderId?: string;
  channel?: 'sms' | 'whatsapp';
}

export interface SmsSendResult {
  success: boolean;
  messageId?: string;
  provider: string;
  segmentsCount: number;
  isSimulated?: boolean;
  error?: string;
}

export class SmsProvider {
  /**
   * Normalizes phone number to E.164 format and validates structure.
   */
  public static normalizePhone(rawPhone: string, defaultCountryCode: string = '+91'): {
    isValid: boolean;
    e164: string;
    error?: string;
  } {
    if (!rawPhone || typeof rawPhone !== 'string') {
      return { isValid: false, e164: '', error: 'Phone number is required.' };
    }

    // Strip whitespaces, dashes, brackets
    let cleaned = rawPhone.replace(/[\s\-\(\)\.]/g, '');

    if (!cleaned.startsWith('+')) {
      if (cleaned.startsWith('00')) {
        cleaned = '+' + cleaned.slice(2);
      } else if (cleaned.length === 10) {
        cleaned = defaultCountryCode + cleaned;
      } else {
        cleaned = '+' + cleaned;
      }
    }

    // Valid E.164: '+' followed by 7 to 15 digits
    const e164Regex = /^\+[1-9]\d{6,14}$/;
    if (!e164Regex.test(cleaned)) {
      return {
        isValid: false,
        e164: cleaned,
        error: 'Invalid phone format. Please include country code (e.g. +919876543210).',
      };
    }

    return { isValid: true, e164: cleaned };
  }

  /**
   * Calculates SMS segment count handling GSM-7 and Unicode (Hindi/Arabic/etc.) scripts.
   */
  public static calculateSegments(text: string): { isUnicode: boolean; segments: number; length: number } {
    // Check if text has characters outside standard GSM 7-bit charset
    const gsmRegex = /^[@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ\x1bÆæßÉ !\"#¤%&'()*+,\-.\/0-9:;<=>?¡A-ZÄÖÑÜ§¿a-zäöñüà]*$/;
    const isUnicode = !gsmRegex.test(text);
    const length = text.length;

    if (!isUnicode) {
      if (length <= 160) return { isUnicode, segments: 1, length };
      return { isUnicode, segments: Math.ceil(length / 153), length };
    } else {
      if (length <= 70) return { isUnicode, segments: 1, length };
      return { isUnicode, segments: Math.ceil(length / 67), length };
    }
  }

  /**
   * Masks a phone number for secure logging (e.g. +91 98*** **210).
   */
  public static maskPhone(phone: string): string {
    if (!phone || phone.length < 6) return '***';
    const start = phone.slice(0, 5);
    const end = phone.slice(-3);
    return `${start}****${end}`;
  }

  /**
   * Dispatches an SMS message via configured provider or mock simulation.
   */
  public static async send(options: SmsSendOptions): Promise<SmsSendResult> {
    const { to, body, channel = 'sms' } = options;
    const { isValid, e164, error: normErr } = this.normalizePhone(to);

    if (!isValid) {
      return {
        success: false,
        provider: 'validator',
        segmentsCount: 0,
        error: normErr || 'Invalid destination number.',
      };
    }

    const { segments } = this.calculateSegments(body);

    // 1. Twilio Integration (if configured)
    const twilioSid = process.env.TWILIO_ACCOUNT_SID;
    const twilioToken = process.env.TWILIO_AUTH_TOKEN;
    const twilioFrom = process.env.TWILIO_PHONE_NUMBER;

    if (twilioSid && twilioToken && twilioFrom) {
      try {
        const url = `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Messages.json`;
        const form = new URLSearchParams();
        form.append('To', channel === 'whatsapp' ? `whatsapp:${e164}` : e164);
        form.append('From', channel === 'whatsapp' ? `whatsapp:${twilioFrom}` : twilioFrom);
        form.append('Body', body);

        const authHeader = 'Basic ' + Buffer.from(`${twilioSid}:${twilioToken}`).toString('base64');
        const res = await fetch(url, {
          method: 'POST',
          headers: {
            Authorization: authHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: form.toString(),
        });

        if (res.ok) {
          const json = await res.json();
          return {
            success: true,
            messageId: json.sid,
            provider: 'twilio',
            segmentsCount: segments,
          };
        } else {
          const errData = await res.json().catch(() => ({}));
          console.warn('[SmsProvider] Twilio dispatch error:', errData);
          return {
            success: false,
            provider: 'twilio',
            segmentsCount: segments,
            error: errData.message || `Twilio HTTP ${res.status}`,
          };
        }
      } catch (err: any) {
        return {
          success: false,
          provider: 'twilio',
          segmentsCount: segments,
          error: err.message,
        };
      }
    }

    // 2. Simulated/Local Provider (Default for local server without paid SMS credentials)
    const simulatedId = `sim_sms_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    console.log(
      `[SmsProvider - SIMULATED] Alert SMS sent to ${this.maskPhone(e164)} (${segments} segments, channel=${channel}):\n"${body.slice(0, 100)}..."`
    );

    return {
      success: true,
      messageId: simulatedId,
      provider: 'mock_sms_local',
      segmentsCount: segments,
      isSimulated: true,
    };
  }
}
