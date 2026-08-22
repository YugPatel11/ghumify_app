import React, { useMemo, useState } from 'react';
import { FlatList, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { CITIES } from '../lib/data';
import { getOrCreateCity, getAllStaysByCity, findCityById } from '../lib/parser';
import { Stay } from '../lib/types';
import { RADIUS, shadow } from '../lib/theme';
import GradientView from '../components/GradientView';

const TYPES: { key: Stay['type'] | 'All'; icon: string }[] = [
  { key: 'All', icon: 'apps' },
  { key: 'Luxury', icon: 'diamond' },
  { key: 'Premium', icon: 'star' },
  { key: 'Mid-Range', icon: 'home' },
  { key: 'Budget', icon: 'wallet' },
  { key: 'Dharamshala', icon: 'flower' },
  { key: 'Hostel', icon: 'bed' },
];

interface Props {
  navigation: any;
}

export default function StaysScreen({ navigation }: Props) {
  const { theme, t: tr } = useApp();
  const [cityId, setCityId] = useState('indore');
  const [type, setType] = useState<Stay['type'] | 'All'>('All');
  const [searchInput, setSearchInput] = useState('');

  const city = findCityById(cityId, CITIES)!;
  const allStays = useMemo(() => getAllStaysByCity(cityId), [cityId]);
  const filtered = useMemo(() => {
    if (type === 'All') return allStays;
    return allStays.filter((s) => s.type === type);
  }, [allStays, type]);

  const minPrice = filtered.length ? Math.min(...filtered.map((s) => s.pricePerNight)) : 0;
  const maxPrice = filtered.length ? Math.max(...filtered.map((s) => s.pricePerNight)) : 0;

  const handleCitySearch = () => {
    if (!searchInput.trim()) return;
    const result = getOrCreateCity(searchInput.trim(), CITIES);
    setCityId(result.city.id);
    setSearchInput('');
    setType('All');
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg }} edges={['top']}>
      <View style={styles.container}>
        <View style={styles.headerRow}>
          <View>
            <Text style={[styles.screenTitle, { color: theme.text }]}>{tr('stays')}</Text>
            <Text style={[styles.screenSub, { color: theme.textMuted }]}>{city.name} · {filtered.length} options</Text>
          </View>
          <Pressable onPress={() => navigation.navigate('Settings')} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
            <View style={[styles.settingsBtn, { backgroundColor: theme.card, borderColor: theme.border }]}>
              <Ionicons name="language" size={20} color={theme.brand} />
            </View>
          </Pressable>
        </View>

        {/* City search - any city worldwide */}
        <View style={{ paddingHorizontal: 20, marginBottom: 14 }}>
          <View style={[styles.citySearchBox, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <Ionicons name="search" size={18} color={theme.accent} />
            <TextInput
              value={searchInput}
              onChangeText={setSearchInput}
              placeholder="Search stays in any city..."
              placeholderTextColor={theme.textMuted}
              style={[styles.citySearchInput, { color: theme.text }]}
              returnKeyType="search"
              onSubmitEditing={handleCitySearch}
            />
            {searchInput ? (
              <Pressable onPress={handleCitySearch} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
                <View style={[styles.searchBtn, { backgroundColor: theme.accent }]}>
                  <Ionicons name="arrow-forward" size={16} color="#fff" />
                </View>
              </Pressable>
            ) : null}
          </View>
        </View>

        {/* City selector */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 14 }}>
          {CITIES.map((c) => {
            const active = c.id === cityId;
            return (
              <Pressable key={c.id} onPress={() => { setCityId(c.id); setType('All'); }} style={{ marginRight: 8 }}>
                <View style={[styles.cityPill, { backgroundColor: active ? theme.brand : theme.card, borderColor: active ? theme.brand : theme.border }]}>
                  <Text style={[styles.cityPillText, { color: active ? '#fff' : theme.text }]}>{c.name}</Text>
                </View>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* Budget range banner */}
        <View style={{ paddingHorizontal: 20, marginBottom: 14 }}>
          <View style={[styles.budgetBanner, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
            <Ionicons name="pricetag-outline" size={18} color={theme.accent} />
            <View style={{ flex: 1 }}>
              <Text style={[styles.budgetText, { color: theme.text }]}>
                {type === 'All' ? 'All budgets' : `${type} stays`} in {city.name}
              </Text>
              <Text style={[styles.budgetRange, { color: theme.textMuted }]}>
                {filtered.length > 0 ? `₹${minPrice} – ₹${maxPrice} ${tr('perNight')}` : 'No stays found'}
              </Text>
            </View>
          </View>
        </View>

        {/* Type filter */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 16 }}>
          {TYPES.map((tp) => {
            const active = type === tp.key;
            return (
              <Pressable key={tp.key} onPress={() => setType(tp.key)} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
                <View style={[styles.typeChip, { backgroundColor: active ? theme.brand : theme.card, borderColor: active ? theme.brand : theme.border, marginRight: 8 }]}>
                  <Ionicons name={tp.icon as any} size={14} color={active ? '#fff' : theme.brand} />
                  <Text style={[styles.typeText, { color: active ? '#fff' : theme.text }]}>{tp.key}</Text>
                </View>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* Stays list */}
        <FlatList
          data={filtered}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 30 }}
          showsVerticalScrollIndicator={false}
          ListEmptyComponent={
            <View style={styles.empty}>
              <Ionicons name="bed-outline" size={48} color={theme.textMuted} />
              <Text style={[styles.emptyText, { color: theme.textSoft }]}>No stays found. Try a different filter or search another city.</Text>
            </View>
          }
          renderItem={({ item }) => (
            <StayCard stay={item} theme={theme} tr={tr} />
          )}
        />
      </View>
    </SafeAreaView>
  );
}

function StayCard({ stay, theme, tr }: any) {
  return (
    <View style={[styles.card, { backgroundColor: theme.card }, shadow(theme, 2)]}>
      <GradientView gradient={stay.gradient} style={styles.stayHero} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
        <View style={styles.stayHeroOverlay} />
        <View style={styles.stayHeroTop}>
          <View style={styles.stayTypeTag}>
            <Text style={styles.stayTypeTagText}>{stay.type}</Text>
          </View>
          <View style={styles.stayRating}>
            <Ionicons name="star" size={11} color="#FFD93D" />
            <Text style={styles.stayRatingText}>{stay.rating.toFixed(1)}</Text>
          </View>
        </View>
        <View style={styles.stayHeroBottom}>
          <Ionicons name="bed" size={24} color="#fff" />
        </View>
      </GradientView>

      <View style={styles.stayBody}>
        <Text style={[styles.stayName, { color: theme.text }]} numberOfLines={1}>{stay.name}</Text>
        <View style={styles.stayAddrRow}>
          <Ionicons name="location-outline" size={12} color={theme.textMuted} />
          <Text style={[styles.stayAddr, { color: theme.textMuted }]} numberOfLines={1}>{stay.address}</Text>
        </View>
        <Text style={[styles.stayDesc, { color: theme.textSoft }]} numberOfLines={2}>{stay.description}</Text>

        <View style={styles.amenRow}>
          {stay.amenities.slice(0, 5).map((a: string, i: number) => (
            <View key={i} style={[styles.amenChip, { backgroundColor: theme.brandSoft }]}>
              <Text style={[styles.amenText, { color: theme.brand }]}>{a}</Text>
            </View>
          ))}
        </View>

        <View style={styles.stayFooter}>
          <View style={styles.priceWrap}>
            <Text style={[styles.price, { color: theme.text }]}>₹{stay.pricePerNight}</Text>
            <Text style={[styles.priceUnit, { color: theme.textMuted }]}>{tr('perNight')}</Text>
          </View>
          <Pressable style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1 })}>
            <GradientView gradient="cherry" style={styles.bookBtn} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }}>
              <Text style={styles.bookBtnText}>Book Now</Text>
            </GradientView>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingTop: 8, paddingBottom: 14 },
  screenTitle: { fontSize: 26, fontWeight: '900', letterSpacing: -0.5 },
  screenSub: { fontSize: 13, fontWeight: '600', marginTop: 2 },
  settingsBtn: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', borderWidth: 1.5 },
  citySearchBox: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 14, borderRadius: RADIUS.md, borderWidth: 1.5, height: 50 },
  citySearchInput: { flex: 1, fontSize: 15, fontWeight: '500' },
  searchBtn: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
  cityPill: { paddingHorizontal: 16, paddingVertical: 9, borderRadius: RADIUS.pill, borderWidth: 1.5 },
  cityPillText: { fontSize: 13.5, fontWeight: '800' },
  budgetBanner: { flexDirection: 'row', gap: 12, alignItems: 'center', paddingHorizontal: 16, paddingVertical: 14, borderRadius: RADIUS.md, borderWidth: 1.5 },
  budgetText: { fontSize: 14, fontWeight: '800' },
  budgetRange: { fontSize: 12.5, fontWeight: '600', marginTop: 3 },
  typeChip: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 14, paddingVertical: 9, borderRadius: RADIUS.pill, borderWidth: 1.5 },
  typeText: { fontSize: 13, fontWeight: '700' },
  empty: { alignItems: 'center', justifyContent: 'center', paddingTop: 60, gap: 12 },
  emptyText: { fontSize: 14, fontWeight: '600', textAlign: 'center', paddingHorizontal: 40 },
  card: { borderRadius: RADIUS.lg, marginBottom: 14, overflow: 'hidden' },
  stayHero: { height: 90, padding: 14, justifyContent: 'space-between', position: 'relative' },
  stayHeroOverlay: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.1)' },
  stayHeroTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', zIndex: 2 },
  stayTypeTag: { backgroundColor: 'rgba(255,255,255,0.25)', paddingHorizontal: 10, paddingVertical: 5, borderRadius: RADIUS.pill },
  stayTypeTagText: { color: '#fff', fontSize: 11, fontWeight: '800' },
  stayRating: { flexDirection: 'row', alignItems: 'center', gap: 4, backgroundColor: 'rgba(0,0,0,0.3)', paddingHorizontal: 8, paddingVertical: 4, borderRadius: RADIUS.pill },
  stayRatingText: { color: '#fff', fontSize: 12, fontWeight: '800' },
  stayHeroBottom: { zIndex: 2 },
  stayBody: { padding: 16 },
  stayName: { fontSize: 17, fontWeight: '900', marginBottom: 5 },
  stayAddrRow: { flexDirection: 'row', alignItems: 'center', gap: 5, marginBottom: 8 },
  stayAddr: { fontSize: 12, fontWeight: '600' },
  stayDesc: { fontSize: 13, lineHeight: 19, marginBottom: 12 },
  amenRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginBottom: 14 },
  amenChip: { paddingHorizontal: 10, paddingVertical: 5, borderRadius: RADIUS.sm },
  amenText: { fontSize: 11, fontWeight: '700' },
  stayFooter: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  priceWrap: { flexDirection: 'row', alignItems: 'baseline', gap: 4 },
  price: { fontSize: 22, fontWeight: '900' },
  priceUnit: { fontSize: 12, fontWeight: '600' },
  bookBtn: { paddingHorizontal: 22, paddingVertical: 12, borderRadius: RADIUS.md },
  bookBtnText: { color: '#fff', fontSize: 14, fontWeight: '900' },
});
