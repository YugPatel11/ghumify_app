import React from 'react';
import { StyleSheet, View, ViewStyle, StyleProp } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { GRADIENTS } from '../lib/theme';

type GKey = keyof typeof GRADIENTS;

interface Props {
  gradient?: GKey;
  colors?: [string, string, string];
  style?: StyleProp<ViewStyle>;
  children?: React.ReactNode;
  start?: { x: number; y: number };
  end?: { x: number; y: number };
}

export default function GradientView({ gradient = 'indigo', colors, style, children, start, end }: Props) {
  const c = colors || GRADIENTS[gradient] || GRADIENTS.indigo;
  return (
    <LinearGradient
      colors={c as any}
      start={start || { x: 0, y: 0 }}
      end={end || { x: 1, y: 1 }}
      style={[styles.base, style]}
    >
      {children}
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  base: { overflow: 'hidden' },
});
