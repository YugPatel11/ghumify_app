export const ALLOWED_AUDIO_MIME_TYPES = new Set([
  'audio/webm',
  'audio/webm;codecs=opus',
  'audio/ogg',
  'audio/ogg;codecs=opus',
  'audio/mp3',
  'audio/mpeg',
  'audio/wav',
  'audio/x-wav',
  'audio/wave',
  'audio/mp4',
  'audio/m4a',
  'audio/x-m4a',
  'audio/aac',
]);

export const MAX_AUDIO_BYTES = 10 * 1024 * 1024; // 10 MB

export interface ValidationResult {
  valid: boolean;
  normalizedMime: string;
  error?: string;
  errorCode?: string;
}

export function validateAudioData(buffer: Buffer, rawMime: string): ValidationResult {
  if (!buffer || buffer.length === 0) {
    return {
      valid: false,
      normalizedMime: '',
      error: 'Audio payload is empty or missing.',
      errorCode: 'EMPTY_AUDIO',
    };
  }

  if (buffer.length > MAX_AUDIO_BYTES) {
    return {
      valid: false,
      normalizedMime: '',
      error: `Audio file exceeds maximum size limit of ${MAX_AUDIO_BYTES / (1024 * 1024)}MB.`,
      errorCode: 'FILE_TOO_LARGE',
    };
  }

  const cleanMime = rawMime.split(';')[0].trim().toLowerCase();
  if (!ALLOWED_AUDIO_MIME_TYPES.has(rawMime.toLowerCase().trim()) && !ALLOWED_AUDIO_MIME_TYPES.has(cleanMime)) {
    return {
      valid: false,
      normalizedMime: cleanMime,
      error: `Unsupported audio format "${rawMime}". Supported types include webm, ogg, mp3, wav, m4a.`,
      errorCode: 'UNSUPPORTED_MIME_TYPE',
    };
  }

  return { valid: true, normalizedMime: cleanMime };
}

export function sanitizeTranscript(text: string): string {
  if (!text) return '';
  return text
    .replace(/[<>]/g, '') // Strip script injection chars
    .trim();
}
