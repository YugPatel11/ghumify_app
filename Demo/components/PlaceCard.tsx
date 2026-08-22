import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from 'react-native-reanimated';
import Ionicons from '@expo/vector-icons/Ionicons';
import { Place } from '../lib/types';
import { useApp } from '../lib/AppContext';
import { RADIUS, SPACING, shadow } from '../lib/theme';
import { getCatMeta } from '../lib/categories';
import GradientView from './GradientView';
import { t } from '../lib/i18n';

interface Props {
  place: Place;
  onPress: (place: Place) => void;
  index?: number;
}

const springConfig = { damping: 16, stiffness: 220, mass: 0.7 } as any;

export default function PlaceCard({ place, onPress, index = 0 }: Props) {
  const { theme } = useApp();
  const scale = useSharedValue(1);
  const meta = getCatMeta(place.category);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePressIn = () => { scale.value = withSpring(0.97, springConfig); };
  const handlePressOut = () => { scale.value = withSpring(1, springConfig); };

  return (
    <Animated.View style={animatedStyle}>
      <Pressable
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        onPress={() => onPress(place)}
        style={({ pressed }) => ({ opacity: pressed ? 0.92 : 1 })}
      >
        <View style={[styles.card, { backgroundColor: theme.card }, shadow(theme, 2)]}>
          <GradientView gradient={place.gradient} style={styles.hero} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
            <View style={styles.heroOverlay} />
            <View style={styles.heroTop}>
              <View style={styles.iconBubble}>
                <Ionicons name={place.icon as any} size={26} color="#fff" />
              </View>
              <View style={styles.ratingBadge}>
                <Ionicons name="star" size={11} color="#FFD93D" />
                <Text style={styles.ratingText}>{place.rating.toFixed(1)}</Text>
              </View>
            </View>
            <View style={styles.heroBottom}>
              <Text style={styles.catLabel}>{t(meta.labelKey)}</Text>
              <Text style={styles.placeName} numberOfLines={2}>{place.name}</Text>
            </View>
          </GradientView>

          <View style={styles.body}>
            <Text style={[styles.shortDesc, { color: theme.textSoft }]} numberOfLines={2}>
              {place.shortDesc}
            </Text>
            <View style={styles.metaRow}>
              <View style={styles.metaItem}>
                <Ionicons name="time-outline" size={13} color={theme.textMuted} />
                <Text style={[styles.metaText, { color: theme.textMuted }]}>{place.timings.open}–{place.timings.close}</Text>
              </View>
              <View style={styles.metaItem}>
                <Ionicons name="navigate-outline" size={13} color={theme.textMuted} />
                <Text style={[styles.metaText, { color: theme.textMuted }]}>{place.distanceKm} km away</Text>
              </View>
            </View>
          </View>
        </View>
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  card: { borderRadius: RADIUS.lg, marginBottom: SPACING.md, overflow: 'hidden' },
  hero: { height: 140, padding: SPACING.md, justifyContent: 'space-between' },
  heroOverlay: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.12)' },
  heroTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  iconBubble: {
    width: 46, height: 46, borderRadius: 23, backgroundColor: 'rgba(255,255,255,0.22)',
    alignItems: 'center', justifyContent: 'center',
  },
  ratingBadge: {
    flexDirection: 'row', alignItems: 'center', gap: 3, backgroundColor: 'rgba(0,0,0,0.3)',
    paddingHorizontal: 8, paddingVertical: 4, borderRadius: RADIUS.pill,
  },
  ratingText: { color: '#fff', fontSize: 11, fontWeight: '800' },
  heroBottom: {},
  catLabel: { color: 'rgba(255,255,255,0.85)', fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 4 },
  placeName: { color: '#fff', fontSize: 19, fontWeight: '800', lineHeight: 24 },
  body: { padding: SPACING.md },
  shortDesc: { fontSize: 13.5, lineHeight: 19, marginBottom: SPACING.sm },
  metaRow: { flexDirection: 'row', gap: 16 },
  metaItem: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  metaText: { fontSize: 12, fontWeight: '600' },
});
