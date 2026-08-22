import React from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { useApp } from '../lib/AppContext';

interface Props {
  label?: string;
  size?: number;
}

export default function Loading({ label = 'Loading...', size = 40 }: Props) {
  const { theme } = useApp();
  return (
    <View style={[styles.wrap, { backgroundColor: theme.bg }]}>
      <ActivityIndicator size="large" color={theme.brand} />
      <Text style={[styles.label, { color: theme.textSoft }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12 },
  label: { fontSize: 15, fontWeight: '600' },
});
