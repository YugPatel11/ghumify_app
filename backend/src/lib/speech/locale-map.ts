export const SPEECH_LOCALE_MAP: Record<string, string> = {
  en: 'en-US',
  hi: 'hi-IN',
  es: 'es-ES',
  fr: 'fr-FR',
  de: 'de-DE',
  pt: 'pt-PT',
  ar: 'ar-SA',
  bn: 'bn-IN',
  ta: 'ta-IN',
  te: 'te-IN',
  mr: 'mr-IN',
  ur: 'ur-PK',
  zh: 'zh-CN',
  ja: 'ja-JP',
  ru: 'ru-RU',
  gu: 'gu-IN',
  kn: 'kn-IN',
  ml: 'ml-IN',
  pa: 'pa-IN',
};

export function getSpeechLocale(langCode: string = 'en'): string {
  const normalized = langCode.toLowerCase().trim().split('-')[0];
  return SPEECH_LOCALE_MAP[normalized] || 'en-US';
}
