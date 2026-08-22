import React, { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated, { useAnimatedStyle, useSharedValue, withTiming, withDelay, withSpring } from 'react-native-reanimated';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { getPlace, getCity } from '../lib/data';
import { getGenericPlace, getGenericCity } from '../lib/parser';
import { getCatMeta } from '../lib/categories';
import { Place } from '../lib/types';
import { RADIUS, SPACING, shadow } from '../lib/theme';
import GradientView from '../components/GradientView';
import { t } from '../lib/i18n';

interface Props {
  route: any;
  navigation: any;
}

export default function PlaceDetailScreen({ route, navigation }: Props) {
  const { theme, t: tr } = useApp();
  const place = getPlace(route.params?.placeId) || getGenericPlace(route.params?.placeId);
  const [audioPlaying, setAudioPlaying] = useState(false);

  const heroScale = useSharedValue(0.9);
  const contentOpacity = useSharedValue(0);
  const contentY = useSharedValue(30);
  const audioProgress = useSharedValue(0);

  useEffect(() => {
    heroScale.value = withSpring(1, { damping: 16, stiffness: 180 });
    contentOpacity.value = withDelay(150, withTiming(1, { duration: 500 }));
    contentY.value = withDelay(150, withSpring(0, { damping: 20 }));
  }, []);

  useEffect(() => {
    if (audioPlaying) {
      audioProgress.value = 0;
      audioProgress.value = withTiming(1, { duration: 8000 });
      const timer = setTimeout(() => setAudioPlaying(false), 8000);
      return () => clearTimeout(timer);
    }
  }, [audioPlaying]);

  const heroStyle = useAnimatedStyle(() => ({ transform: [{ scale: heroScale.value }] }));
  const contentStyle = useAnimatedStyle(() => ({ opacity: contentOpacity.value, transform: [{ translateY: contentY.value }] }));
  const audioBarStyle = useAnimatedStyle(() => ({ width: `${audioProgress.value * 100}%` }));

  if (!place) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: theme.text }}>Place not found</Text>
      </SafeAreaView>
    );
  }

  const city = getCity(place.cityId) || getGenericCity(place.cityId);
  const meta = getCatMeta(place.category);
  const w = city?.currentWeather;

  const toggleAudio = () => setAudioPlaying((p) => !p);

  return (
    <ScrollView style={{ flex: 1, backgroundColor: theme.bg }} showsVerticalScrollIndicator={false}>
      {/* Hero */}
      <Animated.View style={heroStyle}>
        <GradientView gradient={place.gradient} style={styles.hero} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
          <SafeAreaView edges={['top']} style={{ flex: 1 }}>
            <View style={styles.heroTop}>
              <Pressable onPress={() => navigation.goBack()} style={styles.heroBtn}>
                <Ionicons name="chevron-back" size={24} color="#fff" />
              </Pressable>
              <Pressable style={styles.heroBtn}>
                <Ionicons name="share-outline" size={20} color="#fff" />
              </Pressable>
            </View>
            <View style={styles.heroContent}>
              <View style={styles.heroIconRow}>
                <View style={styles.heroIconBubble}>
                  <Ionicons name={place.icon as any} size={34} color="#fff" />
                </View>
                <View style={styles.ratingBig}>
                  <Ionicons name="star" size={14} color="#FFD93D" />
                  <Text style={styles.ratingBigText}>{place.rating.toFixed(1)}</Text>
                </View>
              </View>
              <Text style={styles.heroCat}>{t(meta.labelKey)} · {place.subcategory}</Text>
              <Text style={styles.heroName}>{place.name}</Text>
              <Text style={styles.heroShort} numberOfLines={2}>{place.shortDesc}</Text>
            </View>
          </SafeAreaView>
        </GradientView>
      </Animated.View>

      {/* Animated content */}
      <Animated.View style={contentStyle}>
        <View style={styles.content}>
          {/* Quick stats row */}
          <View style={[styles.statsRow, { backgroundColor: theme.card }, shadow(theme, 1)]}>
            <Stat icon="time-outline" label="Timings" value={`${place.timings.open}–${place.timings.close}`} theme={theme} />
            <Divider theme={theme} />
            <Stat icon="cash-outline" label={tr('entryFee')} value={place.entryFee} theme={theme} />
            <Divider theme={theme} />
            <Stat icon="navigate-outline" label="Distance" value={`${place.distanceKm} km`} theme={theme} />
          </View>

          {/* Weather-aware note */}
          {w && (w.rainChance > 50 || w.tempC >= 35) ? (
            <View style={[styles.weatherNote, { backgroundColor: w.rainChance > 50 ? theme.brandSoft : theme.accentSoft }]}>
              <Ionicons name={w.rainChance > 50 ? 'rainy' : 'sunny'} size={18} color={w.rainChance > 50 ? theme.brand : theme.accent} />
              <Text style={[styles.weatherNoteText, { color: theme.text }]}>
                {w.rainChance > 50
                  ? `${w.rainChance}% rain expected — carry an umbrella and check timings for outdoor areas.`
                  : `Hot day (${w.tempC}°C) — visit early or late, carry water and sunscreen.`}
              </Text>
            </View>
          ) : null}

          {/* Action buttons */}
          <View style={styles.actionRow}>
            <Pressable onPress={toggleAudio} style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1, flex: 1 })}>
              <View style={[styles.actionBtn, { backgroundColor: theme.card, borderColor: theme.border }, shadow(theme, 1)]}>
                <Ionicons name={audioPlaying ? 'pause-circle' : 'headset'} size={20} color={theme.brand} />
                <Text style={[styles.actionText, { color: theme.text }]}>{tr('audioGuide')}</Text>
                <View style={styles.premiumTag}>
                  <Ionicons name="diamond" size={9} color={theme.accent} />
                  <Text style={[styles.premiumTagText, { color: theme.accent }]}>{tr('premium')}</Text>
                </View>
              </View>
            </Pressable>
            <Pressable style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1, flex: 1 })}>
              <View style={[styles.actionBtn, { backgroundColor: theme.card, borderColor: theme.border }, shadow(theme, 1)]}>
                <Ionicons name="car-sport" size={20} color={theme.brand} />
                <Text style={[styles.actionText, { color: theme.text }]}>{tr('bookRide')}</Text>
              </View>
            </Pressable>
          </View>

          {/* Audio progress bar when playing */}
          {audioPlaying ? (
            <View style={[styles.audioBarWrap, { backgroundColor: theme.card }]}>
              <View style={styles.audioBarTrack}>
                <Animated.View style={[styles.audioBarFill, { backgroundColor: theme.brand }, audioBarStyle]} />
              </View>
              <Text style={[styles.audioBarText, { color: theme.textMuted }]}>Playing audio guide · {place.name}</Text>
            </View>
          ) : null}

          {/* About */}
          <Section title={tr('about')} theme={theme}>
            <Text style={[styles.bodyText, { color: theme.textSoft }]}>{place.description}</Text>
          </Section>

          {/* History */}
          <Section title={tr('history')} theme={theme} icon="library-outline">
            <Text style={[styles.bodyText, { color: theme.textSoft }]}>{place.history}</Text>
          </Section>

          {/* Quick facts */}
          <Section title={tr('facts2')} theme={theme} icon="bulb-outline">
            <View style={styles.factList}>
              {place.facts.map((fact, i) => (
                <View key={i} style={[styles.factItem, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
                  <Ionicons name="checkmark-circle" size={16} color={theme.teal} />
                  <Text style={[styles.factText, { color: theme.text }]}>{fact}</Text>
                </View>
              ))}
            </View>
          </Section>

          {/* Timings & best time */}
          <Section title={tr('timings')} theme={theme} icon="time-outline">
            <View style={styles.infoGrid}>
              <InfoRow icon="time" label="Opening" value={`${place.timings.open}`} theme={theme} />
              <InfoRow icon="time" label="Closing" value={`${place.timings.close}`} theme={theme} />
              <InfoRow icon="cash-outline" label={tr('entryFee')} value={place.entryFee} theme={theme} />
              <InfoRow icon="sunny-outline" label={tr('bestTime')} value={place.bestTime} theme={theme} />
              {place.timings.note ? (
                <View style={[styles.infoNote, { backgroundColor: theme.accentSoft }]}>
                  <Ionicons name="information-circle" size={14} color={theme.accent} />
                  <Text style={[styles.infoNoteText, { color: theme.text }]}>{place.timings.note}</Text>
                </View>
              ) : null}
            </View>
          </Section>

          {/* What to carry */}
          <Section title={tr('whatToCarry')} theme={theme} icon="backpack-outline">
            <View style={styles.carryGrid}>
              {place.whatToCarry.map((item, i) => (
                <View key={i} style={[styles.carryItem, { backgroundColor: theme.tealSoft, borderColor: theme.teal }]}>
                  <Ionicons name="checkmark" size={14} color={theme.teal} />
                  <Text style={[styles.carryText, { color: theme.text }]}>{item}</Text>
                </View>
              ))}
            </View>
          </Section>

          {/* Must try */}
          {place.mustTry && place.mustTry.length > 0 ? (
            <Section title={tr('mustTry')} theme={theme} icon="restaurant-outline">
              <View style={styles.mustTryWrap}>
                {place.mustTry.map((item, i) => (
                  <View key={i} style={[styles.mustTryChip, { backgroundColor: theme.accentSoft }]}>
                    <Ionicons name="flame" size={13} color={theme.accent} />
                    <Text style={[styles.mustTryText, { color: theme.text }]}>{item}</Text>
                  </View>
                ))}
              </View>
            </Section>
          ) : null}

          {/* Special events */}
          {place.events && place.events.length > 0 ? (
            <Section title={tr('events')} theme={theme} icon="star-outline">
              <View style={styles.eventList}>
                {place.events.map((ev, i) => (
                  <View key={i} style={[styles.eventItem, { backgroundColor: theme.roseSoft }]}>
                    <View style={styles.eventTime}>
                      <Ionicons name="flame" size={16} color={theme.rose} />
                      <Text style={[styles.eventTimeText, { color: theme.rose }]}>{ev.time}</Text>
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={[styles.eventName, { color: theme.text }]}>{ev.name}</Text>
                      <Text style={[styles.eventDesc, { color: theme.textSoft }]}>{ev.description}</Text>
                    </View>
                  </View>
                ))}
              </View>
            </Section>
          ) : null}

          {/* Nearby attractions */}
          <Section title={tr('nearby')} theme={theme} icon="map-outline" last>
            <View style={styles.nearbyList}>
              {place.nearby.map((n, i) => (
                <View key={i} style={[styles.nearbyItem, { backgroundColor: theme.card, borderColor: theme.border }]}>
                  <View style={[styles.nearbyIcon, { backgroundColor: theme.brandSoft }]}>
                    <Ionicons name="location" size={16} color={theme.brand} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.nearbyName, { color: theme.text }]}>{n.name}</Text>
                    <Text style={[styles.nearbyType, { color: theme.textMuted }]}>{n.type} · {n.distance}</Text>
                  </View>
                  <Ionicons name="chevron-forward" size={16} color={theme.textMuted} />
                </View>
              ))}
            </View>
          </Section>

          {/* Address / map */}
          <View style={{ marginBottom: 30 }}>
            <Section title="Location" theme={theme} icon="location-outline" last>
              <View style={[styles.mapBox, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
                <View style={styles.mapPlaceholder}>
                  <Ionicons name="map" size={32} color={theme.brand} />
                  <Text style={[styles.mapPinText, { color: theme.textSoft }]}>Tap for directions</Text>
                </View>
                <View style={styles.mapAddr}>
                  <Ionicons name="location-outline" size={15} color={theme.brand} />
                  <Text style={[styles.mapAddrText, { color: theme.text }]}>{place.address}</Text>
                </View>
              </View>
            </Section>
          </View>
        </View>
      </Animated.View>
    </ScrollView>
  );
}

