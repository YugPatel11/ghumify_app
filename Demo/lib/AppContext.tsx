import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { useColorScheme } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { LangCode } from './types';
import { dark, light, Theme } from './theme';
import { t, setLang, LANGUAGES } from './i18n';

interface AppCtx {
  theme: Theme;
  lang: LangCode;
  setLanguage: (l: LangCode) => void;
  t: (key: string) => string;
}

const Ctx = createContext<AppCtx>({
  theme: light,
  lang: 'en',
  setLanguage: () => {},
  t: (k: string) => k,
});

export function AppProvider({ children }: { children: React.ReactNode }) {
  const scheme = useColorScheme();
  const [lang, setLangState] = useState<LangCode>('en');
  const [ready, setReady] = useState(false);

  useEffect(() => {
    (async () => {
      const saved = await AsyncStorage.getItem('ghumify_lang');
      if (saved && LANGUAGES.find((l) => l.code === saved)) {
        setLangState(saved as LangCode);
        setLang(saved as LangCode);
      }
      setReady(true);
    })();
  }, []);

  const setLanguage = useCallback((l: LangCode) => {
    setLangState(l);
    setLang(l);
    AsyncStorage.setItem('ghumify_lang', l);
  }, []);

  const theme = scheme === 'dark' ? dark : light;

  if (!ready) return null;

  return (
    <Ctx.Provider value={{ theme, lang, setLanguage, t }}>
      {children}
    </Ctx.Provider>
  );
}

export function useApp() {
  return useContext(Ctx);
}
