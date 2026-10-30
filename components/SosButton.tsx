import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Modal,
  Animated,
  Vibration,
  Platform,
} from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { RADIUS, SPACING } from '../lib/theme';
import { SosClient } from '../lib/sosClient';
import SosActiveModal from './SosActiveModal';

interface Props {
  tripId?: string;
  currentStopName?: string;
  size?: 'compact' | 'normal' | 'hero';
  style?: any;
}

export default function SosButton({ tripId, currentStopName, size = 'normal', style }: Props) {
  const { theme, t: tr, isRtlMode } = useApp();
  const [holding, setHolding] = useState(false);
  const [countingDown, setCountingDown] = useState(false);
  const [countdown, setCountdown] = useState(5);
  const [activeSosId, setActiveSosId] = useState<string | null>(null);

  const holdProgress = useRef(new Animated.Value(0)).current;
  const countdownTimer = useRef<NodeJS.Timeout | null>(null);
  const holdAnimRef = useRef<Animated.CompositeAnimation | null>(null);

  // Clean up timers on unmount
  useEffect(() => {
    return () => {
      if (countdownTimer.current) clearInterval(countdownTimer.current);
    };
  }, []);

  const handlePressIn = () => {
    setHolding(true);
    holdProgress.setValue(0);
    holdAnimRef.current = Animated.timing(holdProgress, {
      toValue: 1,
      duration: 1800, // 1.8s hold to confirm
      useNativeDriver: false,
    });

    holdAnimRef.current.start(({ finished }) => {
      if (finished) {
        triggerCountdown();
      }
    });
  };

  const handlePressOut = () => {
    if (!countingDown) {
      if (holdAnimRef.current) holdAnimRef.current.stop();
      holdProgress.setValue(0);
      setHolding(false);
    }
  };

  const triggerCountdown = () => {
    setHolding(false);
    setCountingDown(true);
    setCountdown(5);
    try {
      Vibration.vibrate([0, 200, 100, 200]);
    } catch {}

    let currentSec = 5;
    countdownTimer.current = setInterval(() => {
      currentSec -= 1;
      setCountdown(currentSec);

      if (currentSec <= 0) {
        if (countdownTimer.current) clearInterval(countdownTimer.current);
        setCountingDown(false);
        dispatchSos();
      }
    }, 1000);
  };

  const cancelCountdown = () => {
    if (countdownTimer.current) clearInterval(countdownTimer.current);
    setCountingDown(false);
    setCountdown(5);
    try {
      Vibration.vibrate(100);
    } catch {}
  };

  const dispatchSos = async () => {
    const sosId = SosClient.generateUuid();
    setActiveSosId(sosId);

    // 1. Fetch current GPS or fallback location
    const loc = await SosClient.getCurrentLocation();

    // 2. Dispatch to server (or offline queue)
    await SosClient.triggerSos({
      sosId,
      lat: loc.lat,
      lng: loc.lng,
      accuracyM: loc.accuracyM,
      locationSource: loc.source,
      tripId,
      triggerSource: 'app_button',
    });

    // 3. Start live location tracking
    SosClient.startLiveLocationUpdates(sosId, 3);
  };

  const progressWidth = holdProgress.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <>
      <Pressable
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        accessibilityRole="button"
        accessibilityLabel="Emergency SOS button. Press and hold to activate."
        accessibilityHint="Activates emergency alert to contacts and shows nearest hospitals."
        style={({ pressed }) => [
          styles.sosBtn,
          size === 'compact' && styles.btnCompact,
          size === 'hero' && styles.btnHero,
          { backgroundColor: '#dc2626' },
          pressed && { opacity: 0.9, transform: [{ scale: 0.97 }] },
          style,
        ]}
      >
        {/* Fill progress layer on hold */}
        {holding && (
          <Animated.View style={[styles.progressFill, { width: progressWidth }]} />
        )}

        <View style={styles.btnContent}>
          <Ionicons name="warning" size={size === 'compact' ? 14 : 18} color="#fff" />
          <Text style={[styles.btnText, size === 'compact' && { fontSize: 12 }]}>
            {holding ? 'KEEP HOLDING...' : 'SOS'}
          </Text>
        </View>
      </Pressable>

      {/* Countdown Modal */}
      <Modal visible={countingDown} transparent animationType="fade">
        <View style={styles.countdownOverlay}>
          <View style={[styles.countdownCard, { backgroundColor: theme.card }]}>
            <View style={styles.countdownBadge}>
              <Ionicons name="warning" size={32} color="#dc2626" />
            </View>

            <Text style={[styles.countdownTitle, { color: theme.text }]}>
              Sending Emergency SOS
            </Text>
            <Text style={[styles.countdownSub, { color: theme.textMuted }]}>
              Alerting your emergency contacts with your live location and finding nearest hospitals in:
            </Text>

            <View style={styles.digitCircle}>
              <Text style={styles.digitText}>{countdown}</Text>
            </View>

            <Pressable
              onPress={cancelCountdown}
              style={[styles.cancelBtn, { backgroundColor: theme.accentSoft, borderColor: theme.border }]}
              accessibilityLabel="Cancel SOS alert"
            >
              <Ionicons name="close" size={20} color={theme.text} />
              <Text style={[styles.cancelBtnText, { color: theme.text }]}>
                CANCEL
              </Text>
            </Pressable>
          </View>
        </View>
      </Modal>

      {/* Active Emergency Dashboard Modal */}
      {activeSosId && (
        <SosActiveModal
          visible={Boolean(activeSosId)}
          sosId={activeSosId}
          onClose={() => setActiveSosId(null)}
        />
      )}
    </>
  );
}

const styles = StyleSheet.create({
  sosBtn: {
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: RADIUS.pill,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    shadowColor: '#dc2626',
    shadowOpacity: 0.4,
    shadowRadius: 6,
    elevation: 4,
    minHeight: 40,
    minWidth: 70,
  },
  btnCompact: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    minHeight: 32,
    minWidth: 60,
  },
  btnHero: {
    paddingHorizontal: 22,
    paddingVertical: 14,
    minHeight: 52,
    minWidth: 100,
  },
  progressFill: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.35)',
  },
  btnContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  btnText: {
    color: '#fff',
    fontWeight: '900',
    fontSize: 14,
    letterSpacing: 0.5,
  },
  countdownOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.8)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  countdownCard: {
    width: '100%',
    maxWidth: 360,
    borderRadius: RADIUS.xl,
    padding: 28,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.3,
    shadowRadius: 20,
    elevation: 10,
  },
  countdownBadge: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: 'rgba(220, 38, 38, 0.15)',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  countdownTitle: {
    fontSize: 20,
    fontWeight: '800',
    textAlign: 'center',
  },
  countdownSub: {
    fontSize: 13,
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 18,
  },
  digitCircle: {
    width: 90,
    height: 90,
    borderRadius: 45,
    backgroundColor: '#dc2626',
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: 24,
    shadowColor: '#dc2626',
    shadowOpacity: 0.5,
    shadowRadius: 15,
    elevation: 8,
  },
  digitText: {
    color: '#fff',
    fontSize: 48,
    fontWeight: '900',
  },
  cancelBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 14,
    paddingHorizontal: 28,
    borderRadius: RADIUS.lg,
    borderWidth: 1,
    width: '100%',
    justifyContent: 'center',
  },
  cancelBtnText: {
    fontSize: 16,
    fontWeight: '800',
    letterSpacing: 1,
  },
});
