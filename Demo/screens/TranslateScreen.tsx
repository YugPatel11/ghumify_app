import React, { useMemo, useState } from 'react';
import { FlatList, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated, { useAnimatedStyle, useSharedValue, withSpring, withTiming } from 'react-native-reanimated';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { TRANSLATOR_CATEGORIES, PHRASES, translate } from '../lib/translator';
import { LANGUAGES } from '../lib/i18n';
import { LangCode, TranslationPhrase } from '../lib/types';
import { RADIUS, SPACING, shadow } from '../lib/theme';

interface Props {
  navigation: any;
}

export default function TranslateScreen({ navigation }: Props) {
  const { theme, lang, t: tr } = useApp();
  const [fromLang, setFromLang] = useState<LangCode>(lang);
  const [toLang, setToLang] = useState<LangCode>('hi');
  const [activeCat, setActiveCat] = useState(TRANSLATOR_CATEGORIES[0]);
  const [showPicker, setShowPicker] = useState<'from' | 'to' | null>(null);
  const [playingId, setPlayingId] = useState<string | null>(null);

  const phrases = useMemo(() => PHRASES.filter((p) => p.category === activeCat), [activeCat]);

  const swap = () => {
    setFromLang(toLang);
    setToLang(fromLang);
  };

  const fromInfo = LANGUAGES.find((l) => l.code === fromLang)!;
  const toInfo = LANGUAGES.find((l) => l.code === toLang)!;

  const playPhrase = (phrase: TranslationPhrase) => {
    setPlayingId(phrase.id);
    setTimeout(() => setPlayingId(null), 1800);
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg }} edges={['top']}>
      <View style={styles.container}>
        <View style={styles.headerRow}>
          <View>
            <Text style={[styles.screenTitle, { color: theme.text }]}>{tr('translate')}</Text>
            <Text style={[styles.screenSub, { color: theme.textMuted }]}>Talk like a local</Text>
          </View>
          <Pressable onPress={() => navigation.navigate('Settings')} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
            <View style={[styles.settingsBtn, { backgroundColor: theme.card, borderColor: theme.border }]}>
              <Ionicons name="language" size={20} color={theme.brand} />
            </View>
          </Pressable>
        </View>

        {/* Language selector */}
        <View style={{ paddingHorizontal: 20, marginBottom: 16 }}>
          <View style={[styles.langSelector, { backgroundColor: theme.card, borderColor: theme.border }, shadow(theme, 1)]}>
            <Pressable onPress={() => setShowPicker('from')} style={styles.langCol}>
              <Text style={[styles.langColLabel, { color: theme.textMuted }]}>From</Text>
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
              <Text style={[styles.langColLabel, { color: theme.textMuted }]}>To</Text>
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
        <FlatList
          data={phrases}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 30 }}
          showsVerticalScrollIndicator={false}
          renderItem={({ item }) => (
            <PhraseCard
              phrase={item}
              fromLang={fromLang}
              toLang={toLang}
              fromInfo={fromInfo}
              toInfo={toInfo}
              theme={theme}
              playing={playingId === item.id}
              onPlay={() => playPhrase(item)}
            />
          )}
        />
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
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));
  const playOpacity = useSharedValue(0);
  const playAnim = useAnimatedStyle(() => ({ opacity: playOpacity.value }));
  React.useEffect(() => {
    if (playing) {
      playOpacity.value = 0;
      playOpacity.value = withSpring(1);
    }
  }, [playing]);

  const fromText = translate(phrase, fromLang);
  const toText = translate(phrase, toLang);

  return (
    <Animated.View style={animStyle}>
      <Pressable onPressIn={() => { scale.value = withSpring(0.98); }} onPressOut={() => { scale.value = withSpring(1); }}>
        <View style={[styles.phraseCard, { backgroundColor: theme.card, borderColor: theme.border }, shadow(theme, 1)]}>
          {/* From language */}
          <View style={styles.phraseRow}>
            <View style={styles.phraseLangTag}>
              <Text style={styles.phraseLangFlag}>{fromInfo.flag}</Text>
              <Text style={[styles.phraseLangName, { color: theme.textMuted }]}>{fromInfo.name}</Text>
            </View>
            <Text style={[styles.phraseFromText, { color: theme.text }]}>{fromText}</Text>
          </View>

          <View style={[styles.phraseDivider, { backgroundColor: theme.border }]} />

          {/* To language */}
          <View style={styles.phraseRow}>
            <View style={styles.phraseLangTag}>
              <Text style={styles.phraseLangFlag}>{toInfo.flag}</Text>
              <Text style={[styles.phraseLangName, { color: theme.textMuted }]}>{toInfo.name}</Text>
            </View>
            <View style={styles.phraseToRow}>
              <Text style={[styles.phraseToText, { color: theme.brand }]}>{toText}</Text>
              <Pressable onPress={onPlay} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
                <View style={[styles.playBtn, { backgroundColor: theme.brandSoft }]}>
                  <Ionicons name={playing ? 'volume-high' : 'volume-medium-outline'} size={16} color={theme.brand} />
                </View>
              </Pressable>
            </View>
          </View>

          {playing ? (
            <Animated.View style={[styles.playingBar, playAnim]}>
              <Animated.Text style={[styles.playingText, { color: theme.brand }]}>🔊 Speaking... Show this to a local</Animated.Text>
            </Animated.View>
          ) : null}
        </View>
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 8, paddingBottom: 16 },
  screenTitle: { fontSize: 26, fontWeight: '900', letterSpacing: -0.5 },
  screenSub: { fontSize: 13, fontWeight: '600', marginTop: 2 },
  settingsBtn: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', borderWidth: 1.5 },
  langSelector: { flexDirection: 'row', alignItems: 'center', borderRadius: RADIUS.lg, borderWidth: 1.5, paddingVertical: 14, paddingHorizontal: 16 },
  langCol: { flex: 1 },
  langColLabel: { fontSize: 11, fontWeight: '800', textTransform: 'uppercase', marginBottom: 6, letterSpacing: 0.5 },
  langColVal: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  langFlag: { fontSize: 22 },
  langName: { fontSize: 16, fontWeight: '800' },
  langNameEn: { fontSize: 11.5, fontWeight: '600', marginTop: 1 },
  swapBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center', marginHorizontal: 12 },
  catTab: { paddingHorizontal: 16, paddingVertical: 9, borderRadius: RADIUS.pill, borderWidth: 1.5 },
  catTabText: { fontSize: 13, fontWeight: '800' },
  phraseCard: { borderRadius: RADIUS.lg, borderWidth: 1.5, marginBottom: 12, overflow: 'hidden' },
  phraseRow: { padding: 16 },
  phraseLangTag: { flexDirection: 'row', alignItems: 'center', gap: 7, marginBottom: 10 },
  phraseLangFlag: { fontSize: 16 },
  phraseLangName: { fontSize: 11.5, fontWeight: '800', textTransform: 'uppercase', letterSpacing: 0.5 },
  phraseFromText: { fontSize: 16.5, fontWeight: '700', lineHeight: 22 },
  phraseDivider: { height: 1, marginHorizontal: 16 },
  phraseToRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  phraseToText: { fontSize: 17, fontWeight: '800', flex: 1, lineHeight: 23 },
  playBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  playingBar: { paddingHorizontal: 16, paddingBottom: 14 },
  playingText: { fontSize: 12.5, fontWeight: '700' },
  overlay: { position: 'absolute', top: 0, bottom: 0, left: 0, right: 0, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' },
  pickerSheet: { borderTopLeftRadius: 28, borderTopRightRadius: 28, paddingBottom: 30, paddingHorizontal: 20, paddingTop: 8 },
  pickerHandle: { width: 40, height: 5, borderRadius: 3, alignSelf: 'center', marginBottom: 16 },
  pickerTitle: { fontSize: 16, fontWeight: '800', marginBottom: 16, textAlign: 'center' },
  pickerItem: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingVertical: 14, paddingHorizontal: 14, borderRadius: RADIUS.md },
  pickerFlag: { fontSize: 24 },
  pickerNative: { fontSize: 16, fontWeight: '800' },
  pickerEn: { fontSize: 12.5, fontWeight: '600', marginTop: 2 },
});
