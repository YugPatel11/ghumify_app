import React, { useMemo, useState } from 'react';
import { FlatList, Pressable, RefreshControl, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { CITIES } from '../lib/data';
import { getOrCreateCity, getAllPlacesByCity, findCityById } from '../lib/parser';
import { CATEGORIES } from '../lib/categories';
import { Category, Place } from '../lib/types';
import { RADIUS } from '../lib/theme';
import PlaceCard from '../components/PlaceCard';
import { t } from '../lib/i18n';

interface Props {
  navigation: any;
}

export default function ExploreScreen({ navigation }: Props) {
  const { theme, t: tr } = useApp();
  const [cityId, setCityId] = useState('indore');
  const [cityName, setCityName] = useState('');
  const [category, setCategory] = useState<Category | 'all'>('all');
  const [query, setQuery] = useState('');
  const [refreshing, setRefreshing] = useState(false);
  const [searchInput, setSearchInput] = useState('');

  const city = findCityById(cityId, CITIES)!;
  const allPlaces = useMemo(() => getAllPlacesByCity(cityId), [cityId]);
  const isKnownCity = CITIES.some((c) => c.id === cityId);

  const filtered = useMemo(() => {
    let list = allPlaces;
    if (category !== 'all') list = list.filter((p) => p.category === category);
    if (query.trim()) {
      const q = query.toLowerCase();
      list = list.filter((p) => p.name.toLowerCase().includes(q) || p.shortDesc.toLowerCase().includes(q) || p.tags.some((tg) => tg.toLowerCase().includes(q)));
    }
    return list;
  }, [allPlaces, category, query]);

  const onRefresh = () => {
    setRefreshing(true);
    setTimeout(() => setRefreshing(false), 800);
  };

  const openPlace = (place: Place) => navigation.navigate('PlaceDetail', { placeId: place.id });

  const handleCitySearch = () => {
    if (!searchInput.trim()) return;
    const result = getOrCreateCity(searchInput.trim(), CITIES);
    setCityId(result.city.id);
    setCityName(result.city.name);
    setSearchInput('');
    setCategory('all');
    setQuery('');
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: theme.bg }} edges={['top']}>
      <View style={styles.container}>
        {/* Header */}
        <View style={styles.headerRow}>
          <View>
            <Text style={[styles.screenTitle, { color: theme.text }]}>{tr('explore')}</Text>
            <Text style={[styles.screenSub, { color: theme.textMuted }]}>{city.name}{isKnownCity ? `, ${city.state}` : ''}</Text>
          </View>
          <Pressable onPress={() => navigation.navigate('Settings')} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
            <View style={[styles.settingsBtn, { backgroundColor: theme.card, borderColor: theme.border }]}>
              <Ionicons name="language" size={20} color={theme.brand} />
            </View>
          </Pressable>
        </View>

        {/* City search - type any city worldwide */}
        <View style={{ paddingHorizontal: 20, marginBottom: 14 }}>
          <View style={[styles.citySearchBox, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <Ionicons name="search" size={18} color={theme.accent} />
            <TextInput
              value={searchInput}
              onChangeText={setSearchInput}
              placeholder="Search any city worldwide..."
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
              <Pressable key={c.id} onPress={() => { setCityId(c.id); setCityName(''); setCategory('all'); setQuery(''); }} style={{ marginRight: 8 }}>
                <View style={[styles.cityPill, { backgroundColor: active ? theme.brand : theme.card, borderColor: active ? theme.brand : theme.border }]}>
                  <Text style={[styles.cityPillText, { color: active ? '#fff' : theme.text }]}>{c.name}</Text>
                </View>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* Search within places */}
        <View style={{ paddingHorizontal: 20, marginBottom: 14 }}>
          <View style={[styles.searchBox, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <Ionicons name="search" size={18} color={theme.textMuted} />
            <TextInput
              value={query}
              onChangeText={setQuery}
              placeholder={tr('searchPlaces')}
              placeholderTextColor={theme.textMuted}
              style={[styles.searchInput, { color: theme.text }]}
              returnKeyType="search"
            />
            {query ? (
              <Pressable onPress={() => setQuery('')}>
                <Ionicons name="close-circle" size={18} color={theme.textMuted} />
              </Pressable>
            ) : null}
          </View>
        </View>

        {/* Category filter */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 16 }}>
          <CatChip label={tr('all')} icon="apps" active={category === 'all'} color={theme.brand} theme={theme} onPress={() => setCategory('all')} />
          {CATEGORIES.map((c) => (
            <CatChip key={c.key} label={t(c.labelKey)} icon={c.icon} active={category === c.key} color={theme.brand} theme={theme} onPress={() => setCategory(c.key)} />
          ))}
        </ScrollView>

        {/* List */}
        <FlatList
          data={filtered}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => <PlaceCard place={item} onPress={openPlace} />}
          contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 30 }}
          showsVerticalScrollIndicator={false}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[theme.brand]} tintColor={theme.brand} />}
          ListEmptyComponent={
            <View style={styles.empty}>
              <Ionicons name="compass-outline" size={48} color={theme.textMuted} />
              <Text style={[styles.emptyText, { color: theme.textSoft }]}>No places found. Try a different category or search another city.</Text>
            </View>
          }
        />
      </View>
    </SafeAreaView>
  );
}

function CatChip({ label, icon, active, color, theme, onPress }: any) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
      <View style={[styles.catChip, { backgroundColor: active ? color : theme.card, borderColor: active ? color : theme.border, marginRight: 8 }]}>
        <Ionicons name={icon as any} size={15} color={active ? '#fff' : color} />
        <Text style={[styles.catChipText, { color: active ? '#fff' : theme.text }]}>{label}</Text>
      </View>
    </Pressable>
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
  searchBox: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 14, paddingVertical: 4, borderRadius: RADIUS.md, borderWidth: 1.5, height: 48 },
  searchInput: { flex: 1, fontSize: 15, fontWeight: '500' },
  catChip: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 14, paddingVertical: 9, borderRadius: RADIUS.pill, borderWidth: 1.5 },
  catChipText: { fontSize: 13, fontWeight: '700' },
  empty: { alignItems: 'center', justifyContent: 'center', paddingTop: 60, gap: 12 },
  emptyText: { fontSize: 14, fontWeight: '600', textAlign: 'center', paddingHorizontal: 40 },
});
