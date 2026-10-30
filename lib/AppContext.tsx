import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { useColorScheme, I18nManager, Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { LangCode } from './types';
import { dark, light, Theme } from './theme';
import { t, setLang, LANGUAGES, isRTL, mergeDynamicTranslations, formatNumber, formatDate, formatTime, formatCurrency } from './i18n';

interface AppCtx {
  theme: Theme;
  lang: LangCode;
  isRtlMode: boolean;
  syncing: boolean;
  syncError: string | null;
  setLanguage: (l: LangCode) => Promise<boolean>;
  t: (key: string, params?: Record<string, string | number>) => string;
  formatNumber: (n: number) => string;
  formatDate: (d: Date, opts?: Intl.DateTimeFormatOptions) => string;
  formatTime: (d: Date) => string;
  formatCurrency: (amount: number, currency?: string) => string;
}

const Ctx = createContext<AppCtx>({
  theme: light,
  lang: 'en',
  isRtlMode: false,
  syncing: false,
  syncError: null,
  setLanguage: async () => true,
  t: (k: string) => k,
  formatNumber: (n: number) => String(n),
  formatDate: (d: Date) => d.toLocaleDateString(),
  formatTime: (d: Date) => d.toLocaleTimeString(),
  formatCurrency: (a: number) => `₹${a}`,
});

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export function AppProvider({ children }: { children: React.ReactNode }) {
  const scheme = useColorScheme();
  const [lang, setLangState] = useState<LangCode>('en');
  const [ready, setReady] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [syncError, setSyncError] = useState<string | null>(null);

  // 1. Language Bootstrap Lifecycle:
  // Server User Preference > Local AsyncStorage > Default 'en'
  useEffect(() => {
    (async () => {
      let resolvedLang: LangCode = 'en';

      // Check local storage first
      const localLang = await AsyncStorage.getItem('ghumify_lang');
      if (localLang && LANGUAGES.some((l) => l.code === localLang)) {
        resolvedLang = localLang as LangCode;
      }

      // Sync with server user profile
      try {
        const res = await fetch(`${BACKEND_URL}/api/v1/me/language`, {
          headers: { 'x-user-id': 'user_demo' },
        });
        if (res.ok) {
          const json = await res.json();
          const serverLang = json.data?.preferred_language;
          if (serverLang && LANGUAGES.some((l) => l.code === serverLang)) {
            resolvedLang = serverLang as LangCode;
            await AsyncStorage.setItem('ghumify_lang', serverLang);
          }
        }
      } catch (err) {
        // Offline or backend not reachable; safely continue with cached localLang
      }

      setLangState(resolvedLang);
      setLang(resolvedLang);

      // Fetch dynamic bundle in background if target is not en
      if (resolvedLang !== 'en') {
        fetchBundle(resolvedLang);
      }

      setReady(true);
    })();
  }, []);

  const fetchBundle = async (targetLang: string) => {
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/translations/${targetLang}`);
      if (res.ok) {
        const data = await res.json();
        if (data.translations) {
          mergeDynamicTranslations(targetLang, data.translations);
        }
      }
    } catch {}
  };

  const setLanguage = useCallback(
    async (newLang: LangCode): Promise<boolean> => {
      const previousLang = lang;
      setSyncError(null);
      setSyncing(true);

      // Optimistic update
      setLangState(newLang);
      setLang(newLang);
      await AsyncStorage.setItem('ghumify_lang', newLang);

      // RTL handling
      const rtl = isRTL(newLang);
      if (I18nManager.isRTL !== rtl) {
        try {
          I18nManager.allowRTL(rtl);
          I18nManager.forceRTL(rtl);
        } catch {}
      }

      // Fetch bundle
      fetchBundle(newLang);

      // Persist to server
      try {
        const res = await fetch(`${BACKEND_URL}/api/v1/me/language`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            'x-user-id': 'user_demo',
          },
          body: JSON.stringify({ language: newLang }),
        });

        if (!res.ok) {
          throw new Error('Server rejected language update');
        }

        setSyncing(false);
        return true;
      } catch (err: any) {
        console.warn('[AppContext] Failed to persist language to server:', err);
        // Do not break user flow offline, but record error state
        setSyncError('Saved locally. Server sync will retry when online.');
        setSyncing(false);
        return false;
      }
    },
    [lang]
  );

  const theme = scheme === 'dark' ? dark : light;
  const isRtlMode = isRTL(lang);

  if (!ready) return null;

  return (
    <Ctx.Provider
      value={{
        theme,
        lang,
        isRtlMode,
        syncing,
        syncError,
        setLanguage,
        t,
        formatNumber: (n) => formatNumber(n, lang),
        formatDate: (d, opts) => formatDate(d, lang, opts),
        formatTime: (d) => formatTime(d, lang),
        formatCurrency: (a, cur) => formatCurrency(a, lang, cur),
      }}
    >
      {children}
    </Ctx.Provider>
  );
}

export function useApp() {
  return useContext(Ctx);
}
