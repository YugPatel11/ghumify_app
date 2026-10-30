import React, { useState, useEffect } from 'react';
import {
  Modal,
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  ActivityIndicator,
  Linking,
  Platform,
  Share,
} from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { RADIUS, SPACING, shadow } from '../lib/theme';
import { SosClient, NearbyHospital, DeliveryStatusItem } from '../lib/sosClient';

interface Props {
  visible: boolean;
  sosId: string;
  onClose: () => void;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export default function SosActiveModal({ visible, sosId, onClose }: Props) {
  const { theme, t: tr, isRtlMode } = useApp();
  const [loading, setLoading] = useState(false);
  const [resolving, setResolving] = useState(false);
  const [statusData, setStatusData] = useState<any>(null);
  const [hospitals, setHospitals] = useState<NearbyHospital[]>([]);
  const [deliveries, setDeliveries] = useState<DeliveryStatusItem[]>([]);

  useEffect(() => {
    if (visible && sosId) {
      loadSosDetails();
      const interval = setInterval(loadSosDetails, 5000); // Polling status
      return () => clearInterval(interval);
    }
  }, [visible, sosId]);

  const loadSosDetails = async () => {
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/sos/${sosId}`);
      if (res.ok) {
        const json = await res.json();
        setStatusData(json.sosEvent);
        setHospitals(json.hospitals || []);
        setDeliveries(json.deliveries || []);
      }
    } catch (e) {
      console.warn('Failed to fetch SOS details:', e);
    }
  };

  const handleImSafe = async () => {
    setResolving(true);
    await SosClient.resolveSafe(sosId);
    setResolving(false);
    onClose();
  };

  const handleFalseAlarm = async () => {
    setResolving(true);
    await SosClient.cancelSos(sosId, true);
    setResolving(false);
    onClose();
  };

  const handleShareLocation = async () => {
    if (!statusData) return;
    const mapUrl = `https://www.google.com/maps?q=${statusData.lat},${statusData.lng}`;
    try {
      await Share.share({
        message: `EMERGENCY ALERT: I need assistance! My live location is: ${mapUrl}`,
        url: mapUrl,
      });
    } catch {}
  };

  const openNavigation = (lat: number, lng: number) => {
    const url = `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`;
    Linking.openURL(url);
  };

  const callPhone = (phone: string) => {
    Linking.openURL(`tel:${phone}`);
  };

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={[styles.container, { backgroundColor: theme.bg }]}>
        {/* Urgent Header */}
        <View style={styles.emergencyBanner}>
          <View style={styles.pulseDot} />
          <Text style={styles.emergencyBannerText}>EMERGENCY ALERT ACTIVE</Text>
        </View>

        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ padding: 20, paddingBottom: 60 }}>
          {/* Quick Call Emergency Services */}
          <Pressable
            onPress={() => SosClient.callEmergencyServices('112')}
            style={[styles.call112Btn, shadow(theme, 2)]}
            accessibilityLabel="Call Official Emergency Services 112"
          >
            <Ionicons name="call" size={24} color="#fff" />
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={styles.call112Title}>Call Emergency Services (112)</Text>
              <Text style={styles.call112Sub}>Police / Ambulance / Disaster Helpline</Text>
            </View>
            <Ionicons name="chevron-forward" size={20} color="#fff" />
          </Pressable>

          {/* Current Location Card */}
          <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <View style={styles.cardHeader}>
              <Ionicons name="location" size={20} color="#dc2626" />
              <Text style={[styles.cardTitle, { color: theme.text }]}>Your Broadcasted Location</Text>
            </View>
            {statusData ? (
              <View style={styles.locationBody}>
                <Text style={[styles.coordsText, { color: theme.text }]}>
                  {statusData.lat.toFixed(5)}, {statusData.lng.toFixed(5)} (±{statusData.accuracyM}m)
                </Text>
                <View style={styles.locActionsRow}>
                  <Pressable
                    onPress={() => openNavigation(statusData.lat, statusData.lng)}
                    style={[styles.smallBtn, { backgroundColor: theme.accentSoft }]}
                  >
                    <Ionicons name="map-outline" size={16} color={theme.accent} />
                    <Text style={[styles.smallBtnText, { color: theme.accent }]}>Open on Map</Text>
                  </Pressable>
                  <Pressable
                    onPress={handleShareLocation}
                    style={[styles.smallBtn, { backgroundColor: theme.brandSoft }]}
                  >
                    <Ionicons name="share-outline" size={16} color={theme.brand} />
                    <Text style={[styles.smallBtnText, { color: theme.brand }]}>Share Link</Text>
                  </Pressable>
                </View>
              </View>
            ) : (
              <ActivityIndicator color={theme.brand} />
            )}
          </View>

          {/* Contact Delivery Statuses */}
          <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <View style={styles.cardHeader}>
              <Ionicons name="people" size={20} color={theme.brand} />
              <Text style={[styles.cardTitle, { color: theme.text }]}>Contacts Alert Delivery</Text>
            </View>
            {deliveries.length === 0 ? (
              <Text style={[styles.emptySub, { color: theme.textMuted }]}>
                Dispatching emergency messages to contacts...
              </Text>
            ) : (
              deliveries.map((deliv, idx) => (
                <View key={deliv.id || idx} style={[styles.deliveryRow, { borderBottomColor: theme.border }]}>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.delivName, { color: theme.text }]}>{deliv.contactName}</Text>
                    <Text style={[styles.delivSub, { color: theme.textMuted }]}>
                      {deliv.channel.toUpperCase()} · {deliv.phone}
                    </Text>
                  </View>
                  <View style={[styles.statusBadge, { backgroundColor: deliv.status === 'sent' || deliv.status === 'delivered' ? '#10b98120' : '#f59e0b20' }]}>
                    <Text style={[styles.statusText, { color: deliv.status === 'sent' || deliv.status === 'delivered' ? '#10b981' : '#f59e0b' }]}>
                      {deliv.status.toUpperCase()}
                    </Text>
                  </View>
                </View>
              ))
            )}
          </View>

          {/* Nearest Hospitals */}
          <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
            <View style={styles.cardHeader}>
              <Ionicons name="medkit" size={20} color="#059669" />
              <Text style={[styles.cardTitle, { color: theme.text }]}>Nearest Hospitals</Text>
            </View>
            {hospitals.length === 0 ? (
              <Text style={[styles.emptySub, { color: theme.textMuted }]}>
                Searching nearby medical centers...
              </Text>
            ) : (
              hospitals.map((h) => (
                <View key={h.id} style={[styles.hospitalItem, { borderBottomColor: theme.border }]}>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.hospitalName, { color: theme.text }]}>{h.name}</Text>
                    <Text style={[styles.hospitalDist, { color: theme.textMuted }]}>
                      {(h.distanceMeters / 1000).toFixed(1)} km away · {h.isOpen24Hours ? 'Open 24/7' : 'Hospital'}
                    </Text>
                  </View>
                  <View style={styles.hospActions}>
                    {h.phone && (
                      <Pressable onPress={() => callPhone(h.phone!)} style={[styles.circleAction, { backgroundColor: '#10b98120' }]}>
                        <Ionicons name="call" size={16} color="#10b981" />
                      </Pressable>
                    )}
                    <Pressable onPress={() => openNavigation(h.lat, h.lng)} style={[styles.circleAction, { backgroundColor: theme.brandSoft }]}>
                      <Ionicons name="navigate" size={16} color={theme.brand} />
                    </Pressable>
                  </View>
                </View>
              ))
            )}
          </View>

          {/* Resolution Action Buttons */}
          <View style={styles.resolutionWrap}>
            <Pressable
              onPress={handleImSafe}
              disabled={resolving}
              style={[styles.safeBtn, { backgroundColor: '#059669' }]}
            >
              {resolving ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <>
                  <Ionicons name="shield-checkmark" size={20} color="#fff" />
                  <Text style={styles.safeBtnText}>I'M SAFE NOW</Text>
                </>
              )}
            </Pressable>

            <Pressable
              onPress={handleFalseAlarm}
              disabled={resolving}
              style={[styles.falseAlarmBtn, { borderColor: theme.border }]}
            >
              <Text style={[styles.falseAlarmText, { color: theme.textMuted }]}>False Alarm / Cancel</Text>
            </Pressable>
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  emergencyBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#dc2626',
    paddingVertical: 14,
    paddingTop: Platform.OS === 'ios' ? 50 : 14,
    gap: 8,
  },
  pulseDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#fff',
  },
  emergencyBannerText: {
    color: '#fff',
    fontWeight: '900',
    fontSize: 15,
    letterSpacing: 1,
  },
  call112Btn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#b91c1c',
    padding: 16,
    borderRadius: RADIUS.lg,
    marginBottom: 16,
  },
  call112Title: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '800',
  },
  call112Sub: {
    color: 'rgba(255,255,255,0.85)',
    fontSize: 12,
    marginTop: 2,
  },
  card: {
    padding: 16,
    borderRadius: RADIUS.lg,
    borderWidth: 1,
    marginBottom: 16,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 10,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
  },
  locationBody: {
    gap: 10,
  },
  coordsText: {
    fontSize: 14,
    fontWeight: '600',
  },
  locActionsRow: {
    flexDirection: 'row',
    gap: 10,
  },
  smallBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: RADIUS.pill,
  },
  smallBtnText: {
    fontSize: 12.5,
    fontWeight: '700',
  },
  emptySub: {
    fontSize: 13,
    paddingVertical: 8,
  },
  deliveryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: 1,
  },
  delivName: {
    fontSize: 14,
    fontWeight: '700',
  },
  delivSub: {
    fontSize: 12,
    marginTop: 2,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: RADIUS.pill,
  },
  statusText: {
    fontSize: 11,
    fontWeight: '800',
  },
  hospitalItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: 1,
  },
  hospitalName: {
    fontSize: 14,
    fontWeight: '700',
  },
  hospitalDist: {
    fontSize: 12,
    marginTop: 2,
  },
  hospActions: {
    flexDirection: 'row',
    gap: 8,
  },
  circleAction: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: 'center',
    justifyContent: 'center',
  },
  resolutionWrap: {
    gap: 10,
    marginTop: 10,
  },
  safeBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 16,
    borderRadius: RADIUS.lg,
  },
  safeBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '900',
    letterSpacing: 1,
  },
  falseAlarmBtn: {
    paddingVertical: 12,
    borderRadius: RADIUS.lg,
    borderWidth: 1,
    alignItems: 'center',
  },
  falseAlarmText: {
    fontSize: 14,
    fontWeight: '600',
  },
});
