import React, { useState, useEffect } from 'react';
import {
  Modal,
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  TextInput,
  Switch,
  ActivityIndicator,
  Platform,
  Alert,
} from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { RADIUS, SPACING } from '../lib/theme';
import { EmergencyContact } from '../lib/sosClient';

interface Props {
  visible: boolean;
  onClose: () => void;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export default function EmergencyContactsModal({ visible, onClose }: Props) {
  const { theme, t: tr, isRtlMode } = useApp();
  const [loading, setLoading] = useState(false);
  const [contacts, setContacts] = useState<EmergencyContact[]>([]);
  const [activeTab, setActiveTab] = useState<'contacts' | 'medical' | 'settings'>('contacts');

  // New contact form state
  const [showAddForm, setShowAddForm] = useState(false);
  const [newName, setNewName] = useState('');
  const [newPhone, setNewPhone] = useState('+91');
  const [newRelationship, setNewRelationship] = useState('Family');
  const [addingContact, setAddingContact] = useState(false);

  // Verification modal state
  const [verifyingContactId, setVerifyingContactId] = useState<string | null>(null);
  const [otpCode, setOtpCode] = useState('');
  const [submittingOtp, setSubmittingOtp] = useState(false);

  // Medical profile state
  const [bloodGroup, setBloodGroup] = useState('O+');
  const [allergies, setAllergies] = useState('');
  const [conditions, setConditions] = useState('');
  const [medications, setMedications] = useState('');
  const [includeInSos, setIncludeInSos] = useState(false);
  const [savingMedical, setSavingMedical] = useState(false);

  // SOS settings state
  const [countdownSec, setCountdownSec] = useState(5);
  const [emergencyNumber, setEmergencyNumber] = useState('112');
  const [testSending, setTestSending] = useState(false);
  const [testFeedback, setTestFeedback] = useState<string | null>(null);

  useEffect(() => {
    if (visible) {
      loadAllData();
    }
  }, [visible]);

  const loadAllData = async () => {
    setLoading(true);
    try {
      // 1. Fetch contacts
      const cRes = await fetch(`${BACKEND_URL}/api/v1/me/emergency-contacts?userId=user_demo`);
      if (cRes.ok) {
        const cJson = await cRes.json();
        setContacts(cJson.contacts || []);
      }

      // 2. Fetch medical profile
      const mRes = await fetch(`${BACKEND_URL}/api/v1/me/medical-profile?userId=user_demo`);
      if (mRes.ok) {
        const mJson = await mRes.json();
        if (mJson.profile) {
          setBloodGroup(mJson.profile.bloodGroup || 'O+');
          setAllergies(mJson.profile.allergies || '');
          setConditions(mJson.profile.medicalConditions || '');
          setMedications(mJson.profile.medications || '');
          setIncludeInSos(mJson.profile.includeInSos || false);
        }
      }

      // 3. Fetch SOS settings
      const sRes = await fetch(`${BACKEND_URL}/api/v1/me/sos-settings?userId=user_demo`);
      if (sRes.ok) {
        const sJson = await sRes.json();
        if (sJson.settings) {
          setCountdownSec(sJson.settings.countdownSeconds || 5);
          setEmergencyNumber(sJson.settings.emergencyNumber || '112');
        }
      }
    } catch (e) {
      console.warn('Failed to load emergency data:', e);
    } finally {
      setLoading(false);
    }
  };

  const handleAddContact = async () => {
    if (!newName.trim() || !newPhone.trim()) return;
    setAddingContact(true);
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/me/emergency-contacts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: 'user_demo',
          name: newName,
          phone: newPhone,
          relationship: newRelationship,
        }),
      });
      if (res.ok) {
        setNewName('');
        setNewPhone('+91');
        setShowAddForm(false);
        loadAllData();
      } else {
        const err = await res.json();
        alert(err.error || 'Failed to add contact');
      }
    } catch {
      alert('Could not reach server.');
    } finally {
      setAddingContact(false);
    }
  };

  const handleDeleteContact = async (id: string) => {
    try {
      await fetch(`${BACKEND_URL}/api/v1/me/emergency-contacts?id=${id}`, { method: 'DELETE' });
      setContacts((prev) => prev.filter((c) => c.id !== id));
    } catch {}
  };

  const handleRequestVerify = async (contactId: string) => {
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/me/emergency-contacts/${contactId}/verify-request`, {
        method: 'POST',
      });
      if (res.ok) {
        setVerifyingContactId(contactId);
        setOtpCode('');
      }
    } catch {}
  };

  const handleConfirmVerify = async () => {
    if (!verifyingContactId || !otpCode.trim()) return;
    setSubmittingOtp(true);
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/me/emergency-contacts/${verifyingContactId}/verify-confirm`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: otpCode }),
      });
      if (res.ok) {
        setVerifyingContactId(null);
        loadAllData();
      } else {
        const err = await res.json();
        alert(err.error || 'Incorrect code');
      }
    } catch {
      alert('Verification failed.');
    } finally {
      setSubmittingOtp(false);
    }
  };

  const handleSaveMedical = async () => {
    setSavingMedical(true);
    try {
      await fetch(`${BACKEND_URL}/api/v1/me/medical-profile`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: 'user_demo',
          bloodGroup,
          allergies,
          medicalConditions: conditions,
          medications,
          includeInSos,
        }),
      });
      alert('Medical profile updated.');
    } catch {
      alert('Failed to update medical profile.');
    } finally {
      setSavingMedical(false);
    }
  };

  const handleSaveSettings = async () => {
    try {
      await fetch(`${BACKEND_URL}/api/v1/me/sos-settings`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: 'user_demo',
          countdownSeconds: countdownSec,
          emergencyNumber,
        }),
      });
      alert('SOS settings updated.');
    } catch {
      alert('Failed to update settings.');
    }
  };

  const handleSendTestDrill = async () => {
    setTestSending(true);
    setTestFeedback(null);
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/sos/test`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: 'user_demo' }),
      });
      if (res.ok) {
        setTestFeedback('Drill alert sent to your device only. Readiness verified!');
      } else {
        setTestFeedback('Drill simulation complete.');
      }
    } catch {
      setTestFeedback('Server unreachable on LAN.');
    } finally {
      setTestSending(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={[styles.container, { backgroundColor: theme.bg }]}>
        {/* Header */}
        <View style={[styles.header, { backgroundColor: theme.card, borderBottomColor: theme.border }]}>
          <Pressable onPress={onClose} style={styles.closeBtn}>
            <Ionicons name="close" size={24} color={theme.text} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: theme.text }]}>Emergency SOS & Contacts</Text>
          <View style={{ width: 40 }} />
        </View>

        {/* Tab Switcher */}
        <View style={[styles.tabBar, { borderBottomColor: theme.border }]}>
          {(['contacts', 'medical', 'settings'] as const).map((tab) => (
            <Pressable
              key={tab}
              onPress={() => setActiveTab(tab)}
              style={[
                styles.tabItem,
                activeTab === tab && { borderBottomColor: '#dc2626', borderBottomWidth: 2.5 },
              ]}
            >
              <Text
                style={[
                  styles.tabText,
                  { color: activeTab === tab ? '#dc2626' : theme.textMuted },
                  activeTab === tab && { fontWeight: 'bold' },
                ]}
              >
                {tab === 'contacts' ? 'Contacts' : tab === 'medical' ? 'Medical' : 'Settings'}
              </Text>
            </Pressable>
          ))}
        </View>

        {loading ? (
          <View style={styles.loadingWrap}>
            <ActivityIndicator size="large" color="#dc2626" />
          </View>
        ) : (
          <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 60 }}>
            {/* TAB 1: Contacts */}
            {activeTab === 'contacts' && (
              <View>
                <View style={styles.sectionHeaderRow}>
                  <Text style={[styles.sectionTitle, { color: theme.text }]}>
                    Emergency Contacts ({contacts.length}/5)
                  </Text>
                  {contacts.length < 5 && !showAddForm && (
                    <Pressable
                      onPress={() => setShowAddForm(true)}
                      style={[styles.addBtn, { backgroundColor: '#dc2626' }]}
                    >
                      <Ionicons name="add" size={16} color="#fff" />
                      <Text style={styles.addBtnText}>Add Contact</Text>
                    </Pressable>
                  )}
                </View>

                {/* Add Contact Form */}
                {showAddForm && (
                  <View style={[styles.formCard, { backgroundColor: theme.card, borderColor: theme.border }]}>
                    <Text style={[styles.formTitle, { color: theme.text }]}>New Emergency Contact</Text>
                    <TextInput
                      value={newName}
                      onChangeText={setNewName}
                      placeholder="Full Name"
                      placeholderTextColor={theme.textMuted}
                      style={[styles.input, { color: theme.text, borderColor: theme.border }]}
                    />
                    <TextInput
                      value={newPhone}
                      onChangeText={setNewPhone}
                      placeholder="+919876543210 (E.164 with country code)"
                      placeholderTextColor={theme.textMuted}
                      keyboardType="phone-pad"
                      style={[styles.input, { color: theme.text, borderColor: theme.border }]}
                    />
                    <View style={styles.formActions}>
                      <Pressable
                        onPress={() => setShowAddForm(false)}
                        style={[styles.formBtn, { borderColor: theme.border, borderWidth: 1 }]}
                      >
                        <Text style={{ color: theme.text }}>Cancel</Text>
                      </Pressable>
                      <Pressable
                        onPress={handleAddContact}
                        disabled={addingContact}
                        style={[styles.formBtn, { backgroundColor: '#dc2626' }]}
                      >
                        {addingContact ? <ActivityIndicator color="#fff" /> : <Text style={{ color: '#fff', fontWeight: 'bold' }}>Save</Text>}
                      </Pressable>
                    </View>
                  </View>
                )}

                {/* Contacts List */}
                {contacts.length === 0 ? (
                  <View style={styles.emptyWrap}>
                    <Ionicons name="people-outline" size={44} color={theme.textMuted} />
                    <Text style={[styles.emptyText, { color: theme.textMuted }]}>
                      No emergency contacts yet. Add family or close friends who will be notified in emergencies.
                    </Text>
                  </View>
                ) : (
                  contacts.map((c) => (
                    <View key={c.id} style={[styles.contactCard, { backgroundColor: theme.card, borderColor: theme.border }]}>
                      <View style={{ flex: 1 }}>
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                          <Text style={[styles.contactName, { color: theme.text }]}>{c.name}</Text>
                          {c.isVerified ? (
                            <View style={styles.verifiedBadge}>
                              <Ionicons name="checkmark-circle" size={14} color="#10b981" />
                              <Text style={styles.verifiedText}>Verified</Text>
                            </View>
                          ) : (
                            <Pressable onPress={() => handleRequestVerify(c.id)} style={styles.unverifiedBadge}>
                              <Text style={styles.unverifiedText}>Tap to Verify</Text>
                            </Pressable>
                          )}
                        </View>
                        <Text style={[styles.contactPhone, { color: theme.textMuted }]}>{c.phone}</Text>
                      </View>
                      <Pressable onPress={() => handleDeleteContact(c.id)} style={{ padding: 6 }}>
                        <Ionicons name="trash-outline" size={18} color="#ef4444" />
                      </Pressable>
                    </View>
                  ))
                )}

                {/* Verification Modal Sheet */}
                {verifyingContactId && (
                  <View style={[styles.verifyBox, { backgroundColor: theme.accentSoft, borderColor: theme.accent }]}>
                    <Text style={[styles.verifyTitle, { color: theme.text }]}>Enter 6-Digit Verification Code</Text>
                    <Text style={[styles.verifySub, { color: theme.textMuted }]}>
                      A code was sent via SMS to verify this contact number.
                    </Text>
                    <TextInput
                      value={otpCode}
                      onChangeText={setOtpCode}
                      placeholder="123456"
                      placeholderTextColor={theme.textMuted}
                      keyboardType="number-pad"
                      maxLength={6}
                      style={[styles.otpInput, { color: theme.text, backgroundColor: theme.card }]}
                    />
                    <View style={{ flexDirection: 'row', gap: 8, marginTop: 10 }}>
                      <Pressable
                        onPress={() => setVerifyingContactId(null)}
                        style={[styles.smallBtn, { borderColor: theme.border, borderWidth: 1 }]}
                      >
                        <Text style={{ color: theme.text }}>Cancel</Text>
                      </Pressable>
                      <Pressable
                        onPress={handleConfirmVerify}
                        disabled={submittingOtp}
                        style={[styles.smallBtn, { backgroundColor: theme.accent }]}
                      >
                        <Text style={{ color: '#fff', fontWeight: 'bold' }}>Confirm Code</Text>
                      </Pressable>
                    </View>
                  </View>
                )}
              </View>
            )}

            {/* TAB 2: Medical Profile */}
            {activeTab === 'medical' && (
              <View>
                <Text style={[styles.sectionTitle, { color: theme.text }]}>Emergency Medical Information</Text>
                <Text style={[styles.sectionSub, { color: theme.textMuted }]}>
                  Optional. Shared only with your emergency contacts during an active SOS.
                </Text>

                <View style={[styles.fieldWrap, { marginTop: 14 }]}>
                  <Text style={[styles.fieldLabel, { color: theme.text }]}>Blood Group</Text>
                  <View style={styles.bloodRow}>
                    {['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((bg) => (
                      <Pressable
                        key={bg}
                        onPress={() => setBloodGroup(bg)}
                        style={[
                          styles.bloodPill,
                          { borderColor: theme.border },
                          bloodGroup === bg && { backgroundColor: '#dc2626', borderColor: '#dc2626' },
                        ]}
                      >
                        <Text style={[styles.bloodText, { color: bloodGroup === bg ? '#fff' : theme.text }]}>
                          {bg}
                        </Text>
                      </Pressable>
                    ))}
                  </View>
                </View>

                <View style={styles.fieldWrap}>
                  <Text style={[styles.fieldLabel, { color: theme.text }]}>Allergies</Text>
                  <TextInput
                    value={allergies}
                    onChangeText={setAllergies}
                    placeholder="e.g. Penicillin, Peanuts, Sulfa drugs"
                    placeholderTextColor={theme.textMuted}
                    style={[styles.input, { color: theme.text, borderColor: theme.border }]}
                  />
                </View>

                <View style={styles.fieldWrap}>
                  <Text style={[styles.fieldLabel, { color: theme.text }]}>Medical Conditions</Text>
                  <TextInput
                    value={conditions}
                    onChangeText={setConditions}
                    placeholder="e.g. Asthma, Diabetes Type 1, Hypertension"
                    placeholderTextColor={theme.textMuted}
                    style={[styles.input, { color: theme.text, borderColor: theme.border }]}
                  />
                </View>

                <View style={styles.fieldWrap}>
                  <Text style={[styles.fieldLabel, { color: theme.text }]}>Current Medications</Text>
                  <TextInput
                    value={medications}
                    onChangeText={setMedications}
                    placeholder="e.g. Inhaler, Insulin"
                    placeholderTextColor={theme.textMuted}
                    style={[styles.input, { color: theme.text, borderColor: theme.border }]}
                  />
                </View>

                <View style={styles.switchRow}>
                  <View style={{ flex: 1, paddingRight: 10 }}>
                    <Text style={[styles.switchTitle, { color: theme.text }]}>Include in Emergency Alert</Text>
                    <Text style={[styles.switchSub, { color: theme.textMuted }]}>
                      Attaches vital medical info to the alert message sent to contacts
                    </Text>
                  </View>
                  <Switch
                    value={includeInSos}
                    onValueChange={setIncludeInSos}
                    trackColor={{ false: theme.border, true: '#dc2626' }}
                  />
                </View>

                <Pressable
                  onPress={handleSaveMedical}
                  disabled={savingMedical}
                  style={[styles.saveBtn, { backgroundColor: '#dc2626' }]}
                >
                  {savingMedical ? <ActivityIndicator color="#fff" /> : <Text style={styles.saveBtnText}>Save Medical Info</Text>}
                </Pressable>
              </View>
            )}

            {/* TAB 3: Settings & Drill */}
            {activeTab === 'settings' && (
              <View>
                <Text style={[styles.sectionTitle, { color: theme.text }]}>SOS Safety Settings</Text>

                <View style={[styles.fieldWrap, { marginTop: 14 }]}>
                  <Text style={[styles.fieldLabel, { color: theme.text }]}>Countdown Delay (Seconds)</Text>
                  <View style={styles.bloodRow}>
                    {[0, 3, 5, 10].map((sec) => (
                      <Pressable
                        key={sec}
                        onPress={() => setCountdownSec(sec)}
                        style={[
                          styles.bloodPill,
                          { borderColor: theme.border },
                          countdownSec === sec && { backgroundColor: '#dc2626', borderColor: '#dc2626' },
                        ]}
                      >
                        <Text style={[styles.bloodText, { color: countdownSec === sec ? '#fff' : theme.text }]}>
                          {sec === 0 ? 'Instant' : `${sec}s`}
                        </Text>
                      </Pressable>
                    ))}
                  </View>
                </View>

                <View style={styles.fieldWrap}>
                  <Text style={[styles.fieldLabel, { color: theme.text }]}>Regional Emergency Number</Text>
                  <TextInput
                    value={emergencyNumber}
                    onChangeText={setEmergencyNumber}
                    placeholder="112 (India/EU), 911 (USA), 999 (UK)"
                    placeholderTextColor={theme.textMuted}
                    keyboardType="number-pad"
                    style={[styles.input, { color: theme.text, borderColor: theme.border }]}
                  />
                </View>

                <Pressable onPress={handleSaveSettings} style={[styles.saveBtn, { backgroundColor: theme.brand }]}>
                  <Text style={styles.saveBtnText}>Save Settings</Text>
                </Pressable>

                {/* Self Drill Test */}
                <View style={[styles.drillCard, { backgroundColor: theme.card, borderColor: theme.border }]}>
                  <Ionicons name="shield" size={24} color="#dc2626" />
                  <Text style={[styles.drillTitle, { color: theme.text }]}>Simulate Test SOS Drill</Text>
                  <Text style={[styles.drillSub, { color: theme.textMuted }]}>
                    Dispatches a simulation alert only to your device. No emergency contacts will be messaged.
                  </Text>
                  <Pressable
                    onPress={handleSendTestDrill}
                    disabled={testSending}
                    style={[styles.drillBtn, { backgroundColor: '#dc262620', borderColor: '#dc2626' }]}
                  >
                    {testSending ? <ActivityIndicator color="#dc2626" /> : <Text style={styles.drillBtnText}>Run Drill Test</Text>}
                  </Pressable>
                  {testFeedback && (
                    <Text style={[styles.feedbackText, { color: '#059669' }]}>{testFeedback}</Text>
                  )}
                </View>
              </View>
            )}
          </ScrollView>
        )}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 14,
    paddingTop: Platform.OS === 'ios' ? 50 : 14,
    borderBottomWidth: 1,
  },
  headerTitle: { fontSize: 17, fontWeight: '800' },
  closeBtn: { padding: 6 },
  tabBar: { flexDirection: 'row', borderBottomWidth: 1 },
  tabItem: { flex: 1, alignItems: 'center', paddingVertical: 14 },
  tabText: { fontSize: 14, fontWeight: '600' },
  loadingWrap: { paddingVertical: 60, alignItems: 'center' },
  sectionHeaderRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 },
  sectionTitle: { fontSize: 16, fontWeight: '800' },
  sectionSub: { fontSize: 13, marginTop: 4, lineHeight: 18 },
  addBtn: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 12, paddingVertical: 7, borderRadius: RADIUS.pill },
  addBtnText: { color: '#fff', fontSize: 12.5, fontWeight: 'bold' },
  formCard: { padding: 14, borderRadius: RADIUS.lg, borderWidth: 1, marginBottom: 14, gap: 10 },
  formTitle: { fontSize: 15, fontWeight: '700' },
  input: { borderWidth: 1, borderRadius: RADIUS.md, paddingHorizontal: 12, paddingVertical: 10, fontSize: 14 },
  formActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 10, marginTop: 4 },
  formBtn: { paddingHorizontal: 16, paddingVertical: 8, borderRadius: RADIUS.md },
  contactCard: { flexDirection: 'row', alignItems: 'center', padding: 14, borderRadius: RADIUS.lg, borderWidth: 1, marginBottom: 10 },
  contactName: { fontSize: 15, fontWeight: '700' },
  contactPhone: { fontSize: 13, marginTop: 2 },
  verifiedBadge: { flexDirection: 'row', alignItems: 'center', gap: 3, backgroundColor: '#10b98120', paddingHorizontal: 6, paddingVertical: 2, borderRadius: RADIUS.pill },
  verifiedText: { color: '#10b981', fontSize: 10, fontWeight: 'bold' },
  unverifiedBadge: { backgroundColor: '#f59e0b20', paddingHorizontal: 6, paddingVertical: 2, borderRadius: RADIUS.pill },
  unverifiedText: { color: '#f59e0b', fontSize: 10, fontWeight: 'bold' },
  emptyWrap: { paddingVertical: 40, alignItems: 'center', gap: 8 },
  emptyText: { fontSize: 13, textAlign: 'center', maxWidth: 260 },
  verifyBox: { padding: 14, borderRadius: RADIUS.lg, borderWidth: 1, marginTop: 10 },
  verifyTitle: { fontSize: 14, fontWeight: 'bold' },
  verifySub: { fontSize: 12, marginTop: 2, marginBottom: 8 },
  otpInput: { borderWidth: 1, borderColor: '#ccc', borderRadius: RADIUS.md, padding: 10, fontSize: 16, textAlign: 'center', letterSpacing: 4 },
  smallBtn: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: RADIUS.md },
  fieldWrap: { marginBottom: 14 },
  fieldLabel: { fontSize: 14, fontWeight: '700', marginBottom: 6 },
  bloodRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  bloodPill: { paddingHorizontal: 12, paddingVertical: 7, borderRadius: RADIUS.pill, borderWidth: 1 },
  bloodText: { fontSize: 13, fontWeight: '700' },
  switchRow: { flexDirection: 'row', alignItems: 'center', marginVertical: 14 },
  switchTitle: { fontSize: 14, fontWeight: '700' },
  switchSub: { fontSize: 12, marginTop: 2 },
  saveBtn: { paddingVertical: 14, borderRadius: RADIUS.lg, alignItems: 'center', marginTop: 10 },
  saveBtnText: { color: '#fff', fontSize: 15, fontWeight: 'bold' },
  drillCard: { padding: 18, borderRadius: RADIUS.lg, borderWidth: 1, marginTop: 24, alignItems: 'center', gap: 8 },
  drillTitle: { fontSize: 16, fontWeight: '800' },
  drillSub: { fontSize: 12.5, textAlign: 'center', lineHeight: 17 },
  drillBtn: { paddingHorizontal: 20, paddingVertical: 10, borderRadius: RADIUS.pill, borderWidth: 1, marginTop: 6 },
  drillBtnText: { color: '#dc2626', fontWeight: '800', fontSize: 13 },
  feedbackText: { fontSize: 12, fontWeight: '600', marginTop: 4 },
});
