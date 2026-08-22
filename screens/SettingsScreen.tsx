import React from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { LANGUAGES } from '../lib/i18n';
import { LangCode } from '../lib/types';
import { RADIUS, SPACING, shadow } from '../lib/theme';
import GradientView from '../components/GradientView';

interface Props {
  navigation: any;
}

export default function SettingsScreen({ navigation }: Props) {
  const { theme, lang, setLanguage, t: tr } = useApp();

  const current = LANGUAGES.find((l) => l.code === lang)!;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg }} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => navigation.goBack()} style={styles.backBtn}>
          <Ionicons name="chevron-back" size={24} color={theme.text} />
        </Pressable>
        <Text style={[styles.headerTitle, { color: theme.text }]}>{tr('settings')}</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 40, paddingTop: 10 }}>
        {/* Brand card */}
        <GradientView gradient="indigo" style={styles.brandCard} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
          <View style={styles.brandLogoRow}>
            <View style={styles.brandLogo}>
              <Ionicons name="airplane" size={28} color="#fff" />
            </View>
            <View>
              <Text style={styles.brandName}>Ghumify</Text>
              <Text style={styles.brandTag}>{tr('tagline')}</Text>
            </View>
          </View>
          <View style={styles.brandStats}>
            <View style={styles.brandStat}>
              <Text style={styles.brandStatVal}>10</Text>
              <Text style={styles.brandStatLabel}>Languages</Text>
            </View>
            <View style={styles.brandDivider} />
            <View style={styles.brandStat}>
              <Text style={styles.brandStatVal}>6</Text>
              <Text style={styles.brandStatLabel}>Cities</Text>
            </View>
            <View style={styles.brandDivider} />
            <View style={styles.brandStat}>
              <Text style={styles.brandStatVal}>40+</Text>
              <Text style={styles.brandStatLabel}>Places</Text>
            </View>
          </View>
        </GradientView>

        {/* Language section */}
        <View style={styles.langSection}>
          <View style={styles.langHeader}>
            <Ionicons name="language" size={20} color={theme.brand} />
            <Text style={[styles.langTitle, { color: theme.text }]}>{tr('changeLanguage')}</Text>
          </View>
          <Text style={[styles.currentLang, { color: theme.textMuted }]}>
            Currently: {current.flag} {current.nativeName} ({current.name})
          </Text>

          <View style={styles.langGrid}>
            {LANGUAGES.map((l) => {
              const active = l.code === lang;
              return (
                <Pressable
                  key={l.code}
                  onPress={() => setLanguage(l.code as LangCode)}
                  style={({ pressed }) => ({ opacity: pressed ? 0.8 : 1 })}
                >
                  <View style={[
                    styles.langItem,
                    { backgroundColor: active ? theme.brand : theme.card, borderColor: active ? theme.brand : theme.border },
                    shadow(theme, 1),
                  ]}>
                    <Text style={styles.langItemFlag}>{l.flag}</Text>
                    <View style={{ flex: 1 }}>
                      <Text style={[styles.langItemNative, { color: active ? '#fff' : theme.text }]}>{l.nativeName}</Text>
                      <Text style={[styles.langItemEn, { color: active ? 'rgba(255,255,255,0.7)' : theme.textMuted }]}>{l.name}</Text>
                    </View>
                    {active ? (
                      <Ionicons name="checkmark-circle" size={22} color="#fff" />
                    ) : (
                      <View style={[styles.langRadio, { borderColor: theme.border }]} />
                    )}
                  </View>
                </Pressable>
              );
            })}
          </View>
        </View>

        {/* About section */}
        <View style={styles.aboutSection}>
          <View style={styles.langHeader}>
            <Ionicons name="information-circle-outline" size={20} color={theme.brand} />
            <Text style={[styles.langTitle, { color: theme.text }]}>About Ghumify</Text>
          </View>
          <View style={[styles.aboutBox, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
            <Text style={[styles.aboutText, { color: theme.textSoft }]}>
              Ghumify is your complete travel companion for exploring India. Create smart, time-based travel plans tailored to your location, available time, and interests. Discover famous places, local food, hidden markets, cultural experiences, and more — all in your own language.
            </Text>
          </View>
        </View>

        {/* Features list */}
        <View style={styles.featuresSection}>
          {[
            { icon: 'sparkles', title: 'Smart Itinerary Planner', desc: 'AI-based time-aware travel plans' },
            { icon: 'language', title: '10-Language Translator', desc: 'Break the language barrier' },
            { icon: 'headset', title: 'Audio Guides', desc: 'Listen to history as you walk' },
            { icon: 'cloudy-outline', title: 'Weather-Aware', desc: 'Plans adapt to the weather' },
            { icon: 'bed', title: 'Budget Stays', desc: 'Hotels, hostels & dharamshalas' },
          ].map((f, i) => (
            <View key={i} style={[styles.featureRow, { backgroundColor: theme.card, borderColor: theme.border }]}>
              <View style={[styles.featureIcon, { backgroundColor: theme.brandSoft }]}>
                <Ionicons name={f.icon as any} size={18} color={theme.brand} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={[styles.featureTitle, { color: theme.text }]}>{f.title}</Text>
                <Text style={[styles.featureDesc, { color: theme.textMuted }]}>{f.desc}</Text>
              </View>
              <Ionicons name="checkmark-circle" size={20} color={theme.teal} />
            </View>
          ))}
        </View>

        <Text style={[styles.versionText, { color: theme.textMuted }]}>Ghumify v1.0 · Made in India 🇮🇳</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 14, paddingVertical: 12 },
  backBtn: { width: 40, alignItems: 'center' },
  headerTitle: { fontSize: 17, fontWeight: '800', flex: 1, textAlign: 'center' },
  brandCard: { borderRadius: RADIUS.xl, padding: 22, marginBottom: 24, shadowColor: '#000', shadowOpacity: 0.15, shadowRadius: 20, elevation: 8 },
  brandLogoRow: { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 22 },
  brandLogo: { width: 54, height: 54, borderRadius: 27, backgroundColor: 'rgba(255,255,255,0.22)', alignItems: 'center', justifyContent: 'center' },
  brandName: { color: '#fff', fontSize: 24, fontWeight: '900' },
  brandTag: { color: 'rgba(255,255,255,0.85)', fontSize: 12.5, fontWeight: '600', marginTop: 2 },
  brandStats: { flexDirection: 'row', backgroundColor: 'rgba(255,255,255,0.15)', borderRadius: RADIUS.lg, paddingVertical: 16 },
  brandStat: { flex: 1, alignItems: 'center' },
  brandStatVal: { color: '#fff', fontSize: 22, fontWeight: '900' },
  brandStatLabel: { color: 'rgba(255,255,255,0.7)', fontSize: 11, fontWeight: '700', marginTop: 3 },
  brandDivider: { width: 1, backgroundColor: 'rgba(255,255,255,0.2)', marginHorizontal: 4 },
  langSection: { marginBottom: 26 },
  langHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 },
  langTitle: { fontSize: 17, fontWeight: '900' },
  currentLang: { fontSize: 13, fontWeight: '600', marginBottom: 16 },
  langGrid: { gap: 10 },
  langItem: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 16, paddingVertical: 14, borderRadius: RADIUS.md, borderWidth: 1.5 },
  langItemFlag: { fontSize: 24 },
  langItemNative: { fontSize: 16, fontWeight: '800' },
  langItemEn: { fontSize: 12, fontWeight: '600', marginTop: 2 },
  langRadio: { width: 22, height: 22, borderRadius: 11, borderWidth: 2 },
  aboutSection: { marginBottom: 26 },
  aboutBox: { padding: 16, borderRadius: RADIUS.md, borderWidth: 1.5 },
  aboutText: { fontSize: 13.5, lineHeight: 21 },
  featuresSection: { gap: 10, marginBottom: 26 },
  featureRow: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 14, borderRadius: RADIUS.md, borderWidth: 1.5 },
  featureIcon: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  featureTitle: { fontSize: 14.5, fontWeight: '800' },
  featureDesc: { fontSize: 12, fontWeight: '600', marginTop: 2 },
  versionText: { fontSize: 12, fontWeight: '700', textAlign: 'center', marginTop: 8 },
});
