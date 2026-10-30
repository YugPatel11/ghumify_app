import { useState, useRef, useEffect, useCallback } from 'react';
import { Platform } from 'react-native';
import { getSpeechLocale } from './speechUtils';

export type SpeechState =
  | 'idle'
  | 'requesting'
  | 'listening'
  | 'processing'
  | 'error'
  | 'unsupported';

export interface UseSpeechToTextOptions {
  language?: string;
  autoStopMs?: number;
  onInterimResult?: (interim: string) => void;
  onFinalResult?: (finalText: string) => void;
  onError?: (errorMessage: string) => void;
}

const BACKEND_URL = Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

export function useSpeechToText(options: UseSpeechToTextOptions = {}) {
  const {
    language = 'en',
    autoStopMs = 2800,
    onInterimResult,
    onFinalResult,
    onError,
  } = options;

  const [state, setState] = useState<SpeechState>('idle');
  const [transcript, setTranscript] = useState('');
  const [interimText, setInterimText] = useState('');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const recognitionRef = useRef<any>(null);
  const mediaRecorderRef = useRef<any>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const streamRef = useRef<MediaStream | null>(null);
  const silenceTimerRef = useRef<any>(null);
  const activeLangRef = useRef(language);
  activeLangRef.current = language;

  // Feature detection
  const isWeb = Platform.OS === 'web' && typeof window !== 'undefined';
  const hasWebSpeech = isWeb && Boolean((window as any).SpeechRecognition || (window as any).webkitSpeechRecognition);
  const hasMediaRecorder = isWeb && Boolean(window.navigator?.mediaDevices?.getUserMedia && (window as any).MediaRecorder);

  const stopTracks = useCallback(() => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
  }, []);

  const resetSilenceTimer = useCallback(() => {
    if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
    silenceTimerRef.current = setTimeout(() => {
      stopListening();
    }, autoStopMs);
  }, [autoStopMs]);

  // Clean up on unmount
  useEffect(() => {
    return () => {
      if (recognitionRef.current) {
        try { recognitionRef.current.abort(); } catch {}
      }
      if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'recording') {
        try { mediaRecorderRef.current.stop(); } catch {}
      }
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      stopTracks();
    };
  }, [stopTracks]);

  // Tier 1: Web Speech Recognition
  const startTier1 = useCallback((locale: string) => {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    const recognition = new SpeechRecognition();
    recognition.lang = locale;
    recognition.interimResults = true;
    recognition.continuous = false;

    recognition.onstart = () => {
      setState('listening');
      resetSilenceTimer();
    };

    recognition.onresult = (event: any) => {
      resetSilenceTimer();
      let interim = '';
      let final = '';

      for (let i = event.resultIndex; i < event.results.length; ++i) {
        if (event.results[i].isFinal) {
          final += event.results[i][0].transcript;
        } else {
          interim += event.results[i][0].transcript;
        }
      }

      if (interim) {
        setInterimText(interim);
        onInterimResult?.(interim);
      }

      if (final) {
        setTranscript((prev) => (prev ? `${prev} ${final.trim()}` : final.trim()));
        setInterimText('');
        onFinalResult?.(final.trim());
      }
    };

    recognition.onerror = (event: any) => {
      console.warn('[WebSpeech] Recognition error:', event.error);
      if (event.error === 'not-allowed') {
        setState('error');
        setErrorMessage('Microphone access was denied. Please allow microphone permissions.');
        onError?.('Microphone permission denied.');
      } else {
        // Fall back to Tier 2 (Server-side STT)
        startTier2();
      }
    };

    recognition.onend = () => {
      setState('idle');
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
    };

    recognitionRef.current = recognition;
    recognition.start();
  }, [resetSilenceTimer, onInterimResult, onFinalResult, onError]);

  // Tier 2: Server-side MediaRecorder capture & transcribe API
  const startTier2 = useCallback(async () => {
    if (!hasMediaRecorder) {
      setState('unsupported');
      setErrorMessage('Speech recording is not supported on this device/browser.');
      return;
    }

    try {
      setState('requesting');
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      const mimeType = (window as any).MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm';

      const recorder = new (window as any).MediaRecorder(stream, { mimeType });
      audioChunksRef.current = [];

      recorder.ondataavailable = (e: any) => {
        if (e.data && e.data.size > 0) {
          audioChunksRef.current.push(e.data);
        }
      };

      recorder.onstart = () => {
        setState('listening');
        resetSilenceTimer();
      };

      recorder.onstop = async () => {
        setState('processing');
        stopTracks();
        if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);

        const audioBlob = new Blob(audioChunksRef.current, { type: mimeType });
        if (audioBlob.size === 0) {
          setState('idle');
          return;
        }

        try {
          const formData = new FormData();
          formData.append('audio', audioBlob, 'speech.webm');
          formData.append('language', activeLangRef.current);

          const res = await fetch(`${BACKEND_URL}/api/v1/speech/transcribe`, {
            method: 'POST',
            headers: { 'x-user-id': 'user_demo' },
            body: formData,
          });

          if (!res.ok) {
            const err = await res.json().catch(() => ({}));
            throw new Error(err.error || 'Server transcription failed');
          }

          const data = await res.json();
          if (data.text) {
            setTranscript((prev) => (prev ? `${prev} ${data.text}` : data.text));
            onFinalResult?.(data.text);
          }
          setState('idle');
        } catch (err: any) {
          setState('error');
          setErrorMessage(err.message || 'Transcription error.');
          onError?.(err.message);
        }
      };

      mediaRecorderRef.current = recorder;
      recorder.start(250);
    } catch (err: any) {
      setState('error');
      setErrorMessage(err.message || 'Microphone permission denied.');
      onError?.(err.message);
      stopTracks();
    }
  }, [hasMediaRecorder, resetSilenceTimer, stopTracks, onFinalResult, onError]);

  const startListening = useCallback(async () => {
    setErrorMessage(null);
    setInterimText('');

    if (!isWeb) {
      // Non-web or unsupported context
      setState('unsupported');
      setErrorMessage('Speech recognition is available on modern web and mobile browsers.');
      return;
    }

    const locale = getSpeechLocale(activeLangRef.current);

    if (hasWebSpeech) {
      try {
        startTier1(locale);
      } catch {
        startTier2();
      }
    } else if (hasMediaRecorder) {
      startTier2();
    } else {
      setState('unsupported');
      setErrorMessage('Audio recording is not supported in this browser.');
    }
  }, [isWeb, hasWebSpeech, hasMediaRecorder, startTier1, startTier2]);

  const stopListening = useCallback(() => {
    if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);

    if (recognitionRef.current) {
      try { recognitionRef.current.stop(); } catch {}
    }
    if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'recording') {
      try { mediaRecorderRef.current.stop(); } catch {}
    }
    stopTracks();
  }, [stopTracks]);

  const cancelListening = useCallback(() => {
    if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
    if (recognitionRef.current) {
      try { recognitionRef.current.abort(); } catch {}
    }
    if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'recording') {
      try { mediaRecorderRef.current.stop(); } catch {}
    }
    audioChunksRef.current = [];
    setInterimText('');
    setState('idle');
    stopTracks();
  }, [stopTracks]);

  return {
    state,
    isListening: state === 'listening',
    isProcessing: state === 'processing',
    transcript,
    interimText,
    errorMessage,
    startListening,
    stopListening,
    cancelListening,
    setTranscript,
  };
}
