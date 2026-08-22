import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useApp } from '../lib/AppContext';

interface Props {
  title: string;
  subtitle?: string;
  right?: React.ReactNode;
}

export default function SectionHeader({ title, subtitle, right }: Props) {
  const { theme } = useApp();
  return (
    <View style={styles.wrap}>
      <View style={{ flex: 1 }}>
        <Text style={[styles.title, { color: theme.text }]}>{title}</Text>
        {subtitle ? <Text style={[styles.subtitle, { color: theme.textMuted }]}>{subtitle}</Text> : null}
      </View>
      {right}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 },
  title: { fontSize: 18, fontWeight: '800' },
  subtitle: { fontSize: 13, marginTop: 2, fontWeight: '500' },
});
