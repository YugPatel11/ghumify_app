import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { CITIES } from '../lib/data';
import { Category } from '../lib/types';
import { parseHours, parseStartTime, parseInterests, matchCity } from '../lib/parser';
import { RADIUS, SPACING, PALETTE } from '../lib/theme';
import GradientView from '../components/GradientView';

const EXAMPLES = [
  { location: 'Indore', description: '6 hours, famous food and local markets' },
  { location: 'Jaipur', description: '8 hours, forts, palaces and history' },
  { location: 'Paris', description: '4 hours, museums and local food' },
  { location: 'Varanasi', description: 'I have 3 hours, want to see temples and the Ganga Aarti' },
  { location: 'Goa', description: 'Half day, beaches and seafood' },
  { location: 'Bangkok', description: '5 hours, temples and street food' },
];

const LOADING_MESSAGES = [
  'Finding the best spots...',
  'Checking opening hours...',
  'Looking at the weather...',
  'Planning your route...',
  'Adding food stops...',
  'Almost ready...',
];

interface Props {
  navigation: any;
}

export default function HomeScreen({ navigation }: Props) {
  const { theme, t: tr } = useApp();
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const spinAnim = useRef(new Animated.Value(0)).current;
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const [loadMsgIndex, setLoadMsgIndex] = useState(0);

  const suggestions = CITIES.filter((c) => {
    if (!location.trim()) return false;
    return c.name.toLowerCase().includes(location.toLowerCase().trim());
  }).slice(0, 6);

  useEffect(() => {
    if (loading) {
      fadeAnim.setValue(0);
      Animated.timing(fadeAnim, { toValue: 1, duration: 300, useNativeDriver: true }).start();
      const spinLoop = Animated.loop(
        Animated.timing(spinAnim, { toValue: 1, duration: 1500, easing: Easing.linear, useNativeDriver: true }),
      );
      spinLoop.start();
      const msgTimer = setInterval(() => {
        setLoadMsgIndex((i) => (i + 1) % LOADING_MESSAGES.length);
      }, 700);
      return () => {
        spinLoop.stop();
        clearInterval(msgTimer);
      };
    }
  }, [loading]);

  const spinInterpolate = spinAnim.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] });

  const selectExample = (ex: typeof EXAMPLES[0]) => {
    setLocation(ex.location);
    setDescription(ex.description);
    setShowSuggestions(false);
    setErrorMsg('');
  };

  const handleGenerate = () => {
    if (!location.trim()) {
      setErrorMsg('Please enter a location first.');
      return;
    }
    setErrorMsg('');
    setLoading(true);

    // Parse the description
    const fullText = `${location} ${description}`;
    const hours = parseHours(fullText);
    const startTime = parseStartTime(fullText) || '09:00';
    const interests = parseInterests(fullText);

    // Simulate loading delay for the animation
    setTimeout(() => {
      setLoading(false);
      navigation.navigate('PlanResult', {
        cityName: location.trim(),
        hours,
        interests,
        startTime,
      });
    }, 2200);
  };

  if (loading) {
    return (
      <SafeAreaView style={[styles.loadingContainer, { backgroundColor: theme.bg }]} edges={['top']}>
        <Animated.View style={{ opacity: fadeAnim, alignItems: 'center', justifyContent: 'center', flex: 1 }}>
          <Animated.View style={{ transform: [{ rotate: spinInterpolate }] }}>
            <View style={[styles.loadingIconWrap, { backgroundColor: theme.accentSoft }]}>
              <Ionicons name="airplane" size={44} color={theme.accent} />
            </View>
          </Animated.View>
          <Text style={[styles.loadingTitle, { color: theme.text }]}>Crafting your plan for {location}</Text>
          <Text style={[styles.loadingMsg, { color: theme.textMuted }]}>{LOADING_MESSAGES[loadMsgIndex]}</Text>
          <View style={styles.loadingDots}>
            {[0, 1, 2].map((i) => (
              <View
                key={i}
                style={[
                  styles.loadingDot,
                  { backgroundColor: loadMsgIndex % 3 === i ? theme.accent : theme.border },
                ]}
              />
            ))}
          </View>
        </Animated.View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: theme.bg }]} edges={['top']}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={{ flex: 1 }}
        keyboardVerticalOffset={0}
      >
        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 100 }} keyboardShouldPersistTaps="handled">
          {/* Hero */}
          <GradientView gradient="cherry" style={styles.hero} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
            <View style={styles.heroInner}>
              <View style={styles.brandRow}>
                <View style={styles.logoCircle}>
                  <Ionicons name="airplane" size={24} color="#fff" />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.brandName}>Ghumify</Text>
                  <Text style={styles.brandTag}>{tr('tagline')}</Text>
                </View>
              </View>
              <Text style={styles.heroPrompt}>Tell us where you want to go and how much time you have. We will craft the perfect plan.</Text>
            </View>
          </GradientView>

          <View style={styles.body}>
            {/* Location input */}
            <View style={styles.inputSection}>
              <View style={styles.inputLabelRow}>
                <View style={[styles.inputIcon, { backgroundColor: theme.accentSoft }]}>
                  <Ionicons name="location" size={18} color={theme.accent} />
                </View>
                <Text style={[styles.inputLabel, { color: theme.text }]}>{tr('whereAreYou')}</Text>
              </View>
              <View style={[styles.inputWrap, { backgroundColor: theme.card, borderColor: showSuggestions ? theme.accent : theme.border }]}>
                <Ionicons name="navigate-outline" size={18} color={theme.textMuted} style={{ marginHorizontal: 2 }} />
                <TextInput
                  value={location}
                  onChangeText={(t) => { setLocation(t); setShowSuggestions(true); setErrorMsg(''); }}
                  onFocus={() => setShowSuggestions(true)}
                  onBlur={() => setTimeout(() => setShowSuggestions(false), 200)}
                  placeholder="e.g. Indore, Paris, Tokyo..."
                  placeholderTextColor={theme.textMuted}
                  style={[styles.input, { color: theme.text }]}
                  returnKeyType="next"
                />
                {location ? (
                  <Pressable onPress={() => { setLocation(''); setShowSuggestions(false); }}>
                    <Ionicons name="close-circle" size={18} color={theme.textMuted} />
                  </Pressable>
                ) : null}
              </View>

              {/* Autocomplete suggestions */}
              {showSuggestions && suggestions.length > 0 && (
                <View style={[styles.suggestionsWrap, { backgroundColor: theme.card, borderColor: theme.border }, { shadowColor: '#000', shadowOpacity: 0.1, shadowRadius: 12, elevation: 5 }]}>
                  {suggestions.map((c) => (
                    <Pressable
                      key={c.id}
                      onPress={() => { setLocation(c.name); setShowSuggestions(false); setErrorMsg(''); }}
                      style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}
                    >
                      <View style={styles.suggestionItem}>
                        <View style={[styles.suggestionIcon, { backgroundColor: theme.accentSoft }]}>
                          <Ionicons name="location-outline" size={16} color={theme.accent} />
                        </View>
                        <View style={{ flex: 1 }}>
                          <Text style={[styles.suggestionName, { color: theme.text }]}>{c.name}</Text>
                          <Text style={[styles.suggestionState, { color: theme.textMuted }]}>{c.state} · {c.tagline}</Text>
                        </View>
                        <Ionicons name="chevron-forward" size={14} color={theme.textMuted} />
                      </View>
                    </Pressable>
                  ))}
                </View>
              )}

              {errorMsg ? (
                <View style={[styles.errorBox, { backgroundColor: theme.accentSoft }]}>
                  <Ionicons name="alert-circle-outline" size={15} color={theme.accent} />
                  <Text style={[styles.errorText, { color: theme.accent }]}>{errorMsg}</Text>
                </View>
              ) : null}
            </View>

            {/* Description input */}
            <View style={styles.inputSection}>
              <View style={styles.inputLabelRow}>
                <View style={[styles.inputIcon, { backgroundColor: theme.brandSoft }]}>
                  <Ionicons name="create-outline" size={18} color={theme.brand} />
                </View>
                <Text style={[styles.inputLabel, { color: theme.text }]}>Describe your trip</Text>
              </View>
              <View style={[styles.descWrap, { backgroundColor: theme.card, borderColor: theme.border }]}>
                <TextInput
                  value={description}
                  onChangeText={setDescription}
                  placeholder="e.g. I have 6 hours and want to visit famous places, eat local food, and explore markets"
                  placeholderTextColor={theme.textMuted}
                  style={[styles.descInput, { color: theme.text }]}
                  multiline
                  numberOfLines={4}
                  textAlignVertical="top"
                  returnKeyType="default"
                />
              </View>
              <Text style={[styles.hintText, { color: theme.textMuted }]}>Mention your available hours, what you want to see, and any preferences. We will handle the rest.</Text>
            </View>

            {/* Examples */}
            <View style={styles.examplesSection}>
              <Text style={[styles.examplesTitle, { color: theme.text }]}>Try an example:</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingTop: 10 }}>
                {EXAMPLES.map((ex, i) => (
                  <Pressable
                    key={i}
                    onPress={() => selectExample(ex)}
                    style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1, marginRight: 10 })}
                  >
                    <View style={[styles.exampleChip, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
                      <Ionicons name="time-outline" size={13} color={theme.accent} />
                      <Text style={[styles.exampleChipText, { color: theme.text }]}>
                        {ex.location}: {ex.description.length > 35 ? ex.description.slice(0, 35) + '...' : ex.description}
                      </Text>
                    </View>
                  </Pressable>
                ))}
              </ScrollView>
            </View>

            {/* Feature highlights */}
            <View style={styles.featuresRow}>
              <FeaturePill icon="sunny-outline" label="Weather-aware" theme={theme} />
              <FeaturePill icon="time-outline" label="Time-based" theme={theme} />
              <FeaturePill icon="language" label="10 languages" theme={theme} />
            </View>
          </View>
        </ScrollView>

        {/* Generate button */}
        <View style={[styles.generateWrap, { backgroundColor: theme.bg }]}>
          <Pressable onPress={handleGenerate} style={({ pressed }) => ({ opacity: pressed ? 0.9 : 1 })}>
            <GradientView gradient="cherry" style={styles.generateBtn} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }}>
              <Ionicons name="sparkles" size={20} color="#fff" />
              <Text style={styles.generateText}>{tr('generatePlan')}</Text>
            </GradientView>
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function FeaturePill({ icon, label, theme }: any) {
  return (
    <View style={[styles.featurePill, { backgroundColor: theme.card, borderColor: theme.border }]}>
      <Ionicons name={icon} size={14} color={theme.accent} />
      <Text style={[styles.featurePillText, { color: theme.textSoft }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loadingContainer: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  loadingIconWrap: { width: 80, height: 80, borderRadius: 40, alignItems: 'center', justifyContent: 'center', marginBottom: 24 },
  loadingTitle: { fontSize: 20, fontWeight: '900', marginBottom: 8 },
  loadingMsg: { fontSize: 15, fontWeight: '600' },
  loadingDots: { flexDirection: 'row', gap: 6, marginTop: 16 },
  loadingDot: { width: 8, height: 8, borderRadius: 4 },
  hero: { paddingBottom: 28, borderBottomLeftRadius: 32, borderBottomRightRadius: 32 },
  heroInner: { paddingHorizontal: 22, paddingTop: 16 },
  brandRow: { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 14 },
  logoCircle: { width: 48, height: 48, borderRadius: 24, backgroundColor: 'rgba(255,255,255,0.22)', alignItems: 'center', justifyContent: 'center' },
  brandName: { color: '#fff', fontSize: 26, fontWeight: '900', letterSpacing: -0.5 },
  brandTag: { color: 'rgba(255,255,255,0.9)', fontSize: 13, fontWeight: '600', marginTop: 1 },
  heroPrompt: { color: 'rgba(255,255,255,0.9)', fontSize: 14.5, fontWeight: '500', lineHeight: 21 },
  body: { paddingHorizontal: 22, paddingTop: 24 },
  inputSection: { marginBottom: 22 },
  inputLabelRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 10 },
  inputIcon: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
  inputLabel: { fontSize: 16, fontWeight: '800' },
  inputWrap: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 16, height: 54, borderRadius: RADIUS.md, borderWidth: 2 },
  input: { flex: 1, fontSize: 16, fontWeight: '600' },
  suggestionsWrap: { marginTop: 8, borderRadius: RADIUS.md, borderWidth: 1.5, overflow: 'hidden' },
  suggestionItem: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 14, paddingVertical: 12, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: 'rgba(128,128,128,0.15)' },
  suggestionIcon: { width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  suggestionName: { fontSize: 15, fontWeight: '800' },
  suggestionState: { fontSize: 12, fontWeight: '600', marginTop: 2 },
  errorBox: { flexDirection: 'row', gap: 8, alignItems: 'center', paddingHorizontal: 14, paddingVertical: 10, borderRadius: RADIUS.sm, marginTop: 10 },
  errorText: { fontSize: 13, fontWeight: '700' },
  descWrap: { borderRadius: RADIUS.md, borderWidth: 2, paddingHorizontal: 16, paddingVertical: 12, minHeight: 100 },
  descInput: { fontSize: 15.5, fontWeight: '500', lineHeight: 22, minHeight: 76 },
  hintText: { fontSize: 12.5, fontWeight: '600', marginTop: 8, lineHeight: 17 },
  examplesSection: { marginBottom: 20 },
  examplesTitle: { fontSize: 14, fontWeight: '800', marginBottom: 4 },
  exampleChip: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 14, paddingVertical: 10, borderRadius: RADIUS.pill, borderWidth: 1.5 },
  exampleChipText: { fontSize: 12.5, fontWeight: '700' },
  featuresRow: { flexDirection: 'row', gap: 8, marginBottom: 20 },
  featurePill: { flexDirection: 'row', alignItems: 'center', gap: 5, paddingHorizontal: 12, paddingVertical: 8, borderRadius: RADIUS.pill, borderWidth: 1.5 },
  featurePillText: { fontSize: 11.5, fontWeight: '700' },
  generateWrap: { paddingHorizontal: 22, paddingTop: 12, paddingBottom: 16, shadowColor: '#000', shadowOpacity: 0.08, shadowRadius: 20, elevation: 8 },
  generateBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, paddingVertical: 17, borderRadius: RADIUS.md, shadowColor: PALETTE.cherryDark, shadowOpacity: 0.3, shadowRadius: 12, elevation: 6 },
  generateText: { color: '#fff', fontSize: 17, fontWeight: '900' },
});
