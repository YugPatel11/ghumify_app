export interface SupportedLanguage {
  code: string;
  name: string;
  nativeName: string;
  direction: 'ltr' | 'rtl';
  flag: string;
  enabled: boolean;
}

export const SUPPORTED_LANGUAGES: SupportedLanguage[] = [
  { code: 'en', name: 'English', nativeName: 'English', direction: 'ltr', flag: '🌐', enabled: true },
  { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', direction: 'ltr', flag: '🇮🇳', enabled: true },
  { code: 'es', name: 'Spanish', nativeName: 'Español', direction: 'ltr', flag: '🇪🇸', enabled: true },
  { code: 'fr', name: 'French', nativeName: 'Français', direction: 'ltr', flag: '🇫🇷', enabled: true },
  { code: 'de', name: 'German', nativeName: 'Deutsch', direction: 'ltr', flag: '🇩🇪', enabled: true },
  { code: 'pt', name: 'Portuguese', nativeName: 'Português', direction: 'ltr', flag: '🇵🇹', enabled: true },
  { code: 'ar', name: 'Arabic', nativeName: 'العربية', direction: 'rtl', flag: '🇦🇪', enabled: true },
  { code: 'bn', name: 'Bengali', nativeName: 'বাংলা', direction: 'ltr', flag: '🐅', enabled: true },
  { code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', direction: 'ltr', flag: '🛕', enabled: true },
  { code: 'te', name: 'Telugu', nativeName: 'తెలుగు', direction: 'ltr', flag: '🪔', enabled: true },
  { code: 'mr', name: 'Marathi', nativeName: 'मराठी', direction: 'ltr', flag: '🏵️', enabled: true },
  { code: 'ur', name: 'Urdu', nativeName: 'اردو', direction: 'rtl', flag: '🇵🇰', enabled: true },
  { code: 'zh', name: 'Chinese (Simplified)', nativeName: '简体中文', direction: 'ltr', flag: '🇨🇳', enabled: true },
  { code: 'ja', name: 'Japanese', nativeName: '日本語', direction: 'ltr', flag: '🇯🇵', enabled: true },
  { code: 'ru', name: 'Russian', nativeName: 'Русский', direction: 'ltr', flag: '🇷🇺', enabled: true },
  { code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', direction: 'ltr', flag: '🦁', enabled: true },
  { code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', direction: 'ltr', flag: '🦚', enabled: true },
  { code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', direction: 'ltr', flag: '🌴', enabled: true },
  { code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', direction: 'ltr', flag: '🌾', enabled: true },
];

export const DEFAULT_LANGUAGE = 'en';

export function isLanguageSupported(code: string): boolean {
  if (!code) return false;
  const normalized = code.toLowerCase().trim();
  return SUPPORTED_LANGUAGES.some((lang) => lang.enabled && (lang.code.toLowerCase() === normalized || lang.code.toLowerCase() === normalized.split('-')[0]));
}

export function getLanguageMetadata(code: string): SupportedLanguage | undefined {
  if (!code) return undefined;
  const normalized = code.toLowerCase().trim();
  return SUPPORTED_LANGUAGES.find((lang) => lang.code.toLowerCase() === normalized || lang.code.toLowerCase() === normalized.split('-')[0]);
}
