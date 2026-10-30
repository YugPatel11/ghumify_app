import React, { useState, useMemo } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { LANGUAGES } from '../lib/i18n';
import { LangCode } from '../lib/types';
import { RADIUS, SPACING, shadow } from '../lib/theme';
import GradientView from '../components/GradientView';
import EmergencyContactsModal from '../components/EmergencyContactsModal';

interface Props {
  navigation: any;
}

export default function SettingsScreen({ navigation }: Props) {
  const { theme, lang, setLanguage, t: tr, syncing, syncError, isRtlMode } = useApp();
  const [searchQuery, setSearchQuery] = useState('');
  const [feedbackMsg, setFeedbackMsg] = useState<string | null>(null);
  const [sosModalOpen, setSosModalOpen] = useState(false);

  const current = LANGUAGES.find((l) => l.code === lang) || LANGUAGES[0];

  const filteredLanguages = useMemo(() => {
    if (!searchQuery.trim()) return LANGUAGES;
    const q = searchQuery.toLowerCase().trim();
    return LANGUAGES.filter(
      (l) =>
        l.name.toLowerCase().includes(q) ||
        l.nativeName.toLowerCase().includes(q) ||
        l.code.toLowerCase().includes(q)
    );
  }, [searchQuery]);

  const handleSelectLanguage = async (code: LangCode) => {
    setFeedbackMsg(null);
    const success = await setLanguage(code);
    if (success) {
      setFeedbackMsg(tr('settings.savedSuccess', { lang: code }));
      setTimeout(() => setFeedbackMsg(null), 3000);
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg }} edges={['top']}>
      {/* Header Bar */}
      <View style={[styles.headerBar, isRtlMode && styles.rtlRow]}>
        <Pressable onPress={() => navigation.goBack()} style={styles.backBtn} accessibilityLabel="Back">
          <Ionicons name={isRtlMode ? 'chevron-forward' : 'chevron-back'} size={24} color={theme.text} />
        </Pressable>
        <Text style={[styles.headerTitle, { color: theme.text }]}>{tr('settings')}</Text>
        <View style={{ width: 40 }}>
          {syncing && <ActivityIndicator size="small" color={theme.brand} />}
        </View>
      </View>

      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 40, paddingTop: 10 }}
      >
        {/* Brand card */}
        <GradientView gradient="indigo" style={styles.brandCard} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
          <View style={[styles.brandLogoRow, isRtlMode && styles.rtlRow]}>
            <View style={styles.brandLogo}>
              <Ionicons name="airplane" size={28} color="#fff" />
            </View>
            <View>
              <Text style={styles.brandName}>Ghumify</Text>
              <Text style={styles.brandTag}>{tr('tagline')}</Text>
            </View>
          </View>
          <View style={[styles.brandStats, isRtlMode && styles.rtlRow]}>
            <View style={styles.brandStat}>
              <Text style={styles.brandStatVal}>{LANGUAGES.length}</Text>
              <Text style={styles.brandStatLabel}>{tr('settings.statsLanguages') || 'Languages'}</Text>
            </View>
            <View style={styles.brandDivider} />
            <View style={styles.brandStat}>
              <Text style={styles.brandStatVal}>6</Text>
              <Text style={styles.brandStatLabel}>{tr('settings.statsCities') || 'Cities'}</Text>
            </View>
            <View style={styles.brandDivider} />
            <View style={styles.brandStat}>
              <Text style={styles.brandStatVal}>40+</Text>
              <Text style={styles.brandStatLabel}>{tr('settings.statsPlaces') || 'Places'}</Text>
            </View>
          </View>
        </GradientView>

        {/* Feedback Alert Messages */}
        {feedbackMsg && (
          <View style={[styles.alertBanner, { backgroundColor: '#10b98120', borderColor: '#10b981' }]}>
            <Ionicons name="checkmark-circle" size={18} color="#10b981" />
            <Text style={[styles.alertText, { color: '#10b981' }]}>{feedbackMsg}</Text>
          </View>
        )}
        {syncError && (
          <View style={[styles.alertBanner, { backgroundColor: '#f59e0b20', borderColor: '#f59e0b' }]}>
            <Ionicons name="alert-circle" size={18} color="#f59e0b" />
            <Text style={[styles.alertText, { color: '#f59e0b' }]}>{syncError}</Text>
          </View>
        )}

        {/* SOS & Emergency Contacts Section */}
        <Pressable
          onPress={() => setSosModalOpen(true)}
          style={({ pressed }) => ({ opacity: pressed ? 0.9 : 1, marginBottom: SPACING.lg })}
          accessibilityRole="button"
          accessibilityLabel="Emergency Contacts and SOS Settings"
        >
          <View
            style={[
              styles.sosCard,
              { backgroundColor: theme.card, borderColor: '#ef444450' },
              isRtlMode && styles.rtlRow,
              shadow(theme, 2),
            ]}
          >
            <View style={styles.sosCardIconWrap}>
              <Ionicons name="shield-checkmark" size={24} color="#ef4444" />
            </View>
            <View style={[{ flex: 1 }, isRtlMode && { alignItems: 'flex-end' }]}>
              <Text style={[styles.sosCardTitle, { color: theme.text }, isRtlMode && styles.rtlText]}>
                {tr('sos.emergencyContacts') || 'Emergency Contacts & SOS'}
              </Text>
              <Text style={[styles.sosCardSub, { color: theme.textMuted }, isRtlMode && styles.rtlText]}>
                {tr('sos.manageDesc') || 'Manage trusted contacts, live alerts & medical profile'}
              </Text>
            </View>
            <Ionicons name={isRtlMode ? 'chevron-back' : 'chevron-forward'} size={20} color={theme.textMuted} />
          </View>
        </Pressable>

        {/* Default Language Section */}
        <View style={styles.langSection}>
          <View style={[styles.langHeader, isRtlMode && styles.rtlRow]}>
            <Ionicons name="language" size={20} color={theme.brand} />
            <Text style={[styles.langTitle, { color: theme.text }]}>
              {tr('settings.defaultLanguage') || tr('changeLanguage')}
            </Text>
          </View>

          <Text style={[styles.currentLang, { color: theme.textMuted }, isRtlMode && styles.rtlText]}>
            {tr('settings.currently', { lang: `${current.nativeName} (${current.name})` }) ||
              `Currently: ${current.flag} ${current.nativeName} (${current.name})`}
          </Text>

          {/* Search bar */}
          <View style={[styles.searchBox, { backgroundColor: theme.card, borderColor: theme.border }, isRtlMode && styles.rtlRow]}>
            <Ionicons name="search" size={18} color={theme.textMuted} />
            <TextInput
              value={searchQuery}
              onChangeText={setSearchQuery}
              placeholder={tr('settings.searchLang') || 'Search language...'}
              placeholderTextColor={theme.textMuted}
              style={[styles.searchInput, { color: theme.text }, isRtlMode && styles.rtlText]}
            />
            {searchQuery.length > 0 && (
              <Pressable onPress={() => setSearchQuery('')}>
                <Ionicons name="close-circle" size={18} color={theme.textMuted} />
              </Pressable>
            )}
          </View>

          {/* Languages List */}
          <View style={styles.langGrid}>
            {filteredLanguages.map((l) => {
              const active = l.code === lang;
              return (
                <Pressable
                  key={l.code}
                  onPress={() => handleSelectLanguage(l.code as LangCode)}
                  style={({ pressed }) => ({ opacity: pressed ? 0.8 : 1 })}
                  accessibilityRole="radio"
                  accessibilityState={{ selected: active }}
                  accessibilityLabel={`${l.nativeName} (${l.name})`}
                >
                  <View
                    style={[
                      styles.langItem,
                      isRtlMode && styles.rtlRow,
                      {
                        backgroundColor: active ? theme.brand : theme.card,
                        borderColor: active ? theme.brand : theme.border,
                      },
                      shadow(theme, 1),
                    ]}
                  >
                    <Text style={styles.langItemFlag}>{l.flag}</Text>
                    <View style={[{ flex: 1 }, isRtlMode && { alignItems: 'flex-end' }]}>
                      <View style={{ flexDirection: isRtlMode ? 'row-reverse' : 'row', alignItems: 'center', gap: 6 }}>
                        <Text style={[styles.langItemNative, { color: active ? '#fff' : theme.text }]}>
                          {l.nativeName}
                        </Text>
                        {l.direction === 'rtl' && (
                          <View style={styles.rtlBadge}>
                            <Text style={styles.rtlBadgeText}>RTL</Text>
                          </View>
                        )}
                      </View>
                      <Text style={[styles.langItemEn, { color: active ? 'rgba(255,255,255,0.7)' : theme.textMuted }]}>
                        {l.name}
                      </Text>
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
          <View style={[styles.langHeader, isRtlMode && styles.rtlRow]}>
            <Ionicons name="information-circle-outline" size={20} color={theme.brand} />
            <Text style={[styles.langTitle, { color: theme.text }]}>
              {tr('settings.aboutTitle') || 'About Ghumify'}
            </Text>
          </View>
          <View style={[styles.aboutBox, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
            <Text style={[styles.aboutText, { color: theme.textSoft }, isRtlMode && styles.rtlText]}>
              {tr('settings.aboutDesc') ||
                'Ghumify is your complete travel companion for exploring India with personalized, time-based travel plans tailored to your needs.'}
            </Text>
          </View>
        </View>

        <Text style={[styles.versionText, { color: theme.textMuted }]}>
          {tr('settings.version') || 'Ghumify v1.0 · Made in India 🇮🇳'}
        </Text>
      </ScrollView>

      {/* Emergency Contacts & SOS Settings Modal */}
      <EmergencyContactsModal
        visible={sosModalOpen}
        onClose={() => setSosModalOpen(false)}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  headerBar: {
    height: 52,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '700',
  },
  backBtn: {
    padding: 6,
  },
  brandCard: {
    borderRadius: RADIUS.lg,
    padding: 20,
    marginBottom: SPACING.md,
  },
  brandLogoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 16,
  },
  brandLogo: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  brandName: {
    fontSize: 22,
    fontWeight: '800',
    color: '#fff',
  },
  brandTag: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.8)',
    marginTop: 2,
  },
  brandStats: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    backgroundColor: 'rgba(0,0,0,0.15)',
    borderRadius: RADIUS.md,
    paddingVertical: 10,
  },
  brandStat: {
    alignItems: 'center',
  },
  brandStatVal: {
    fontSize: 18,
    fontWeight: '800',
    color: '#fff',
  },
  brandStatLabel: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.7)',
    marginTop: 2,
  },
  brandDivider: {
    width: 1,
    height: 24,
    backgroundColor: 'rgba(255,255,255,0.2)',
  },
  alertBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    padding: 12,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    marginBottom: SPACING.md,
  },
  alertText: {
    fontSize: 13,
    fontWeight: '500',
    flex: 1,
  },
  langSection: {
    marginBottom: SPACING.lg,
  },
  langHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 6,
  },
  langTitle: {
    fontSize: 16,
    fontWeight: '700',
  },
  currentLang: {
    fontSize: 13,
    marginBottom: 12,
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    borderWidth: 1,
    borderRadius: RADIUS.md,
    paddingHorizontal: 12,
    height: 42,
    marginBottom: 14,
  },
  searchInput: {
    flex: 1,
    fontSize: 14,
  },
  langGrid: {
    gap: 8,
  },
  langItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    gap: 12,
  },
  langItemFlag: {
    fontSize: 22,
  },
  langItemNative: {
    fontSize: 15,
    fontWeight: '700',
  },
  langItemEn: {
    fontSize: 12,
    marginTop: 1,
  },
  langRadio: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
  },
  rtlBadge: {
    backgroundColor: 'rgba(0,0,0,0.15)',
    paddingHorizontal: 5,
    paddingVertical: 1,
    borderRadius: 4,
  },
  rtlBadgeText: {
    fontSize: 9,
    fontWeight: '700',
    color: '#666',
  },
  aboutSection: {
    marginBottom: SPACING.lg,
  },
  aboutBox: {
    padding: 14,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    marginTop: 6,
  },
  aboutText: {
    fontSize: 13,
    lineHeight: 19,
  },
  versionText: {
    textAlign: 'center',
    fontSize: 12,
    marginTop: 8,
  },
  sosCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderRadius: RADIUS.lg,
    borderWidth: 1.5,
    gap: 12,
  },
  sosCardIconWrap: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#ef444415',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sosCardTitle: {
    fontSize: 15,
    fontWeight: '700',
  },
  sosCardSub: {
    fontSize: 12,
    marginTop: 2,
  },
  rtlRow: {
    flexDirection: 'row-reverse',
  },
  rtlText: {
    textAlign: 'right',
  },
});
