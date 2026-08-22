import React from 'react';
import { useFonts } from 'expo-font';
import Ionicons from '@expo/vector-icons/Ionicons';
import { NavigationContainer, DefaultTheme, DarkTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'expo-status-bar';
import { useColorScheme, StyleSheet, Text } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

import { AppProvider, useApp } from './lib/AppContext';
import { PALETTE } from './lib/theme';
import { t } from './lib/i18n';

import HomeScreen from './screens/HomeScreen';
import PlanResultScreen from './screens/PlanResultScreen';
import ExploreScreen from './screens/ExploreScreen';
import PlaceDetailScreen from './screens/PlaceDetailScreen';
import TranslateScreen from './screens/TranslateScreen';
import StaysScreen from './screens/StaysScreen';
import SettingsScreen from './screens/SettingsScreen';

export type RootStackParamList = {
  Tabs: undefined;
  PlanResult: { cityName: string; hours: number; interests: string[]; startTime: string };
  PlaceDetail: { placeId: string };
  Settings: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator();

function TabIcon({ name, color, size }: { name: string; color: string; size: number }) {
  return <Ionicons name={name as any} size={size} color={color} />;
}

function MainTabs() {
  const { theme, t: tr } = useApp();
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: theme.brand,
        tabBarInactiveTintColor: theme.textMuted,
        tabBarStyle: {
          backgroundColor: theme.card,
          borderTopColor: theme.border,
          borderTopWidth: 1,
          height: 64,
          paddingBottom: 8,
          paddingTop: 8,
        },
        tabBarLabelStyle: { fontSize: 11, fontWeight: '700', marginTop: 2 },
        tabBarIconStyle: { marginBottom: 0 },
      }}
    >
      <Tab.Screen
        name="PlanTab"
        component={HomeScreen}
        options={{
          tabBarLabel: tr('plan'),
          tabBarIcon: ({ color, size }) => <TabIcon name="sparkles" color={color} size={22} />,
        }}
      />
      <Tab.Screen
        name="ExploreTab"
        component={ExploreScreen}
        options={{
          tabBarLabel: tr('explore'),
          tabBarIcon: ({ color, size }) => <TabIcon name="compass" color={color} size={22} />,
        }}
      />
      <Tab.Screen
        name="TranslateTab"
        component={TranslateScreen}
        options={{
          tabBarLabel: tr('translate'),
          tabBarIcon: ({ color, size }) => <TabIcon name="language" color={color} size={22} />,
        }}
      />
      <Tab.Screen
        name="StaysTab"
        component={StaysScreen}
        options={{
          tabBarLabel: tr('stays'),
          tabBarIcon: ({ color, size }) => <TabIcon name="bed" color={color} size={22} />,
        }}
      />
    </Tab.Navigator>
  );
}

function RootNavigator() {
  const { theme } = useApp();
  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: theme.bg },
      }}
    >
      <Stack.Screen name="Tabs" component={MainTabs} />
      <Stack.Screen name="PlanResult" component={PlanResultScreen} options={{ presentation: 'card' }} />
      <Stack.Screen name="PlaceDetail" component={PlaceDetailScreen} options={{ presentation: 'card' }} />
      <Stack.Screen name="Settings" component={SettingsScreen} options={{ presentation: 'modal' }} />
    </Stack.Navigator>
  );
}

function AppContent() {
  const scheme = useColorScheme();
  const { theme } = useApp();
  const navTheme = scheme === 'dark'
    ? { ...DarkTheme, colors: { ...DarkTheme.colors, background: theme.bg, card: theme.card, text: theme.text, border: theme.border, primary: theme.brand } }
    : { ...DefaultTheme, colors: { ...DefaultTheme.colors, background: theme.bg, card: theme.card, text: theme.text, border: theme.border, primary: theme.brand } };

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <NavigationContainer theme={navTheme as any}>
        <RootNavigator />
        <StatusBar style={scheme === 'dark' ? 'light' : 'dark'} />
      </NavigationContainer>
    </GestureHandlerRootView>
  );
}

export default function App() {
  const [fontsLoaded] = useFonts({ ...Ionicons.font });

  if (!fontsLoaded) {
    return null;
  }

  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
}