function Section({ title, theme, icon, children, last }: any) {
  return (
    <View style={[styles.section, last && { marginBottom: 0 }]}>
      <View style={styles.sectionHeader}>
        <Ionicons name={icon} size={18} color={theme.brand} />
        <Text style={[styles.sectionTitle, { color: theme.text }]}>{title}</Text>
      </View>
      {children}
    </View>
  );
}

function Stat({ icon, label, value, theme }: any) {
  return (
    <View style={styles.statItem}>
      <Ionicons name={icon} size={17} color={theme.brand} />
      <Text style={[styles.statLabel, { color: theme.textMuted }]}>{label}</Text>
      <Text style={[styles.statValue, { color: theme.text }]} numberOfLines={1}>{value}</Text>
    </View>
  );
}

function Divider({ theme }: any) {
  return <View style={{ width: 1, height: 40, backgroundColor: theme.border }} />;
}

function InfoRow({ icon, label, value, theme }: any) {
  return (
    <View style={styles.infoRow}>
      <View style={styles.infoRowLeft}>
        <Ionicons name={icon} size={16} color={theme.brand} />
        <Text style={[styles.infoRowLabel, { color: theme.textMuted }]}>{label}</Text>
      </View>
      <Text style={[styles.infoRowValue, { color: theme.text }]}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: { height: 340, borderBottomLeftRadius: 0, borderBottomRightRadius: 0 },
  heroTop: { flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 16, paddingTop: 4 },
  heroBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.2)', alignItems: 'center', justifyContent: 'center' },
  heroContent: { flex: 1, paddingHorizontal: 24, justifyContent: 'flex-end', paddingBottom: 28 },
  heroIconRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 },
  heroIconBubble: { width: 64, height: 64, borderRadius: 32, backgroundColor: 'rgba(255,255,255,0.22)', alignItems: 'center', justifyContent: 'center' },
  ratingBig: { flexDirection: 'row', alignItems: 'center', gap: 4, backgroundColor: 'rgba(0,0,0,0.28)', paddingHorizontal: 10, paddingVertical: 6, borderRadius: RADIUS.pill },
  ratingBigText: { color: '#fff', fontSize: 13, fontWeight: '800' },
  heroCat: { color: 'rgba(255,255,255,0.9)', fontSize: 12.5, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 },
  heroName: { color: '#fff', fontSize: 30, fontWeight: '900', letterSpacing: -0.5, marginBottom: 8 },
  heroShort: { color: 'rgba(255,255,255,0.85)', fontSize: 15, fontWeight: '500', lineHeight: 21 },
  content: { paddingHorizontal: 20, paddingTop: 20 },
  statsRow: { flexDirection: 'row', justifyContent: 'space-around', alignItems: 'center', paddingVertical: 16, borderRadius: RADIUS.lg, marginBottom: 16 },
  statItem: { alignItems: 'center', flex: 1, gap: 4 },
  statLabel: { fontSize: 11, fontWeight: '700' },
  statValue: { fontSize: 13, fontWeight: '800' },
  weatherNote: { flexDirection: 'row', gap: 10, alignItems: 'flex-start', paddingHorizontal: 16, paddingVertical: 14, borderRadius: RADIUS.md, marginBottom: 16 },
  weatherNoteText: { fontSize: 13, lineHeight: 18.5, flex: 1, fontWeight: '600' },
  actionRow: { flexDirection: 'row', gap: 12, marginBottom: 16 },
  actionBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, paddingVertical: 14, borderRadius: RADIUS.md, borderWidth: 1.5, position: 'relative' },
  actionText: { fontSize: 14, fontWeight: '800' },
  premiumTag: { position: 'absolute', top: -8, right: 10, flexDirection: 'row', alignItems: 'center', gap: 3, backgroundColor: '#fff', paddingHorizontal: 7, paddingVertical: 3, borderRadius: 8 },
  premiumTagText: { fontSize: 9, fontWeight: '800' },
  audioBarWrap: { borderRadius: RADIUS.md, paddingHorizontal: 14, paddingVertical: 12, marginBottom: 16 },
  audioBarTrack: { height: 4, backgroundColor: 'rgba(128,128,128,0.2)', borderRadius: 2, marginBottom: 8, overflow: 'hidden' },
  audioBarFill: { height: '100%', borderRadius: 2 },
  audioBarText: { fontSize: 12, fontWeight: '600' },
  section: { marginBottom: 26 },
  sectionHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 },
  sectionTitle: { fontSize: 17, fontWeight: '900' },
  bodyText: { fontSize: 14, lineHeight: 22 },
  factList: { gap: 8 },
  factItem: { flexDirection: 'row', gap: 8, alignItems: 'flex-start', paddingHorizontal: 14, paddingVertical: 12, borderRadius: RADIUS.md, borderWidth: 1 },
  factText: { fontSize: 13.5, lineHeight: 19, flex: 1, fontWeight: '500' },
  infoGrid: { gap: 6 },
  infoRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 8 },
  infoRowLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  infoRowLabel: { fontSize: 13.5, fontWeight: '600' },
  infoRowValue: { fontSize: 13.5, fontWeight: '700', flex: 1, textAlign: 'right' },
  infoNote: { flexDirection: 'row', gap: 6, alignItems: 'center', paddingHorizontal: 12, paddingVertical: 10, borderRadius: RADIUS.sm, marginTop: 8 },
  infoNoteText: { fontSize: 12.5, fontWeight: '600' },
  carryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  carryItem: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 12, paddingVertical: 9, borderRadius: RADIUS.pill, borderWidth: 1.5 },
  carryText: { fontSize: 13, fontWeight: '700' },
  mustTryWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  mustTryChip: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 14, paddingVertical: 10, borderRadius: RADIUS.md },
  mustTryText: { fontSize: 13.5, fontWeight: '700' },
  eventList: { gap: 8 },
  eventItem: { flexDirection: 'row', gap: 12, alignItems: 'center', paddingHorizontal: 14, paddingVertical: 14, borderRadius: RADIUS.md },
  eventTime: { alignItems: 'center', gap: 2 },
  eventTimeText: { fontSize: 12.5, fontWeight: '800' },
  eventName: { fontSize: 14, fontWeight: '800', marginBottom: 3 },
  eventDesc: { fontSize: 12.5, lineHeight: 17, fontWeight: '500' },
  nearbyList: { gap: 8 },
  nearbyItem: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 14, paddingVertical: 12, borderRadius: RADIUS.md, borderWidth: 1.5 },
  nearbyIcon: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center' },
  nearbyName: { fontSize: 14, fontWeight: '800' },
  nearbyType: { fontSize: 12, fontWeight: '600', marginTop: 2 },
  mapBox: { borderRadius: RADIUS.lg, borderWidth: 1.5, overflow: 'hidden' },
  mapPlaceholder: { height: 110, alignItems: 'center', justifyContent: 'center', gap: 6, backgroundColor: 'rgba(0,0,0,0.02)' },
  mapPinText: { fontSize: 12, fontWeight: '600' },
  mapAddr: { flexDirection: 'row', gap: 8, alignItems: 'flex-start', padding: 14, borderTopWidth: 1, borderTopColor: 'rgba(128,128,128,0.15)' },
  mapAddrText: { fontSize: 13, fontWeight: '600', flex: 1, lineHeight: 18 },
});
