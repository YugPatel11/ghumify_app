import React, { useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { RADIUS, SPACING } from '../lib/theme';
import GradientView from './GradientView';

export interface Contradiction {
  field: string;
  formValue: any;
  remarksValue: any;
  message: string;
}

export interface MergedPlanReview {
  city: string;
  numberOfDays: number;
  hours: number;
  startTime: string;
  endTime: string;
  travelMode: string;
  pace: string;
  foodPreference: string;
  interests: string[];
  sources: Record<string, 'form' | 'remarks' | 'default'>;
  contradictions: Contradiction[];
  assumptions: string[];
}

interface Props {
  visible: boolean;
  plan: MergedPlanReview | null;
  onConfirm: (finalPlan: MergedPlanReview) => void;
  onClose: () => void;
}

export default function DraftReviewModal({ visible, plan, onConfirm, onClose }: Props) {
  const { theme, t: tr, isRtlMode } = useApp();
  const [resolvedPlan, setResolvedPlan] = useState<MergedPlanReview | null>(plan);

  if (!plan) return null;
  const currentPlan = resolvedPlan || plan;

  const handleSwitchContradiction = (field: string, newValue: any) => {
    setResolvedPlan((prev) => {
      if (!prev) return prev;
      return {
        ...prev,
        [field]: newValue,
        sources: {
          ...prev.sources,
          [field]: 'remarks',
        },
        contradictions: prev.contradictions.filter((c) => c.field !== field),
      };
    });
  };

  const getSourceBadge = (source?: string) => {
    switch (source) {
      case 'form':
        return { label: 'Form', bg: '#3b82f615', color: '#3b82f6' };
      case 'remarks':
        return { label: 'From Remarks', bg: '#10b98115', color: '#10b981' };
      default:
        return { label: 'Default', bg: '#6b728015', color: '#6b7280' };
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <View style={styles.overlay}>
        <SafeAreaView style={[styles.sheet, { backgroundColor: theme.card }]} edges={['bottom']}>
          {/* Header */}
          <View style={[styles.header, isRtlMode && styles.rtlRow]}>
            <View style={{ flex: 1 }}>
              <Text style={[styles.headerTitle, { color: theme.text }, isRtlMode && styles.rtlText]}>
                {tr('draft.reviewTitle') || 'Review Itinerary Plan'}
              </Text>
              <Text style={[styles.headerSub, { color: theme.textMuted }, isRtlMode && styles.rtlText]}>
                {tr('draft.reviewSub') || 'Check merged details before creating your trip'}
              </Text>
            </View>
            <Pressable onPress={onClose} style={styles.closeBtn}>
              <Ionicons name="close-circle" size={26} color={theme.textMuted} />
            </Pressable>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.scrollBody}>
            {/* Contradiction Warnings if any */}
            {currentPlan.contradictions && currentPlan.contradictions.length > 0 && (
              <View style={styles.warningContainer}>
                {currentPlan.contradictions.map((contra, idx) => (
                  <View key={idx} style={[styles.contraCard, { borderColor: '#f59e0b', backgroundColor: '#fef3c720' }]}>
                    <View style={styles.contraHeader}>
                      <Ionicons name="alert-circle" size={20} color="#f59e0b" />
                      <Text style={[styles.contraTitle, { color: '#b45309' }]}>
                        Conflict in {contra.field}
                      </Text>
                    </View>
                    <Text style={[styles.contraText, { color: theme.textSoft }]}>{contra.message}</Text>
                    <View style={styles.contraActionRow}>
                      <Pressable
                        onPress={() => handleSwitchContradiction(contra.field, contra.remarksValue)}
                        style={[styles.switchBtn, { backgroundColor: '#f59e0b' }]}
                      >
                        <Text style={styles.switchBtnText}>
                          Use remarks value ({String(contra.remarksValue)})
                        </Text>
                      </Pressable>
                    </View>
                  </View>
                ))}
              </View>
            )}

            {/* Summary Grid with Source Badges */}
            <View style={[styles.summaryBox, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
              {/* Destination */}
              <View style={styles.detailRow}>
                <View>
                  <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Destination</Text>
                  <Text style={[styles.detailValue, { color: theme.text }]}>{currentPlan.city}</Text>
                </View>
                <View style={[styles.badge, { backgroundColor: getSourceBadge(currentPlan.sources.city).bg }]}>
                  <Text style={[styles.badgeText, { color: getSourceBadge(currentPlan.sources.city).color }]}>
                    {getSourceBadge(currentPlan.sources.city).label}
                  </Text>
                </View>
              </View>

              <View style={[styles.divider, { backgroundColor: theme.border }]} />

              {/* Duration */}
              <View style={styles.detailRow}>
                <View>
                  <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Duration</Text>
                  <Text style={[styles.detailValue, { color: theme.text }]}>
                    {currentPlan.numberOfDays} {currentPlan.numberOfDays > 1 ? 'Days' : 'Day'} ({currentPlan.hours} hrs/day)
                  </Text>
                </View>
                <View style={[styles.badge, { backgroundColor: getSourceBadge(currentPlan.sources.numberOfDays).bg }]}>
                  <Text style={[styles.badgeText, { color: getSourceBadge(currentPlan.sources.numberOfDays).color }]}>
                    {getSourceBadge(currentPlan.sources.numberOfDays).label}
                  </Text>
                </View>
              </View>

              <View style={[styles.divider, { backgroundColor: theme.border }]} />

              {/* Hours */}
              <View style={styles.detailRow}>
                <View>
                  <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Active Window</Text>
                  <Text style={[styles.detailValue, { color: theme.text }]}>
                    {currentPlan.startTime} - {currentPlan.endTime}
                  </Text>
                </View>
                <View style={[styles.badge, { backgroundColor: getSourceBadge(currentPlan.sources.startTime).bg }]}>
                  <Text style={[styles.badgeText, { color: getSourceBadge(currentPlan.sources.startTime).color }]}>
                    {getSourceBadge(currentPlan.sources.startTime).label}
                  </Text>
                </View>
              </View>

              <View style={[styles.divider, { backgroundColor: theme.border }]} />

              {/* Pace & Dietary */}
              <View style={styles.detailRow}>
                <View>
                  <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Pace & Food</Text>
                  <Text style={[styles.detailValue, { color: theme.text }]}>
                    {currentPlan.pace.toUpperCase()} · {currentPlan.foodPreference.toUpperCase()}
                  </Text>
                </View>
                <View style={[styles.badge, { backgroundColor: getSourceBadge(currentPlan.sources.foodPreference).bg }]}>
                  <Text style={[styles.badgeText, { color: getSourceBadge(currentPlan.sources.foodPreference).color }]}>
                    {getSourceBadge(currentPlan.sources.foodPreference).label}
                  </Text>
                </View>
              </View>
            </View>

            {/* Assumptions */}
            {currentPlan.assumptions && currentPlan.assumptions.length > 0 && (
              <View style={styles.assumptionsSection}>
                <Text style={[styles.assumptionsTitle, { color: theme.textMuted }]}>Assumptions Made:</Text>
                {currentPlan.assumptions.map((assump, i) => (
                  <View key={i} style={styles.bulletRow}>
                    <Text style={{ color: theme.brand, marginRight: 6 }}>•</Text>
                    <Text style={[styles.assumpText, { color: theme.textSoft }]}>{assump}</Text>
                  </View>
                ))}
              </View>
            )}
          </ScrollView>

          {/* Confirm Button */}
          <View style={styles.footer}>
            <Pressable
              onPress={() => onConfirm(currentPlan)}
              style={({ pressed }) => [{ opacity: pressed ? 0.9 : 1 }]}
            >
              <GradientView gradient="cherry" style={styles.confirmBtn} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }}>
                <Ionicons name="sparkles" size={18} color="#fff" />
                <Text style={styles.confirmBtnText}>
                  {tr('draft.confirmBtn') || 'Confirm & Create Itinerary'}
                </Text>
              </GradientView>
            </Pressable>
          </View>
        </SafeAreaView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  sheet: {
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '85%',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingTop: 18,
    paddingBottom: 14,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '800',
  },
  headerSub: {
    fontSize: 13,
    marginTop: 2,
  },
  closeBtn: {
    padding: 4,
  },
  scrollBody: {
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  warningContainer: {
    marginBottom: 16,
    gap: 10,
  },
  contraCard: {
    padding: 14,
    borderRadius: RADIUS.md,
    borderWidth: 1.5,
  },
  contraHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 6,
  },
  contraTitle: {
    fontSize: 14,
    fontWeight: '800',
  },
  contraText: {
    fontSize: 13,
    lineHeight: 18,
    marginBottom: 10,
  },
  contraActionRow: {
    flexDirection: 'row',
  },
  switchBtn: {
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: RADIUS.sm,
  },
  switchBtnText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '700',
  },
  summaryBox: {
    padding: 16,
    borderRadius: RADIUS.lg,
    borderWidth: 1,
    gap: 12,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  detailLabel: {
    fontSize: 12,
    fontWeight: '600',
  },
  detailValue: {
    fontSize: 15,
    fontWeight: '800',
    marginTop: 2,
  },
  divider: {
    height: 1,
  },
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: RADIUS.pill,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: '700',
  },
  assumptionsSection: {
    marginTop: 16,
    paddingHorizontal: 4,
  },
  assumptionsTitle: {
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 6,
  },
  bulletRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  assumpText: {
    fontSize: 12.5,
  },
  footer: {
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 16,
  },
  confirmBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 15,
    borderRadius: RADIUS.md,
  },
  confirmBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '800',
  },
  rtlRow: {
    flexDirection: 'row-reverse',
  },
  rtlText: {
    textAlign: 'right',
  },
});
