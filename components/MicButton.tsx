import React, { useEffect, useRef } from 'react';
import {
  Animated,
  Easing,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import { SpeechState } from '../lib/useSpeechToText';
import { useApp } from '../lib/AppContext';

interface MicButtonProps {
  state: SpeechState;
  onPress: () => void;
  onCancel?: () => void;
  size?: number;
  accessibilityLabel?: string;
  disabled?: boolean;
}

export default function MicButton({
  state,
  onPress,
  onCancel,
  size = 40,
  accessibilityLabel = 'Voice Input',
  disabled = false,
}: MicButtonProps) {
  const { theme } = useApp();
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const spinAnim = useRef(new Animated.Value(0)).current;

  // Keyboard shortcut listener (Ctrl+Shift+M on web)
  useEffect(() => {
    if (Platform.OS === 'web' && typeof window !== 'undefined') {
      const handleKeyDown = (e: KeyboardEvent) => {
        if (e.ctrlKey && e.shiftKey && (e.key === 'M' || e.key === 'm')) {
          e.preventDefault();
          onPress();
        } else if (e.key === 'Escape' && state === 'listening') {
          onCancel?.();
        }
      };
      window.addEventListener('keydown', handleKeyDown);
      return () => window.removeEventListener('keydown', handleKeyDown);
    }
  }, [onPress, onCancel, state]);

  // Pulse animation when listening
  useEffect(() => {
    if (state === 'listening') {
      const pulseLoop = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.25,
            duration: 600,
            easing: Easing.inOut(Easing.ease),
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 600,
            easing: Easing.inOut(Easing.ease),
            useNativeDriver: true,
          }),
        ])
      );
      pulseLoop.start();
      return () => pulseLoop.stop();
    } else {
      pulseAnim.setValue(1);
    }
  }, [state, pulseAnim]);

  // Spin animation when processing
  useEffect(() => {
    if (state === 'processing') {
      const spinLoop = Animated.loop(
        Animated.timing(spinAnim, {
          toValue: 1,
          duration: 1000,
          easing: Easing.linear,
          useNativeDriver: true,
        })
      );
      spinLoop.start();
      return () => spinLoop.stop();
    } else {
      spinAnim.setValue(0);
    }
  }, [state, spinAnim]);

  const spin = spinAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  const isListening = state === 'listening';
  const isProcessing = state === 'processing';
  const isError = state === 'error';
  const isUnsupported = state === 'unsupported' || disabled;

  let btnColor = theme.brand;
  let iconName: any = 'mic';

  if (isListening) {
    btnColor = '#ef4444'; // Red recording indicator
    iconName = 'mic';
  } else if (isProcessing) {
    btnColor = '#3b82f6'; // Blue processing
    iconName = 'sync-outline';
  } else if (isError) {
    btnColor = '#f59e0b'; // Amber warning
    iconName = 'mic-off';
  } else if (isUnsupported) {
    btnColor = theme.border;
    iconName = 'mic-off';
  }

  return (
    <Pressable
      onPress={onPress}
      disabled={isUnsupported}
      accessibilityRole="button"
      accessibilityLabel={`${accessibilityLabel} (${state})`}
      accessibilityState={{
        busy: isProcessing,
        disabled: isUnsupported,
        selected: isListening,
      }}
      style={({ pressed }) => [
        styles.btnWrap,
        { width: size, height: size, borderRadius: size / 2 },
        pressed && { opacity: 0.8 },
      ]}
    >
      {/* Outer pulsing ring while recording */}
      {isListening && (
        <Animated.View
          style={[
            styles.pulseRing,
            {
              width: size * 1.5,
              height: size * 1.5,
              borderRadius: (size * 1.5) / 2,
              borderColor: '#ef4444',
              transform: [{ scale: pulseAnim }],
            },
          ]}
        />
      )}

      {/* Button Body */}
      <View
        style={[
          styles.innerBtn,
          {
            width: size,
            height: size,
            borderRadius: size / 2,
            backgroundColor: isListening ? '#ef4444' : theme.cardAlt,
            borderColor: isListening ? '#ef4444' : theme.border,
          },
        ]}
      >
        {isProcessing ? (
          <Animated.View style={{ transform: [{ rotate: spin }] }}>
            <Ionicons name="sync" size={size * 0.48} color={btnColor} />
          </Animated.View>
        ) : (
          <Ionicons
            name={iconName}
            size={size * 0.52}
            color={isListening ? '#ffffff' : isUnsupported ? theme.textMuted : theme.brand}
          />
        )}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  btnWrap: {
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
  },
  pulseRing: {
    position: 'absolute',
    borderWidth: 2,
    opacity: 0.45,
  },
  innerBtn: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
  },
});
