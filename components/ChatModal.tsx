import React, { useState, useRef, useEffect } from 'react';
import {
  ActivityIndicator,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Ionicons from '@expo/vector-icons/Ionicons';
import { useApp } from '../lib/AppContext';
import { useSpeechToText } from '../lib/useSpeechToText';
import MicButton from './MicButton';
import { LANGUAGES } from '../lib/i18n';
import { RADIUS, shadow } from '../lib/theme';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  timestamp: string;
}

interface ChatModalProps {
  visible: boolean;
  onClose: () => void;
  context?: { cityName?: string; hours?: number };
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export default function ChatModal({ visible, onClose, context }: ChatModalProps) {
  const { theme, lang, t: tr, isRtlMode } = useApp();
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 'welcome',
      role: 'assistant',
      text: tr('chat.welcome') || `Hello! I'm Ghumify AI. Ask me anything about places, local street food, markets, or travel tips!`,
      timestamp: 'Just now',
    },
  ]);
  const [inputText, setInputText] = useState('');
  const [sessionLang, setSessionLang] = useState(lang);
  const [autoSend, setAutoSend] = useState(false);
  const [loading, setLoading] = useState(false);
  const [showLangPicker, setShowLangPicker] = useState(false);
  const listRef = useRef<FlatList>(null);

  // Load auto-send preference
  useEffect(() => {
    (async () => {
      const saved = await AsyncStorage.getItem('ghumify_chat_autosend');
      if (saved !== null) setAutoSend(saved === 'true');
    })();
  }, []);

  const toggleAutoSend = async () => {
    const next = !autoSend;
    setAutoSend(next);
    await AsyncStorage.setItem('ghumify_chat_autosend', String(next));
  };

  const handleSendMessage = async (textToSend?: string) => {
    const content = (textToSend || inputText).trim();
    if (!content || loading) return;

    const userMsg: Message = {
      id: `u_${Date.now()}`,
      role: 'user',
      text: content,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInputText('');
    setLoading(true);

    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'user_demo',
          'x-language': sessionLang,
        },
        body: JSON.stringify({
          message: content,
          history: messages.slice(-6).map((m) => ({ role: m.role, text: m.text })),
          context,
          language: sessionLang,
        }),
      });

      const data = await res.json();
      const assistantMsg: Message = {
        id: `a_${Date.now()}`,
        role: 'assistant',
        text: data.response || 'I am ready to help you plan your journey!',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      };
      setMessages((prev) => [...prev, assistantMsg]);
    } catch {
      setMessages((prev) => [
        ...prev,
        {
          id: `err_${Date.now()}`,
          role: 'assistant',
          text: 'Sorry, I had trouble connecting. Please try again.',
          timestamp: 'Just now',
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  // Speech to Text integration
  const speech = useSpeechToText({
    language: sessionLang,
    onInterimResult: (interim) => {
      // Keep user's typed text intact, append interim visually
    },
    onFinalResult: (finalText) => {
      setInputText((prev) => {
        const updated = prev ? `${prev} ${finalText}` : finalText;
        if (autoSend) {
          setTimeout(() => handleSendMessage(updated), 200);
        }
        return updated;
      });
    },
  });

  if (!visible) return null;

  const currentLangInfo = LANGUAGES.find((l) => l.code === sessionLang) || LANGUAGES[0];

  return (
    <View style={styles.modalOverlay}>
      <Pressable style={styles.backdrop} onPress={onClose} />
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={[styles.sheetContainer, { backgroundColor: theme.card }]}
      >
        {/* Header Bar */}
        <View style={[styles.headerRow, isRtlMode && styles.rtlRow]}>
          <View style={styles.headerTitleWrap}>
            <View style={[styles.avatar, { backgroundColor: theme.brandSoft }]}>
              <Ionicons name="sparkles" size={18} color={theme.brand} />
            </View>
            <View>
              <Text style={[styles.title, { color: theme.text }]}>Ghumify AI</Text>
              <Text style={[styles.subtitle, { color: theme.textMuted }]}>
                {context?.cityName ? `Exploring ${context.cityName}` : 'Your Travel Guide'}
              </Text>
            </View>
          </View>

          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
            {/* Auto-send toggle */}
            <Pressable
              onPress={toggleAutoSend}
              style={[styles.toggleBtn, autoSend && { backgroundColor: theme.brandSoft }]}
              accessibilityLabel="Auto-send after speaking"
            >
              <Ionicons
                name={autoSend ? 'flash' : 'flash-outline'}
                size={16}
                color={autoSend ? theme.brand : theme.textMuted}
              />
            </Pressable>

            {/* Session Speech Language selector chip */}
            <Pressable
              onPress={() => setShowLangPicker(!showLangPicker)}
              style={[styles.langChip, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}
              accessibilityLabel={`Speech language: ${currentLangInfo.name}`}
            >
              <Text style={styles.langFlag}>{currentLangInfo.flag}</Text>
              <Text style={[styles.langCode, { color: theme.text }]}>{currentLangInfo.code.toUpperCase()}</Text>
              <Ionicons name="chevron-down" size={12} color={theme.textMuted} />
            </Pressable>

            {/* Close button */}
            <Pressable onPress={onClose} style={styles.closeBtn}>
              <Ionicons name="close" size={22} color={theme.text} />
            </Pressable>
          </View>
        </View>

        {/* Dropdown Language Picker */}
        {showLangPicker && (
          <View style={[styles.langDropdown, { backgroundColor: theme.cardAlt, borderColor: theme.border }]}>
            <Text style={[styles.dropdownTitle, { color: theme.textMuted }]}>Session Speech Language</Text>
            <FlatList
              data={LANGUAGES}
              horizontal
              showsHorizontalScrollIndicator={false}
              keyExtractor={(item) => item.code}
              renderItem={({ item }) => (
                <Pressable
                  onPress={() => {
                    setSessionLang(item.code);
                    setShowLangPicker(false);
                  }}
                  style={[
                    styles.pickerItem,
                    sessionLang === item.code && { backgroundColor: theme.brand, borderColor: theme.brand },
                  ]}
                >
                  <Text style={styles.pickerItemText}>
                    {item.flag} {item.nativeName}
                  </Text>
                </Pressable>
              )}
            />
          </View>
        )}

        {/* Messages List */}
        <FlatList
          ref={listRef}
          data={messages}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ padding: 16, paddingBottom: 20 }}
          onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
          renderItem={({ item }) => {
            const isUser = item.role === 'user';
            return (
              <View
                style={[
                  styles.msgRow,
                  isUser ? styles.msgRowUser : styles.msgRowAssistant,
                  isRtlMode && styles.rtlRow,
                ]}
              >
                {!isUser && (
                  <View style={[styles.msgAvatar, { backgroundColor: theme.brandSoft }]}>
                    <Ionicons name="sparkles" size={14} color={theme.brand} />
                  </View>
                )}
                <View
                  style={[
                    styles.bubble,
                    isUser
                      ? { backgroundColor: theme.brand }
                      : { backgroundColor: theme.cardAlt, borderColor: theme.border, borderWidth: 1 },
                  ]}
                >
                  <Text style={[styles.bubbleText, { color: isUser ? '#fff' : theme.text }]}>
                    {item.text}
                  </Text>
                  <Text style={[styles.msgTime, { color: isUser ? 'rgba(255,255,255,0.7)' : theme.textMuted }]}>
                    {item.timestamp}
                  </Text>
                </View>
              </View>
            );
          }}
          ListFooterComponent={
            loading ? (
              <View style={[styles.loadingRow, isRtlMode && styles.rtlRow]}>
                <ActivityIndicator size="small" color={theme.brand} />
                <Text style={[styles.loadingText, { color: theme.textMuted }]}>Ghumify AI is thinking...</Text>
              </View>
            ) : null
          }
        />

        {/* Live Interim Transcript Bubble */}
        {speech.isListening && (
          <View style={[styles.interimBanner, { backgroundColor: '#ef444415', borderColor: '#ef4444' }]}>
            <View style={styles.listeningDot} />
            <Text style={[styles.interimText, { color: theme.text }]}>
              {speech.interimText || 'Listening... Speak now'}
            </Text>
            <Pressable onPress={speech.cancelListening} style={{ padding: 4 }}>
              <Ionicons name="close-circle" size={16} color="#ef4444" />
            </Pressable>
          </View>
        )}

        {/* Input Bar */}
        <View style={[styles.inputBar, { borderTopColor: theme.border }, isRtlMode && styles.rtlRow]}>
          <TextInput
            value={inputText}
            onChangeText={setInputText}
            placeholder={speech.isListening ? 'Listening...' : 'Type or speak a message...'}
            placeholderTextColor={theme.textMuted}
            style={[styles.input, { color: theme.text }, isRtlMode && styles.rtlText]}
            multiline
            maxLength={500}
            returnKeyType="send"
            onSubmitEditing={() => handleSendMessage()}
          />

          {/* Reusable MicButton */}
          <MicButton
            state={speech.state}
            onPress={() => {
              if (speech.isListening) speech.stopListening();
              else speech.startListening();
            }}
            onCancel={speech.cancelListening}
            size={38}
          />

          {/* Send Button */}
          <Pressable
            onPress={() => handleSendMessage()}
            disabled={!inputText.trim() || loading}
            style={({ pressed }) => [
              styles.sendBtn,
              { backgroundColor: inputText.trim() ? theme.brand : theme.cardAlt },
              pressed && { opacity: 0.8 },
            ]}
          >
            <Ionicons
              name={isRtlMode ? 'send' : 'send'}
              size={18}
              color={inputText.trim() ? '#fff' : theme.textMuted}
            />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  modalOverlay: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    right: 0,
    zIndex: 9999,
  },
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  sheetContainer: {
    height: '75%',
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    overflow: 'hidden',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(0,0,0,0.06)',
  },
  headerTitleWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 16,
    fontWeight: '800',
  },
  subtitle: {
    fontSize: 11,
  },
  toggleBtn: {
    padding: 6,
    borderRadius: 8,
  },
  langChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    borderWidth: 1,
    borderRadius: 14,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  langFlag: {
    fontSize: 13,
  },
  langCode: {
    fontSize: 11,
    fontWeight: '700',
  },
  closeBtn: {
    padding: 4,
  },
  langDropdown: {
    padding: 10,
    borderBottomWidth: 1,
  },
  dropdownTitle: {
    fontSize: 11,
    fontWeight: '600',
    marginBottom: 6,
  },
  pickerItem: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#ddd',
    marginRight: 6,
  },
  pickerItemText: {
    fontSize: 12,
    fontWeight: '600',
  },
  msgRow: {
    flexDirection: 'row',
    marginBottom: 12,
    alignItems: 'flex-end',
    gap: 8,
  },
  msgRowUser: {
    justifyContent: 'flex-end',
  },
  msgRowAssistant: {
    justifyContent: 'flex-start',
  },
  msgAvatar: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bubble: {
    maxWidth: '80%',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: RADIUS.lg,
  },
  bubbleText: {
    fontSize: 14,
    lineHeight: 20,
  },
  msgTime: {
    fontSize: 10,
    marginTop: 4,
    textAlign: 'right',
  },
  loadingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 8,
  },
  loadingText: {
    fontSize: 12,
  },
  interimBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderTopWidth: 1,
    gap: 8,
  },
  listeningDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#ef4444',
  },
  interimText: {
    flex: 1,
    fontSize: 13,
    fontStyle: 'italic',
  },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderTopWidth: 1,
    gap: 8,
  },
  input: {
    flex: 1,
    maxHeight: 100,
    fontSize: 14,
    paddingHorizontal: 8,
    paddingVertical: 6,
  },
  sendBtn: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rtlRow: {
    flexDirection: 'row-reverse',
  },
  rtlText: {
    textAlign: 'right',
  },
});
