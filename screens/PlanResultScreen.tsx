import React, { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated, { useAnimatedStyle, useSharedValue, withSpring, withTiming, withDelay } from 'react-native-reanimated';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { generateItinerary } from '../lib/itinerary';
import { getOrCreateCity } from '../lib/parser';
import { CITIES } from '../lib/data';
import { Itinerary, ItineraryStop, Category } from '../lib/types';
import { RADIUS, shadow } from '../lib/theme';
import GradientView from '../components/GradientView';
import ChatModal from '../components/ChatModal';
import NotificationPreferencesModal from '../components/NotificationPreferencesModal';
import NotificationInboxModal from '../components/NotificationInboxModal';
import SosButton from '../components/SosButton';
import { NotificationClient, AlertItem, TravelEstimateItem } from '../lib/notifications';

interface Props {
  route: any;
  navigation: any;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export default function PlanResultScreen({ route, navigation }: Props) {
  const { theme, t: tr } = useApp();
  const [itinerary, setItinerary] = useState<Itinerary | null>(null);
  const [isKnownCity, setIsKnownCity] = useState(true);
  const [chatOpen, setChatOpen] = useState(false);
  const [prefModalOpen, setPrefModalOpen] = useState(false);
  const [inboxModalOpen, setInboxModalOpen] = useState(false);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);
  const [estimates, setEstimates] = useState<TravelEstimateItem[]>([]);
  const [activeBanner, setActiveBanner] = useState<{ title: string; body: string; stopId?: string } | null>(null);
  const params = route.params || {};

  useEffect(() => {
    const { cityName, hours, interests, startTime } = params;
    if (!cityName) return;
    const result = getOrCreateCity(cityName, CITIES);
    setIsKnownCity(result.isKnown);
    const it = generateItinerary(
      result.city.id,
      result.city.name,
      startTime || '09:00',
      hours || 6,
      (interests || []) as Category[],
      result.city.currentWeather,
      result.places,
    );
    setItinerary(it);

    // Sync trip to server and register local backup alarms
    const tripId = `trip_${result.city.id}_${Date.now()}`;
    syncTripToServer(tripId, it);
  }, [params.cityName]);

  const syncTripToServer = async (tripId: string, it: Itinerary) => {
    try {
      const today = new Date().toISOString().split('T')[0];
      const stopsPayload = it.stops.map((s, idx) => ({
        id: s.id,
        title: s.title,
        subtitle: s.subtitle,
        stopOrder: idx + 1,
        stopType: s.type,
        plannedArrivalAt: `${today}T${s.startTime}:00Z`,
        plannedDepartureAt: `${today}T${s.endTime}:00Z`,
        stayDurationMinutes: s.durationMin,
        transportMode: 'driving',
        lat: 26.9124, // fallback city coordinates
        lng: 75.7873,
      }));

      await fetch(`${BACKEND_URL}/api/v1/trips/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: tripId,
          userId: 'user_demo',
          title: `${it.cityName} Day Trip`,
          cityId: it.cityId,
          cityName: it.cityName,
          stops: stopsPayload,
        }),
      });

      // Fetch scheduled alerts and travel estimates
      const alertRes = await fetch(`${BACKEND_URL}/api/v1/trips/${tripId}/alerts`);
      if (alertRes.ok) {
        const data = await alertRes.json();
        setAlerts(data.alerts || []);
        setEstimates(data.travelEstimates || []);

        // Schedule local backup alarms (Layer 2)
        NotificationClient.scheduleLocalBackupAlerts(tripId, data.alerts || [], (triggered) => {
          setActiveBanner({
            title: triggered.type === 'leave_now' ? 'Time to Leave!' : 'Time to Head Out!',
            body: `Alert for ${triggered.stopTitle}`,
            stopId: triggered.stopId,
          });
        });
      }
    } catch (e) {
      console.warn('Trip alert sync failed:', e);
    }
  };

  if (!itinerary) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg, alignItems: 'center', justifyContent: 'center' }} edges={['top']}>
        <Text style={{ color: theme.text }}>Generating...</Text>
      </SafeAreaView>
    );
  }

  const w = itinerary.weather;
  const visitCount = itinerary.stops.filter((s) => s.type === 'visit').length;

  const openPlace = (placeId?: string) => {
    if (placeId) navigation.navigate('PlaceDetail', { placeId });
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg }} edges={['top']}>
      <View style={[styles.headerBar, { backgroundColor: theme.card, borderBottomColor: theme.border }]}>
        <Pressable onPress={() => navigation.goBack()} style={styles.backBtn}>
          <Ionicons name="chevron-back" size={24} color={theme.text} />
        </Pressable>
        <View style={styles.headerActions}>
          <Pressable
            onPress={() => setInboxModalOpen(true)}
            style={styles.headerBtn}
            accessibilityLabel="Trip Alerts Inbox"
          >
            <Ionicons name="notifications-outline" size={21} color={theme.text} />
          </Pressable>
          <Pressable
            onPress={() => setPrefModalOpen(true)}
            style={styles.headerBtn}
            accessibilityLabel="Notification Settings"
          >
            <Ionicons name="options-outline" size={21} color={theme.text} />
          </Pressable>
          <Pressable
            onPress={() => setChatOpen(true)}
            style={styles.headerBtn}
            accessibilityLabel="Ask Ghumify AI"
          >
            <Ionicons name="sparkles" size={21} color={theme.brand} />
          </Pressable>
          <SosButton
            size="compact"
            tripId={itinerary.cityId}
            currentStopName={itinerary.stops[0]?.title}
          />
        </View>
      </View>

      <ChatModal
        visible={chatOpen}
        onClose={() => setChatOpen(false)}
        context={{ cityName: itinerary.cityName, hours: params.hours }}
      />

      <NotificationPreferencesModal
        visible={prefModalOpen}
        onClose={() => setPrefModalOpen(false)}
      />

      <NotificationInboxModal
        visible={inboxModalOpen}
        onClose={() => setInboxModalOpen(false)}
        onNavigateToStop={(stopId) => {
          // Open place or focus stop
        }}
      />

      {/* Foreground Alert Banner */}
      {activeBanner && (
        <View style={[styles.activeBanner, { backgroundColor: theme.brand, borderColor: theme.border }]}>
          <View style={styles.activeBannerTextCol}>
            <Text style={styles.activeBannerTitle}>{activeBanner.title}</Text>
            <Text style={styles.activeBannerBody}>{activeBanner.body}</Text>
          </View>
          <View style={styles.activeBannerActions}>
            <Pressable
              onPress={() => {
                if (activeBanner.stopId) {
                  NotificationClient.handleDeparted('current_trip', activeBanner.stopId);
                }
                setActiveBanner(null);
              }}
              style={styles.bannerActionBtn}
            >
              <Text style={styles.bannerActionText}>I'm leaving</Text>
            </Pressable>
            <Pressable
              onPress={() => setActiveBanner(null)}
              style={[styles.bannerActionBtn, { backgroundColor: 'rgba(255,255,255,0.2)' }]}
            >
              <Text style={styles.bannerActionText}>Dismiss</Text>
            </Pressable>
          </View>
        </View>
      )}

      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 40 }}>
        {/* Summary header */}
        <GradientView gradient="cherry" style={styles.summaryHeader} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
          <Text style={styles.summaryCity}>{itinerary.cityName}</Text>
          <Text style={styles.summaryDate}>{itinerary.date}</Text>
          <View style={styles.summaryRow}>
            <View style={styles.summaryStat}>
              <Text style={styles.summaryStatVal}>{params.hours}h</Text>
              <Text style={styles.summaryStatLabel}>{tr('plan')}</Text>
            </View>
            <View style={styles.summaryDivider} />
            <View style={styles.summaryStat}>
              <Text style={styles.summaryStatVal}>{visitCount}</Text>
              <Text style={styles.summaryStatLabel}>stops</Text>
            </View>
            <View style={styles.summaryDivider} />
            <View style={styles.summaryStat}>
              <Text style={styles.summaryStatVal}>{itinerary.startTime}</Text>
              <Text style={styles.summaryStatLabel}>start</Text>
            </View>
            <View style={styles.summaryDivider} />
            <View style={styles.summaryStat}>
              <Text style={styles.summaryStatVal}>{itinerary.endTime}</Text>
              <Text style={styles.summaryStatLabel}>end</Text>
            </View>
          </View>
          <View style={styles.weatherStrip}>
            <Ionicons name={w.condition === 'rainy' ? 'rainy' : 'sunny'} size={14} color="#fff" />
            <Text style={styles.weatherStripText}>{w.tempC}°C · {w.conditionText} · {w.rainChance}% rain</Text>
          </View>
        </GradientView>

        {/* Generic city notice */}
        {!isKnownCity && (
          <View style={[styles.genericNotice, { backgroundColor: theme.accentSoft }]}>
            <Ionicons name="sparkles-outline" size={16} color={theme.accent} />
            <Text style={[styles.genericNoticeText, { color: theme.text }]}>
              We are building detailed coverage for {itinerary.cityName}. Here is a starter plan — tap any stop for more info!
            </Text>
          </View>
        )}

        {/* Timeline */}
        <View style={styles.timelineWrap}>
          {itinerary.stops.map((stop, i) => (
            <TimelineStop key={stop.id} stop={stop} theme={theme} index={i} onPress={() => openPlace(stop.placeId)} tr={tr} />
          ))}
        </View>

        {/* Travel tips */}
        <View style={styles.tipsSection}>
          <View style={styles.tipsHeader}>
            <Ionicons name="bulb-outline" size={18} color={theme.accent} />
            <Text style={[styles.tipsTitle, { color: theme.text }]}>{tr('travelTips')}</Text>
          </View>
          {itinerary.tips.map((tip, i) => (
            <View key={i} style={[styles.tipItem, { backgroundColor: theme.accentSoft }]}>
              <Ionicons name="checkmark-circle" size={16} color={theme.accent} />
              <Text style={[styles.tipText, { color: theme.text }]}>{tip}</Text>
            </View>
          ))}
        </View>

        {/* Transport section */}
        <View style={styles.transportSection}>
          <View style={styles.tipsHeader}>
            <Ionicons name="car-outline" size={18} color={theme.brand} />
            <Text style={[styles.tipsTitle, { color: theme.text }]}>{tr('transport')}</Text>
          </View>
          <View style={styles.transportGrid}>
            {[
              { name: 'Uber', icon: 'car-sport' },
              { name: 'Rapido', icon: 'bicycle' },
              { name: 'Auto', icon: 'car' },
              { name: 'Metro', icon: 'train' },
            ].map((tp) => (
              <Pressable key={tp.name} style={({ pressed }) => ({ opacity: pressed ? 0.8 : 1 })}>
                <View style={[styles.transportCard, { backgroundColor: theme.card, borderColor: theme.border }]}>
                  <Ionicons name={tp.icon as any} size={22} color={theme.brand} />
                  <Text style={[styles.transportName, { color: theme.text }]}>{tp.name}</Text>
                  <Text style={[styles.transportEta, { color: theme.textMuted }]}>~{Math.max(5, Math.round(itinerary.totalDistanceKm / 4))} min</Text>
                </View>
              </Pressable>
            ))}
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function TimelineStop({ stop, theme, index, onPress, tr }: any) {
  const opacity = useSharedValue(0);
  const translateX = useSharedValue(20);
  const animStyle = useAnimatedStyle(() => ({ opacity: opacity.value, transform: [{ translateX: translateX.value }] }));
  useEffect(() => {
    opacity.value = withDelay(index * 80, withTiming(1, { duration: 400 }));
    translateX.value = withDelay(index * 80, withSpring(0, { damping: 18 }));
  }, []);

  const isTravel = stop.type === 'travel';
  const isMeal = stop.type === 'meal';
  const isEvent = stop.type === 'event';
  const isVisit = stop.type === 'visit';
  const pressable = (isVisit || isMeal) && !!stop.placeId;

  const bubbleBg = isTravel ? theme.brandSoft : isMeal ? theme.accentSoft : isEvent ? theme.roseSoft : theme.tealSoft;
  const iconColor = isTravel ? theme.brand : isMeal ? theme.accent : isEvent ? theme.rose : theme.teal;

  const Inner = (
    <View style={[styles.stopCard, !isTravel && { backgroundColor: theme.card }, !isTravel && shadow(theme, 1)]}>
      <View style={styles.stopTimeCol}>
        <Text style={[styles.stopTime, { color: isTravel ? theme.textMuted : theme.text }]}>{fmt(stop.startTime)}</Text>
        <View style={[styles.stopIconBubble, { backgroundColor: bubbleBg }]}>
          <Ionicons name={stopIcon(stop) as any} size={16} color={iconColor} />
        </View>
        <View style={[styles.stopLine, { backgroundColor: theme.border }]} />
      </View>
      <View style={styles.stopContent}>
        {isTravel ? (
          <View style={[styles.travelBadge, { backgroundColor: theme.brandSoft, borderColor: theme.brand }]}>
            <Ionicons name="navigate-circle" size={16} color={theme.brand} />
            <Text style={[styles.travelBadgeText, { color: theme.brand }]}>
              Leave at {fmt(stop.startTime)} · {stop.durationMin} min travel · Arrive {fmt(stop.endTime)}
            </Text>
          </View>
        ) : null}
        <Text style={[styles.stopTitle, { color: isTravel ? theme.textMuted : theme.text }]}>{stop.title}</Text>
        <Text style={[styles.stopSub, { color: theme.textMuted }]}>{stop.subtitle}</Text>
        {stop.note ? (
          <Text style={[styles.stopNote, { color: theme.textSoft }]} numberOfLines={2}>{stop.note}</Text>
        ) : null}
        {pressable ? (
          <View style={styles.stopFooter}>
            <View style={{ flexDirection: 'row', gap: 6, alignItems: 'center' }}>
              <Pressable
                onPress={() => NotificationClient.handleDeparted('current_trip', stop.id)}
                style={[styles.miniActionBtn, { backgroundColor: theme.accentSoft }]}
              >
                <Ionicons name="exit-outline" size={13} color={theme.accent} />
                <Text style={[styles.miniActionText, { color: theme.accent }]}>I'm leaving</Text>
              </Pressable>
              <Pressable
                onPress={() => NotificationClient.openNavigation(26.9124, 75.7873, stop.title)}
                style={[styles.miniActionBtn, { backgroundColor: theme.brandSoft }]}
              >
                <Ionicons name="navigate-outline" size={13} color={theme.brand} />
                <Text style={[styles.miniActionText, { color: theme.brand }]}>Navigate</Text>
              </Pressable>
            </View>
            <Text style={[styles.stopDur, { color: theme.textMuted }]}>{stop.startTime}–{stop.endTime}</Text>
          </View>
        ) : (
          <Text style={[styles.stopDur2, { color: theme.textMuted }]}>{stop.durationMin} min</Text>
        )}
      </View>
    </View>
  );

  return (
    <Animated.View style={animStyle}>
      {pressable ? (
        <Pressable onPress={onPress} style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1 })}>
          {Inner}
        </Pressable>
      ) : (
        Inner
      )}
    </Animated.View>
  );
}

function fmt(t: string): string {
  const [h, m] = t.split(':').map(Number);
  const period = h >= 12 ? 'PM' : 'AM';
  let h12 = h % 12;
  if (h12 === 0) h12 = 12;
  return `${h12}:${String(m).padStart(2, '0')}`;
}

function stopIcon(stop: ItineraryStop): string {
  if (stop.type === 'travel') return 'navigate';
  if (stop.type === 'meal') return 'fast-food';
  if (stop.type === 'event') return 'star';
  return stop.icon;
}

const styles = StyleSheet.create({
  headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 14, paddingVertical: 12, borderBottomWidth: 1 },
  backBtn: { width: 40, alignItems: 'center' },
  headerActions: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  headerBtn: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  headerTitle: { fontSize: 17, fontWeight: '800', flex: 1, textAlign: 'center' },
  activeBanner: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: 12, marginHorizontal: 16, marginTop: 10, borderRadius: RADIUS.md, borderWidth: 1 },
  activeBannerTextCol: { flex: 1, paddingRight: 8 },
  activeBannerTitle: { color: '#fff', fontSize: 13, fontWeight: 'bold' },
  activeBannerBody: { color: 'rgba(255,255,255,0.9)', fontSize: 12, marginTop: 2 },
  activeBannerActions: { flexDirection: 'row', gap: 6 },
  bannerActionBtn: { backgroundColor: '#fff', paddingHorizontal: 10, paddingVertical: 6, borderRadius: RADIUS.pill },
  bannerActionText: { fontSize: 11.5, fontWeight: 'bold', color: '#1e1b4b' },
  summaryHeader: { paddingHorizontal: 24, paddingVertical: 26, marginHorizontal: 16, marginTop: 10, borderRadius: RADIUS.xl, shadowColor: '#000', shadowOpacity: 0.15, shadowRadius: 20, elevation: 8 },
  summaryCity: { color: '#fff', fontSize: 26, fontWeight: '900' },
  summaryDate: { color: 'rgba(255,255,255,0.85)', fontSize: 13, fontWeight: '600', marginTop: 2, marginBottom: 18 },
  summaryRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 14 },
  summaryStat: { flex: 1, alignItems: 'center' },
  summaryStatVal: { color: '#fff', fontSize: 17, fontWeight: '800' },
  summaryStatLabel: { color: 'rgba(255,255,255,0.7)', fontSize: 10.5, fontWeight: '600', marginTop: 2 },
  summaryDivider: { width: 1, height: 28, backgroundColor: 'rgba(255,255,255,0.2)' },
  weatherStrip: { flexDirection: 'row', alignItems: 'center', gap: 6, alignSelf: 'flex-start', backgroundColor: 'rgba(255,255,255,0.15)', paddingHorizontal: 12, paddingVertical: 7, borderRadius: RADIUS.pill },
  weatherStripText: { color: '#fff', fontSize: 12, fontWeight: '700' },
  genericNotice: { flexDirection: 'row', gap: 8, alignItems: 'flex-start', marginHorizontal: 16, marginTop: 12, paddingHorizontal: 14, paddingVertical: 12, borderRadius: RADIUS.md },
  genericNoticeText: { fontSize: 12.5, fontWeight: '600', flex: 1, lineHeight: 17 },
  timelineWrap: { paddingHorizontal: 20, paddingTop: 20 },
  stopCard: { flexDirection: 'row', marginBottom: 4, borderRadius: RADIUS.md, padding: 12, minHeight: 80 },
  stopTimeCol: { width: 56, alignItems: 'center', marginRight: 10 },
  stopTime: { fontSize: 12.5, fontWeight: '800', marginBottom: 8 },
  stopIconBubble: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center', marginBottom: 8 },
  stopLine: { width: 2, flex: 1, minHeight: 16 },
  stopContent: { flex: 1, paddingVertical: 2 },
  travelBadge: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 10, paddingVertical: 5, borderRadius: RADIUS.pill, marginBottom: 8, alignSelf: 'flex-start', borderWidth: 1 },
  travelBadgeText: { fontSize: 11.5, fontWeight: '700' },
  stopTitle: { fontSize: 15.5, fontWeight: '800', marginBottom: 3 },
  stopSub: { fontSize: 12.5, fontWeight: '600', marginBottom: 4 },
  stopNote: { fontSize: 12.5, lineHeight: 18, marginBottom: 6 },
  stopFooter: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 6 },
  miniActionBtn: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 8, paddingVertical: 4, borderRadius: RADIUS.pill },
  miniActionText: { fontSize: 11, fontWeight: '700' },
  stopDetail: { fontSize: 12.5, fontWeight: '800' },
  stopDur: { fontSize: 11.5, fontWeight: '600' },
  stopDur2: { fontSize: 11.5, fontWeight: '600', marginTop: 4 },
  tipsSection: { paddingHorizontal: 20, marginTop: 24 },
  tipsHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 },
  tipsTitle: { fontSize: 16.5, fontWeight: '800' },
  tipItem: { flexDirection: 'row', gap: 8, alignItems: 'flex-start', paddingHorizontal: 14, paddingVertical: 12, borderRadius: RADIUS.md, marginBottom: 8 },
  tipText: { fontSize: 13, lineHeight: 18.5, flex: 1 },
  transportSection: { paddingHorizontal: 20, marginTop: 26 },
  transportGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  transportCard: { width: '47%', alignItems: 'center', paddingVertical: 16, borderRadius: RADIUS.md, borderWidth: 1.5, gap: 6 },
  transportName: { fontSize: 14, fontWeight: '800' },
  transportEta: { fontSize: 11.5, fontWeight: '600' },
});

