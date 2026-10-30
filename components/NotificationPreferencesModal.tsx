import React, { useState, useEffect } from 'react';
import {
  Modal,
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  Switch,
  ActivityIndicator,
  Platform,
  TextInput,
} from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { RADIUS, SPACING, shadow } from '../lib/theme';
import { NotificationClient } from '../lib/notifications';

interface Props {
  visible: boolean;
  onClose: () => void;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export default function NotificationPreferencesModal({ visible, onClose }: Props) {
  const { theme, t: tr, isRtlMode } = useApp();
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [testSending, setTestSending] = useState(false);
  const [testResult, setTestResult] = useState<string | null>(null);

  // Preferences state
  const [pushEnabled, setPushEnabled] = useState(true);
  const [headsUpEnabled, setHeadsUpEnabled] = useState(true);
  const [headsUpMinutes, setHeadsUpMinutes] = useState(15);
  const [leaveNowEnabled, setLeaveNowEnabled] = useState(true);
  const [goToNextEnabled, setGoToNextEnabled] = useState(true);
  const [safetyBufferMinutes, setSafetyBufferMinutes] = useState(10);
  const [transportMode, setTransportMode] = useState('driving');
  const [quietHoursEnabled, setQuietHoursEnabled] = useState(false);
  const [smartModeEnabled, setSmartModeEnabled] = useState(false);

  useEffect(() => {
    if (visible) {
      loadPreferences();
    }
  }, [visible]);

  const loadPreferences = async () => {
    setLoading(true);
    setTestResult(null);
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/me/notification-preferences?userId=user_demo`);
      if (res.ok) {
        const data = await res.json();
        const p = data.preferences;
        if (p) {
          setPushEnabled(p.pushEnabled);
          setHeadsUpEnabled(p.headsUpEnabled);
          setHeadsUpMinutes(p.headsUpLeadMinutes || 15);
          setLeaveNowEnabled(p.leaveNowEnabled);
          setGoToNextEnabled(p.goToNextEnabled);
          setSafetyBufferMinutes(p.safetyBufferMinutes || 10);
          setTransportMode(p.defaultTransportMode || 'driving');
          setQuietHoursEnabled(p.quietHoursEnabled);
          setSmartModeEnabled(p.locationSmartModeEnabled);
        }
      }
    } catch (e) {
      console.warn('Failed to load notification preferences:', e);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await fetch(`${BACKEND_URL}/api/v1/me/notification-preferences`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: 'user_demo',
          pushEnabled,
          headsUpEnabled,
          headsUpLeadMinutes: headsUpMinutes,
          leaveNowEnabled,
          goToNextEnabled,
          safetyBufferMinutes,
          defaultTransportMode: transportMode,
          quietHoursEnabled,
          locationSmartModeEnabled: smartModeEnabled,
        }),
      });
      onClose();
    } catch (e) {
      console.warn('Failed to save preferences:', e);
    } finally {
      setSaving(false);
    }
  };

  const handleSendTest = async () => {
    setTestSending(true);
    setTestResult(null);
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/notifications/admin/test-alert`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: 'user_demo', place: 'Amber Fort' }),
      });
      if (res.ok) {
        setTestResult(tr('testNotifSent') || 'Test notification sent!');
      } else {
        setTestResult('Test notification queued (check server logs).');
      }
    } catch {
      setTestResult('Server unreachable on local network.');
    } finally {
      setTestSending(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={[styles.modalCard, { backgroundColor: theme.card }]}>
          {/* Header */}
          <View style={[styles.headerRow, isRtlMode && styles.rtlRow]}>
            <View style={styles.titleWrap}>
              <Ionicons name="notifications" size={20} color={theme.brand} />
              <Text style={[styles.modalTitle, { color: theme.text }]}>
                {tr('notificationSettings') || 'Notification Settings'}
              </Text>
            </View>
            <Pressable onPress={onClose} style={styles.closeBtn}>
              <Ionicons name="close" size={22} color={theme.textMuted} />
            </Pressable>
          </View>

          {loading ? (
            <View style={styles.loadingWrap}>
              <ActivityIndicator size="large" color={theme.brand} />
            </View>
          ) : (
            <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 20 }}>
              {/* Push Enabled Toggle */}
              <View style={[styles.prefRow, { borderBottomColor: theme.border }]}>
                <View style={styles.prefTextCol}>
                  <Text style={[styles.prefLabel, { color: theme.text }]}>
                    {tr('enablePushAlerts') || 'Enable Push Notifications'}
                  </Text>
                  <Text style={[styles.prefSub, { color: theme.textMuted }]}>
                    Receive timely departure and transition alerts
                  </Text>
                </View>
                <Switch
                  value={pushEnabled}
                  onValueChange={setPushEnabled}
                  trackColor={{ false: theme.border, true: theme.brand }}
                />
              </View>

              {/* Heads-up Lead Time */}
              <View style={[styles.prefSection, { borderBottomColor: theme.border }]}>
                <View style={styles.rowBetween}>
                  <Text style={[styles.prefLabel, { color: theme.text }]}>
                    Heads-Up Alert (Before Leave Time)
                  </Text>
                  <Switch
                    value={headsUpEnabled}
                    onValueChange={setHeadsUpEnabled}
                    trackColor={{ false: theme.border, true: theme.brand }}
                  />
                </View>
                <View style={styles.pillsRow}>
                  {[5, 10, 15, 30].map((m) => (
                    <Pressable
                      key={m}
                      onPress={() => setHeadsUpMinutes(m)}
                      style={[
                        styles.pill,
                        { borderColor: theme.border },
                        headsUpMinutes === m && { backgroundColor: theme.brand, borderColor: theme.brand },
                      ]}
                    >
                      <Text
                        style={[
                          styles.pillText,
                          { color: theme.text },
                          headsUpMinutes === m && { color: '#fff', fontWeight: 'bold' },
                        ]}
                      >
                        {m} min
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </View>

              {/* Safety Buffer */}
              <View style={[styles.prefSection, { borderBottomColor: theme.border }]}>
                <Text style={[styles.prefLabel, { color: theme.text }]}>
                  Safety Travel Buffer
                </Text>
                <Text style={[styles.prefSub, { color: theme.textMuted }]}>
                  Extra cushion added before next stop arrival time
                </Text>
                <View style={styles.pillsRow}>
                  {[5, 10, 15, 20].map((b) => (
                    <Pressable
                      key={b}
                      onPress={() => setSafetyBufferMinutes(b)}
                      style={[
                        styles.pill,
                        { borderColor: theme.border },
                        safetyBufferMinutes === b && { backgroundColor: theme.accent, borderColor: theme.accent },
                      ]}
                    >
                      <Text
                        style={[
                          styles.pillText,
                          { color: theme.text },
                          safetyBufferMinutes === b && { color: '#fff', fontWeight: 'bold' },
                        ]}
                      >
                        {b} min
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </View>

              {/* Transport Mode */}
              <View style={[styles.prefSection, { borderBottomColor: theme.border }]}>
                <Text style={[styles.prefLabel, { color: theme.text }]}>
                  Default Transport Mode
                </Text>
                <View style={styles.pillsRow}>
                  {[
                    { id: 'driving', label: 'Car/Drive', icon: 'car-sport' },
                    { id: 'walk', label: 'Walk', icon: 'walk' },
                    { id: 'transit', label: 'Transit', icon: 'train' },
                    { id: 'bike', label: 'Bike', icon: 'bicycle' },
                  ].map((mode) => (
                    <Pressable
                      key={mode.id}
                      onPress={() => setTransportMode(mode.id)}
                      style={[
                        styles.pill,
                        { borderColor: theme.border },
                        transportMode === mode.id && { backgroundColor: theme.brand, borderColor: theme.brand },
                      ]}
                    >
                      <Ionicons
                        name={mode.icon as any}
                        size={14}
                        color={transportMode === mode.id ? '#fff' : theme.text}
                        style={{ marginRight: 4 }}
                      />
                      <Text
                        style={[
                          styles.pillText,
                          { color: theme.text },
                          transportMode === mode.id && { color: '#fff', fontWeight: 'bold' },
                        ]}
                      >
                        {mode.label}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </View>

              {/* Smart Mode (Layer 3) */}
              <View style={[styles.prefRow, { borderBottomColor: theme.border }]}>
                <View style={styles.prefTextCol}>
                  <Text style={[styles.prefLabel, { color: theme.text }]}>
                    Smart Mode (Geofence Detection)
                  </Text>
                  <Text style={[styles.prefSub, { color: theme.textMuted }]}>
                    Auto-confirm arrival and silence leave alerts when already departed
                  </Text>
                </View>
                <Switch
                  value={smartModeEnabled}
                  onValueChange={setSmartModeEnabled}
                  trackColor={{ false: theme.border, true: theme.teal }}
                />
              </View>

              {/* Quiet Hours */}
              <View style={[styles.prefRow, { borderBottomColor: theme.border }]}>
                <View style={styles.prefTextCol}>
                  <Text style={[styles.prefLabel, { color: theme.text }]}>
                    Quiet Hours (22:00 - 07:00)
                  </Text>
                  <Text style={[styles.prefSub, { color: theme.textMuted }]}>
                    Mute alerts outside daytime travel hours
                  </Text>
                </View>
                <Switch
                  value={quietHoursEnabled}
                  onValueChange={setQuietHoursEnabled}
                  trackColor={{ false: theme.border, true: theme.brand }}
                />
              </View>

              {/* Test Notification Button */}
              <View style={styles.testWrap}>
                <Pressable
                  onPress={handleSendTest}
                  disabled={testSending}
                  style={[styles.testBtn, { backgroundColor: theme.accentSoft, borderColor: theme.accent }]}
                >
                  {testSending ? (
                    <ActivityIndicator size="small" color={theme.accent} />
                  ) : (
                    <>
                      <Ionicons name="paper-plane" size={16} color={theme.accent} style={{ marginRight: 6 }} />
                      <Text style={[styles.testBtnText, { color: theme.accent }]}>Send Test Notification</Text>
                    </>
                  )}
                </Pressable>
                {testResult && (
                  <Text style={[styles.testResultText, { color: theme.textSoft }]}>{testResult}</Text>
                )}
              </View>
            </ScrollView>
          )}

          {/* Footer Save Button */}
          <Pressable
            onPress={handleSave}
            disabled={saving}
            style={[styles.saveBtn, { backgroundColor: theme.brand }]}
          >
            {saving ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.saveBtnText}>{tr('save') || 'Save Settings'}</Text>
            )}
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.55)',
    justifyContent: 'flex-end',
  },
  modalCard: {
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: Platform.OS === 'ios' ? 36 : 20,
    maxHeight: '85%',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingBottom: 14,
  },
  rtlRow: {
    flexDirection: 'row-reverse',
  },
  titleWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '700',
  },
  closeBtn: {
    padding: 6,
  },
  loadingWrap: {
    paddingVertical: 40,
    alignItems: 'center',
  },
  prefRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
    borderBottomWidth: 1,
  },
  rowBetween: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  prefSection: {
    paddingVertical: 14,
    borderBottomWidth: 1,
  },
  prefTextCol: {
    flex: 1,
    paddingRight: 14,
  },
  prefLabel: {
    fontSize: 15,
    fontWeight: '600',
  },
  prefSub: {
    fontSize: 12,
    marginTop: 2,
  },
  pillsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 10,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: RADIUS.pill,
    borderWidth: 1,
  },
  pillText: {
    fontSize: 13,
  },
  testWrap: {
    marginTop: 16,
    alignItems: 'center',
  },
  testBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
    paddingHorizontal: 18,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    width: '100%',
  },
  testBtnText: {
    fontSize: 14,
    fontWeight: '600',
  },
  testResultText: {
    fontSize: 12,
    marginTop: 6,
  },
  saveBtn: {
    marginTop: 12,
    paddingVertical: 14,
    borderRadius: RADIUS.lg,
    alignItems: 'center',
  },
  saveBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
});
