import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { RADIUS } from '../lib/theme';
import { t } from '../lib/i18n';

interface Props {
  labelKey: string;
  icon: string;
  selected: boolean;
  onPress: () => void;
  color?: string;
}

export default function Chip({ labelKey, icon, selected, onPress, color }: Props) {
  const { theme } = useApp();
  return (
    <Pressable onPress={onPress} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
      <View
        style={[
          styles.chip,
          {
            backgroundColor: selected ? (color || theme.brand) : theme.card,
            borderColor: selected ? (color || theme.brand) : theme.border,
          },
        ]}
      >
        <Ionicons name={icon as any} size={16} color={selected ? '#fff' : (color || theme.brand)} />
        <Text style={[styles.text, { color: selected ? '#fff' : theme.text }]} numberOfLines={1}>
          {t(labelKey)}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: RADIUS.pill,
    borderWidth: 1.5,
    marginRight: 8,
  },
  text: { fontSize: 13.5, fontWeight: '700' },
});
