import React, { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { TRANSLATOR_CATEGORIES, PHRASES } from '../lib/translator';
import { LANGUAGES } from '../lib/i18n';
import { LangCode, TranslationPhrase } from '../lib/types';
import { RADIUS, SPACING, shadow } from '../lib/theme';
import { useSpeechToText } from '../lib/useSpeechToText';
import MicButton from '../components/MicButton';

interface Props {
  navigation: any;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export default function TranslateScreen({ navigation }: Props) {
  const { theme, lang, t: tr, isRtlMode } = useApp();
  const [fromLang, setFromLang] = useState<LangCode>(lang);
  const [toLang, setToLang] = useState<LangCode>('hi');
  const [activeCat, setActiveCat] = useState(TRANSLATOR_CATEGORIES[0]);
  const [showPicker, setShowPicker] = useState<'from' | 'to' | null>(null);
  const [playingId, setPlayingId] = useState<string | null>(null);

  // Custom translation state
  const [sourceText, setSourceText] = useState('');
  const [translatedResult, setTranslatedResult] = useState('');
  const [translating, setTranslating] = useState(false);
  const [copied, setCopied] = useState(false);

  const phrases = useMemo(() => PHRASES.filter((p) => p.category === activeCat), [activeCat]);

  const swap = () => {
    setFromLang(toLang);
    setToLang(fromLang);
    // Swap text as well
    if (translatedResult) {
      setSourceText(translatedResult);
      setTranslatedResult(sourceText);
    }
  };

  const fromInfo = LANGUAGES.find((l) => l.code === fromLang) || LANGUAGES[0];
  const toInfo = LANGUAGES.find((l) => l.code === toLang) || LANGUAGES[1];

  const handleTranslate = async (textToTranslate?: string) => {
    const text = (textToTranslate || sourceText).trim();
    if (!text || fromLang === toLang) {
      setTranslatedResult(text);
      return;
    }

    setTranslating(true);
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/translate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'user_demo',
        },
        body: JSON.stringify({
          texts: [text],
          source_lang: fromLang,
          target_lang: toLang,
        }),
      });

      if (res.ok) {
        const data = await res.json();
        setTranslatedResult(data.translations?.[0] || text);
      } else {
        setTranslatedResult(text);
      }
    } catch {
      setTranslatedResult(text);
    } finally {
      setTranslating(false);
    }
  };

  // Speech to Text hook bound to the active source language
  const speech = useSpeechToText({
    language: fromLang,
    onFinalResult: (text) => {
      setSourceText((prev) => {
        const full = prev ? `${prev} ${text}` : text;
        handleTranslate(full);
        return full;
      });
    },
  });

  const playPhrase = (phrase: TranslationPhrase) => {
    setPlayingId(phrase.id);
    setTimeout(() => setPlayingId(null), 1800);
  };

  const copyToClipboard = () => {
    if (!translatedResult) return;
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg }} edges={['top']}>
      <View style={styles.container}>
        {/* Header */}
        <View style={[styles.headerRow, isRtlMode && styles.rtlRow]}>
          <View>
            <Text style={[styles.screenTitle, { color: theme.text }]}>{tr('translate')}</Text>
            <Text style={[styles.screenSub, { color: theme.textMuted }]}>
              {tr('translate.subtitle') || 'Speak or type in any language'}
            </Text>
          </View>
          <Pressable onPress={() => navigation.navigate('Settings')} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
            <View style={[styles.settingsBtn, { backgroundColor: theme.card, borderColor: theme.border }]}>
              <Ionicons name="settings-outline" size={20} color={theme.brand} />
            </View>
          </Pressable>
        </View>

        {/* Language selector bar */}
        <View style={{ paddingHorizontal: 20, marginBottom: 12 }}>
          <View style={[styles.langSelector, { backgroundColor: theme.card, borderColor: theme.border }, shadow(theme, 1)]}>
            <Pressable onPress={() => setShowPicker('from')} style={styles.langCol}>
              <Text style={[styles.langColLabel, { color: theme.textMuted }]}>Speak / From</Text>
              <View style={styles.langColVal}>
                <Text style={styles.langFlag}>{fromInfo.flag}</Text>
                <View>
                  <Text style={[styles.langName, { color: theme.text }]}>{fromInfo.nativeName}</Text>
                  <Text style={[styles.langNameEn, { color: theme.textMuted }]}>{fromInfo.name}</Text>
                </View>
              </View>
              <Ionicons name="chevron-down" size={14} color={theme.textMuted} />
            </Pressable>

            <Pressable onPress={swap} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
              <View style={[styles.swapBtn, { backgroundColor: theme.brandSoft }]}>
                <Ionicons name="swap-horizontal" size={18} color={theme.brand} />
              </View>
            </Pressable>

            <Pressable onPress={() => setShowPicker('to')} style={styles.langCol}>
              <Text style={[styles.langColLabel, { color: theme.textMuted }]}>Translate To</Text>
              <View style={styles.langColVal}>
                <Text style={styles.langFlag}>{toInfo.flag}</Text>
                <View>
                  <Text style={[styles.langName, { color: theme.text }]}>{toInfo.nativeName}</Text>
                  <Text style={[styles.langNameEn, { color: theme.textMuted }]}>{toInfo.name}</Text>
                </View>
              </View>
              <Ionicons name="chevron-down" size={14} color={theme.textMuted} />
            </Pressable>
          </View>
        </View>

        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 40 }}>
          {/* Live Speech & Custom Translation Box */}
          <View style={[styles.customBox, { backgroundColor: theme.card, borderColor: theme.border }, shadow(theme, 2)]}>
            {/* Source Box */}
            <View style={styles.sourceWrap}>
              <TextInput
                value={sourceText}
                onChangeText={setSourceText}
                placeholder={speech.isListening ? `Listening in ${fromInfo.name}...` : `Type or speak in ${fromInfo.name}...`}
                placeholderTextColor={theme.textMuted}
                style={[styles.sourceInput, { color: theme.text }, isRtlMode && styles.rtlText]}
                multiline
                numberOfLines={3}
              />
              <View style={styles.sourceActions}>
                {sourceText.length > 0 && (
                  <Pressable onPress={() => { setSourceText(''); setTranslatedResult(''); }} style={{ padding: 6 }}>
                    <Ionicons name="close-circle" size={18} color={theme.textMuted} />
                  </Pressable>
                )}
                {/* Mic Button for Speech-to-Text */}
                <MicButton
                  state={speech.state}
                  onPress={() => {
                    if (speech.isListening) speech.stopListening();
                    else speech.startListening();
                  }}
                  onCancel={speech.cancelListening}
                  size={36}
                />
              </View>
            </View>

            {/* Interim live speech banner */}
            {speech.isListening && (
              <View style={[styles.speechStatusBanner, { backgroundColor: '#ef444415' }]}>
                <View style={styles.redPulse} />
                <Text style={[styles.speechStatusText, { color: theme.text }]}>
                  {speech.interimText || 'Listening... Speak clearly into microphone'}
                </Text>
              </View>
            )}

            {/* Translate Button */}
            <View style={styles.actionRow}>
              <Pressable
                onPress={() => handleTranslate()}
                disabled={!sourceText.trim() || translating}
                style={[
                  styles.translateBtn,
                  { backgroundColor: sourceText.trim() ? theme.brand : theme.cardAlt },
                ]}
              >
                {translating ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <>
                    <Ionicons name="language" size={16} color={sourceText.trim() ? '#fff' : theme.textMuted} />
                    <Text style={[styles.translateBtnText, { color: sourceText.trim() ? '#fff' : theme.textMuted }]}>
                      Translate
                    </Text>
                  </>
                )}
              </Pressable>
            </View>

            {/* Translated Output */}
            {translatedResult ? (
              <View style={[styles.outputBox, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
                <View style={[styles.outputHeader, isRtlMode && styles.rtlRow]}>
                  <Text style={[styles.outputLang, { color: theme.brand }]}>{toInfo.flag} {toInfo.name}</Text>
                  <Pressable onPress={copyToClipboard} style={styles.copyBtn}>
                    <Ionicons name={copied ? 'checkmark' : 'copy-outline'} size={16} color={theme.brand} />
                    <Text style={[styles.copyBtnText, { color: theme.brand }]}>
                      {copied ? 'Copied' : 'Copy'}
                    </Text>
                  </Pressable>
                </View>
                <Text style={[styles.outputText, { color: theme.text }, isRtlMode && styles.rtlText]}>
                  {translatedResult}
                </Text>
              </View>
            ) : null}
          </View>

          {/* Section Divider: Travel Phrases */}
          <View style={styles.sectionHeaderWrap}>
            <Text style={[styles.sectionTitle, { color: theme.text }]}>Common Travel Phrases</Text>
            <Text style={[styles.sectionSubtitle, { color: theme.textMuted }]}>Instant phrases with one-tap audio</Text>
          </View>

          {/* Category tabs */}
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 14 }}>
            {TRANSLATOR_CATEGORIES.map((cat) => {
              const active = cat === activeCat;
              return (
                <Pressable key={cat} onPress={() => setActiveCat(cat)} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
                  <View style={[styles.catTab, { backgroundColor: active ? theme.brand : theme.card, borderColor: active ? theme.brand : theme.border, marginRight: 8 }]}>
                    <Text style={[styles.catTabText, { color: active ? '#fff' : theme.text }]} numberOfLines={1}>{cat}</Text>
                  </View>
                </Pressable>
              );
            })}
          </ScrollView>

          {/* Phrase list */}
          <View style={{ paddingHorizontal: 20 }}>
            {phrases.map((item) => (
              <PhraseCard
                key={item.id}
                phrase={item}
                fromLang={fromLang}
                toLang={toLang}
                fromInfo={fromInfo}
                toInfo={toInfo}
                theme={theme}
                playing={playingId === item.id}
                onPlay={() => playPhrase(item)}
              />
            ))}
          </View>
        </ScrollView>
      </View>

      {/* Language picker modal */}
      {showPicker ? (
        <View style={styles.overlay}>
          <Pressable style={{ flex: 1 }} onPress={() => setShowPicker(null)} />
          <View style={[styles.pickerSheet, { backgroundColor: theme.card }]}>
            <View style={[styles.pickerHandle, { backgroundColor: theme.border }]} />
            <Text style={[styles.pickerTitle, { color: theme.text }]}>Select {showPicker === 'from' ? 'source' : 'target'} language</Text>
            <ScrollView style={{ maxHeight: 420 }} showsVerticalScrollIndicator={false}>
              {LANGUAGES.map((l) => {
                const active = (showPicker === 'from' ? fromLang : toLang) === l.code;
                return (
                  <Pressable
                    key={l.code}
                    onPress={() => {
                      if (showPicker === 'from') setFromLang(l.code);
                      else setToLang(l.code);
                      setShowPicker(null);
                    }}
                    style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}
                  >
                    <View style={[styles.pickerItem, { backgroundColor: active ? theme.brandSoft : 'transparent' }]}>
                      <Text style={styles.pickerFlag}>{l.flag}</Text>
                      <View style={{ flex: 1 }}>
                        <Text style={[styles.pickerNative, { color: theme.text }]}>{l.nativeName}</Text>
                        <Text style={[styles.pickerEn, { color: theme.textMuted }]}>{l.name}</Text>
                      </View>
                      {active ? <Ionicons name="checkmark-circle" size={22} color={theme.brand} /> : null}
                    </View>
                  </Pressable>
                );
              })}
            </ScrollView>
          </View>
        </View>
      ) : null}
    </SafeAreaView>
  );
}

