import React, { useState, useEffect, useRef } from 'react';
import {
  AccessibilityInfo,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { RADIUS, SPACING } from '../lib/theme';
import { useSpeechToText } from '../lib/useSpeechToText';
import MicButton from './MicButton';

const DRAFT_STORAGE_KEY = '@ghumify_itinerary_remarks_draft';
const MAX_CHARS = 4000;

interface Props {
  value: string;
  onChangeText: (text: string) => void;
  style?: any;
}

const QUICK_CHIPS = [
  { key: 'kids', label: 'Travelling with kids', query: 'Travelling with kids' },
  { key: 'veg', label: 'Vegetarian food', query: 'Vegetarian food only' },
  { key: 'relaxed', label: 'Relaxed pace', query: 'Relaxed pace with slow mornings' },
  { key: 'budget', label: 'Budget trip', query: 'Budget trip, affordable options' },
  { key: 'wheelchair', label: 'Wheelchair accessible', query: 'Wheelchair accessible locations' },
  { key: 'late_start', label: 'Avoid early mornings', query: 'Avoid early mornings, start after 10 AM' },
];

const ROTATING_EXAMPLES = [
  'E.g., Travelling with 2 kids, prefer relaxed mornings, pure veg food only...',
  'E.g., We have a weekend, want to see heritage forts and try authentic street food...',
  'E.g., Need wheelchair accessible monuments, slow walking pace, avoid steep climbs...',
  'E.g., Budget trip, love photography, must visit famous local markets and cafes...',
];

export default function ItineraryRemarksBox({ value, onChangeText, style }: Props) {
  const { theme, lang, t: tr, isRtlMode } = useApp();
  const [placeholderIndex, setPlaceholderIndex] = useState(0);
  const [selectedChips, setSelectedChips] = useState<Set<string>>(new Set());

  // Speech-to-Text hook
  const speech = useSpeechToText({
    language: lang,
    onFinalResult: (speechText) => {
      if (speechText.trim()) {
        const separator = value.trim().length > 0 ? ' ' : '';
        const updated = (value + separator + speechText.trim()).slice(0, MAX_CHARS);
        onChangeText(updated);
        persistDraft(updated);
      }
    },
  });

  // Rotate placeholder examples periodically
  useEffect(() => {
    const timer = setInterval(() => {
      setPlaceholderIndex((prev) => (prev + 1) % ROTATING_EXAMPLES.length);
    }, 4500);
    return () => clearInterval(timer);
  }, []);

  // Restore draft on mount
  useEffect(() => {
    AsyncStorage.getItem(DRAFT_STORAGE_KEY)
      .then((saved) => {
        if (saved && !value) {
          onChangeText(saved);
        }
      })
      .catch(() => {});
  }, []);

  const persistDraft = (text: string) => {
    AsyncStorage.setItem(DRAFT_STORAGE_KEY, text).catch(() => {});
  };

  const handleTextChange = (text: string) => {
    const bounded = text.slice(0, MAX_CHARS);
    onChangeText(bounded);
    persistDraft(bounded);
  };

  const handleChipPress = (chip: typeof QUICK_CHIPS[0]) => {
    const isSelected = selectedChips.has(chip.key);
    const nextSet = new Set(selectedChips);

    if (isSelected) {
      nextSet.delete(chip.key);
      // Remove chip text if present
      let updated = value.replace(chip.query, '').replace(/,\s*,/g, ',').trim();
      if (updated.endsWith(',')) updated = updated.slice(0, -1).trim();
      onChangeText(updated);
      persistDraft(updated);
    } else {
      nextSet.add(chip.key);
      const separator = value.trim().length > 0 ? (value.trim().endsWith('.') ? ' ' : ', ') : '';
      const updated = (value + separator + chip.query).slice(0, MAX_CHARS);
      onChangeText(updated);
      persistDraft(updated);
    }

    setSelectedChips(nextSet);
    AccessibilityInfo.announceForAccessibility?.(`Toggled ${chip.label}`);
  };

  const charCount = value.length;

  return (
    <View style={[styles.container, style]}>
      {/* Header Row */}
      <View style={[styles.headerRow, isRtlMode && styles.rtlRow]}>
        <View style={styles.titleWrap}>
          <Ionicons name="chatbox-ellipses-outline" size={18} color={theme.brand} />
          <Text style={[styles.title, { color: theme.text }, isRtlMode && styles.rtlText]}>
            {tr('home.remarksTitle') || 'Remarks'}
          </Text>
          <View style={[styles.optionalBadge, { backgroundColor: theme.cardAlt }]}>
            <Text style={[styles.optionalBadgeText, { color: theme.textMuted }]}>
              {tr('home.optional') || '(optional)'}
            </Text>
          </View>
        </View>

        {/* Character Counter */}
        <Text style={[styles.charCounter, { color: charCount > 3800 ? '#ef4444' : theme.textMuted }]}>
          {charCount} / {MAX_CHARS}
        </Text>
      </View>

      {/* Helper Explanation */}
      <Text style={[styles.helperText, { color: theme.textMuted }, isRtlMode && styles.rtlText]}>
        {tr('home.remarksHelper') ||
          'Tell us more about your trip. Any special requirements or places will be merged into your plan.'}
      </Text>

      {/* Quick Add Chips */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={[styles.chipsContainer, isRtlMode && styles.rtlRow]}
      >
        {QUICK_CHIPS.map((chip) => {
          const active = selectedChips.has(chip.key) || value.toLowerCase().includes(chip.key);
          return (
            <Pressable
              key={chip.key}
              onPress={() => handleChipPress(chip)}
              style={({ pressed }) => [{ opacity: pressed ? 0.75 : 1 }]}
              accessibilityRole="button"
              accessibilityLabel={`${chip.label}, ${active ? 'selected' : 'not selected'}`}
            >
              <View
                style={[
                  styles.chip,
                  {
                    backgroundColor: active ? theme.brandSoft : theme.card,
                    borderColor: active ? theme.brand : theme.border,
                  },
                ]}
              >
                <Ionicons
                  name={active ? 'checkmark-circle' : 'add-circle-outline'}
                  size={14}
                  color={active ? theme.brand : theme.textMuted}
                />
                <Text style={[styles.chipText, { color: active ? theme.brand : theme.textSoft }]}>
                  {tr(`chips.${chip.key}`) || chip.label}
                </Text>
              </View>
            </Pressable>
          );
        })}
      </ScrollView>

      {/* Multiline Text Input with Mic */}
      <View
        style={[
          styles.inputWrapper,
          {
            backgroundColor: theme.card,
            borderColor: speech.isListening ? '#ef4444' : theme.border,
          },
        ]}
      >
        <TextInput
          value={value}
          onChangeText={handleTextChange}
          placeholder={speech.isListening ? `Listening in ${lang.toUpperCase()}...` : ROTATING_EXAMPLES[placeholderIndex]}
          placeholderTextColor={theme.textMuted}
          style={[styles.textInput, { color: theme.text }, isRtlMode && styles.rtlText]}
          multiline
          maxLength={MAX_CHARS}
          textAlignVertical="top"
          accessibilityLabel="Remarks and additional travel details, optional"
          accessibilityHint="Type your notes or tap microphone to speak"
        />

        {/* Action Row Inside Box: Mic & Status */}
        <View style={[styles.innerActionRow, isRtlMode && styles.rtlRow]}>
          {speech.isListening ? (
            <View style={styles.listeningBadge}>
              <View style={styles.recordingDot} />
              <Text style={styles.listeningText}>
                {tr('speech.listening') || 'Listening...'} ({lang.toUpperCase()})
              </Text>
            </View>
          ) : (
            <Text style={[styles.speechHint, { color: theme.textMuted }]}>
              {value.length === 0 ? 'Tap mic to speak' : ''}
            </Text>
          )}

          <View style={{ flex: 1 }} />

          <MicButton
            state={speech.state}
            onPress={() => {
              if (speech.isListening) speech.stopListening();
              else speech.startListening();
            }}
            onCancel={speech.cancelListening}
            size={34}
            accessibilityLabel="Dictate remarks"
          />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: SPACING.md,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 6,
  },
  titleWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  title: {
    fontSize: 15,
    fontWeight: '800',
  },
  optionalBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: RADIUS.pill,
  },
  optionalBadgeText: {
    fontSize: 11,
    fontWeight: '600',
  },
  charCounter: {
    fontSize: 11,
    fontWeight: '700',
  },
  helperText: {
    fontSize: 12.5,
    lineHeight: 17,
    marginBottom: 10,
  },
  chipsContainer: {
    flexDirection: 'row',
    gap: 8,
    paddingBottom: 10,
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 11,
    paddingVertical: 7,
    borderRadius: RADIUS.pill,
    borderWidth: 1.2,
  },
  chipText: {
    fontSize: 12,
    fontWeight: '700',
  },
  inputWrapper: {
    borderRadius: RADIUS.md,
    borderWidth: 1.5,
    padding: 12,
    minHeight: 125,
  },
  textInput: {
    fontSize: 14.5,
    lineHeight: 21,
    minHeight: 70,
  },
  innerActionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 6,
    paddingTop: 4,
  },
  listeningBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#ef444415',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: RADIUS.sm,
  },
  recordingDot: {
    width: 7,
    height: 7,
    borderRadius: 4,
    backgroundColor: '#ef4444',
  },
  listeningText: {
    fontSize: 11.5,
    fontWeight: '700',
    color: '#ef4444',
  },
  speechHint: {
    fontSize: 11,
    fontWeight: '600',
  },
  rtlRow: {
    flexDirection: 'row-reverse',
  },
  rtlText: {
    textAlign: 'right',
  },
});
