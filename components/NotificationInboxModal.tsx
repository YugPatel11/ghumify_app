import React, { useState, useEffect } from 'react';
import {
  Modal,
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  ActivityIndicator,
  Platform,
} from 'react-native';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { RADIUS, SPACING } from '../lib/theme';
import { NotificationClient } from '../lib/notifications';

interface Props {
  visible: boolean;
  onClose: () => void;
  onNavigateToStop?: (stopId: string) => void;
}

interface InboxNotification {
  id: string;
  tripId: string;
  stopId: string;
  type: string;
  title: string;
  body: string;
  data: any;
  notificationKey: string;
  isRead: boolean;
  createdAt: string;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export default function NotificationInboxModal({ visible, onClose, onNavigateToStop }: Props) {
  const { theme, t: tr, isRtlMode } = useApp();
  const [loading, setLoading] = useState(false);
  const [notifications, setNotifications] = useState<InboxNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    if (visible) {
      loadInbox();
    }
  }, [visible]);

  const loadInbox = async () => {
    setLoading(true);
    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/notifications/inbox?userId=user_demo`);
      if (res.ok) {
        const data = await res.json();
        setNotifications(data.notifications || []);
        setUnreadCount(data.unreadCount || 0);
      }
    } catch (e) {
      console.warn('Failed to fetch inbox notifications:', e);
    } finally {
      setLoading(false);
    }
  };

  const markAsRead = async (id: string) => {
    try {
      await fetch(`${BACKEND_URL}/api/v1/notifications/inbox/${id}/read`, { method: 'POST' });
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? { ...n, isRead: true } : n))
      );
      setUnreadCount((prev) => Math.max(0, prev - 1));
    } catch {}
  };

  const formatTimeAgo = (iso: string) => {
    const diffSec = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));
    if (diffSec < 60) return 'Just now';
    const diffMin = Math.floor(diffSec / 60);
    if (diffMin < 60) return `${diffMin}m ago`;
    const diffHour = Math.floor(diffMin / 60);
    if (diffHour < 24) return `${diffHour}h ago`;
    return `${Math.floor(diffHour / 24)}d ago`;
  };

  const getAlertIcon = (type: string) => {
    switch (type) {
      case 'leave_now':
        return { name: 'exit-outline', color: '#ef4444', bg: '#ef444420' };
      case 'go_to_next':
        return { name: 'navigate-outline', color: '#6366f1', bg: '#6366f120' };
      case 'overdue_nag':
        return { name: 'time-outline', color: '#f59e0b', bg: '#f59e0b20' };
      case 'late_warning':
        return { name: 'warning-outline', color: '#f97316', bg: '#f9731620' };
      default:
        return { name: 'notifications-outline', color: '#06b6d4', bg: '#06b6d420' };
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={[styles.modalCard, { backgroundColor: theme.card }]}>
          {/* Header */}
          <View style={[styles.headerRow, isRtlMode && styles.rtlRow]}>
            <View style={styles.titleWrap}>
              <Ionicons name="mail" size={20} color={theme.brand} />
              <Text style={[styles.modalTitle, { color: theme.text }]}>
                {tr('notificationInbox') || 'Trip Alerts Inbox'}
              </Text>
              {unreadCount > 0 && (
                <View style={[styles.badge, { backgroundColor: theme.brand }]}>
                  <Text style={styles.badgeText}>{unreadCount}</Text>
                </View>
              )}
            </View>
            <Pressable onPress={onClose} style={styles.closeBtn}>
              <Ionicons name="close" size={22} color={theme.textMuted} />
            </Pressable>
          </View>

          {loading ? (
            <View style={styles.loadingWrap}>
              <ActivityIndicator size="large" color={theme.brand} />
            </View>
          ) : notifications.length === 0 ? (
            <View style={styles.emptyWrap}>
              <Ionicons name="checkmark-done-circle-outline" size={48} color={theme.textMuted} />
              <Text style={[styles.emptyText, { color: theme.textMuted }]}>
                You are all caught up! No notifications yet.
              </Text>
            </View>
          ) : (
            <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 20 }}>
              {notifications.map((item) => {
                const iconInfo = getAlertIcon(item.type);
                return (
                  <Pressable
                    key={item.id}
                    onPress={() => {
                      if (!item.isRead) markAsRead(item.id);
                      if (item.stopId && onNavigateToStop) {
                        onClose();
                        onNavigateToStop(item.stopId);
                      }
                    }}
                    style={[
                      styles.itemCard,
                      {
                        backgroundColor: item.isRead ? 'transparent' : theme.accentSoft,
                        borderColor: theme.border,
                      },
                    ]}
                  >
                    <View style={[styles.itemHeader, isRtlMode && styles.rtlRow]}>
                      <View style={[styles.iconBubble, { backgroundColor: iconInfo.bg }]}>
                        <Ionicons name={iconInfo.name as any} size={16} color={iconInfo.color} />
                      </View>
                      <View style={{ flex: 1, marginHorizontal: 8 }}>
                        <Text
                          style={[
                            styles.itemTitle,
                            { color: theme.text, fontWeight: item.isRead ? '600' : '700' },
                          ]}
                        >
                          {item.title}
                        </Text>
                        <Text style={[styles.itemTime, { color: theme.textMuted }]}>
                          {formatTimeAgo(item.createdAt)}
                        </Text>
                      </View>
                      {!item.isRead && (
                        <View style={[styles.unreadDot, { backgroundColor: theme.brand }]} />
                      )}
                    </View>
                    <Text style={[styles.itemBody, { color: theme.textSoft }]}>{item.body}</Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          )}
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
    maxHeight: '80%',
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
  badge: {
    paddingHorizontal: 7,
    paddingVertical: 2,
    borderRadius: RADIUS.pill,
  },
  badgeText: {
    color: '#fff',
    fontSize: 11,
    fontWeight: 'bold',
  },
  closeBtn: {
    padding: 6,
  },
  loadingWrap: {
    paddingVertical: 40,
    alignItems: 'center',
  },
  emptyWrap: {
    paddingVertical: 40,
    alignItems: 'center',
    gap: 12,
  },
  emptyText: {
    fontSize: 14,
    textAlign: 'center',
  },
  itemCard: {
    padding: 12,
    borderRadius: RADIUS.lg,
    borderWidth: 1,
    marginBottom: 10,
  },
  itemHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  iconBubble: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  itemTitle: {
    fontSize: 14,
  },
  itemTime: {
    fontSize: 11,
    marginTop: 2,
  },
  unreadDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  itemBody: {
    fontSize: 13,
    marginTop: 6,
    lineHeight: 18,
  },
});