function PhraseCard({ phrase, fromLang, toLang, fromInfo, toInfo, theme, playing, onPlay }: any) {
  const source = phrase.translations[fromLang] || phrase.english;
  const target = phrase.translations[toLang] || phrase.english;

  return (
    <View style={[styles.phraseCard, { backgroundColor: theme.card, borderColor: theme.border }, shadow(theme, 1)]}>
      <View style={{ flex: 1 }}>
        <Text style={[styles.sourcePhrase, { color: theme.text }]}>{source}</Text>
        <Text style={[styles.targetPhrase, { color: theme.brand }]}>{target}</Text>
      </View>
      <Pressable onPress={onPlay} style={styles.playBtn}>
        <Ionicons name={playing ? 'volume-high' : 'volume-medium-outline'} size={20} color={playing ? theme.brand : theme.textMuted} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12 },
  screenTitle: { fontSize: 24, fontWeight: '800' },
  screenSub: { fontSize: 13, marginTop: 2 },
  settingsBtn: { width: 38, height: 38, borderRadius: 19, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
  langSelector: { flexDirection: 'row', alignItems: 'center', borderRadius: RADIUS.lg, padding: 12, borderWidth: 1 },
  langCol: { flex: 1 },
  langColLabel: { fontSize: 10, fontWeight: '700', textTransform: 'uppercase', marginBottom: 2 },
  langColVal: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  langFlag: { fontSize: 22 },
  langName: { fontSize: 14, fontWeight: '700' },
  langNameEn: { fontSize: 11 },
  swapBtn: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center', marginHorizontal: 8 },
  customBox: { marginHorizontal: 20, borderRadius: RADIUS.lg, borderWidth: 1, padding: 14, marginBottom: 16 },
  sourceWrap: { flexDirection: 'row', alignItems: 'flex-start' },
  sourceInput: { flex: 1, fontSize: 15, minHeight: 64, padding: 0, textAlignVertical: 'top' },
  sourceActions: { flexDirection: 'row', alignItems: 'center', gap: 6, marginLeft: 8 },
  speechStatusBanner: { flexDirection: 'row', alignItems: 'center', padding: 8, borderRadius: RADIUS.sm, gap: 8, marginTop: 8 },
  redPulse: { width: 8, height: 8, borderRadius: 4, backgroundColor: '#ef4444' },
  speechStatusText: { fontSize: 12, fontStyle: 'italic', flex: 1 },
  actionRow: { flexDirection: 'row', justifyContent: 'flex-end', marginTop: 10 },
  translateBtn: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 16, paddingVertical: 8, borderRadius: RADIUS.md },
  translateBtnText: { fontSize: 13, fontWeight: '700' },
  outputBox: { marginTop: 12, padding: 12, borderRadius: RADIUS.md, borderWidth: 1 },
  outputHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 },
  outputLang: { fontSize: 12, fontWeight: '700' },
  copyBtn: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  copyBtnText: { fontSize: 12, fontWeight: '600' },
  outputText: { fontSize: 16, fontWeight: '600', lineHeight: 22 },
  sectionHeaderWrap: { paddingHorizontal: 20, marginBottom: 10, marginTop: 6 },
  sectionTitle: { fontSize: 16, fontWeight: '800' },
  sectionSubtitle: { fontSize: 12, marginTop: 1 },
  catTab: { paddingHorizontal: 14, paddingVertical: 7, borderRadius: RADIUS.pill, borderWidth: 1 },
  catTabText: { fontSize: 12, fontWeight: '700' },
  phraseCard: { flexDirection: 'row', alignItems: 'center', padding: 14, borderRadius: RADIUS.md, borderWidth: 1, marginBottom: 8 },
  sourcePhrase: { fontSize: 14, fontWeight: '500', marginBottom: 3 },
  targetPhrase: { fontSize: 15, fontWeight: '700' },
  playBtn: { padding: 6, marginLeft: 10 },
  overlay: { position: 'absolute', top: 0, bottom: 0, left: 0, right: 0, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end', zIndex: 999 },
  pickerSheet: { borderTopLeftRadius: RADIUS.xl, borderTopRightRadius: RADIUS.xl, padding: 20 },
  pickerHandle: { width: 36, height: 4, borderRadius: 2, alignSelf: 'center', marginBottom: 14 },
  pickerTitle: { fontSize: 16, fontWeight: '800', marginBottom: 14 },
  pickerItem: { flexDirection: 'row', alignItems: 'center', padding: 12, borderRadius: RADIUS.md, gap: 12 },
  pickerFlag: { fontSize: 22 },
  pickerNative: { fontSize: 15, fontWeight: '700' },
  pickerEn: { fontSize: 12 },
  rtlRow: { flexDirection: 'row-reverse' },
  rtlText: { textAlign: 'right' },
});
