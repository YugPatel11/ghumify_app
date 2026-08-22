import { useColorScheme } from 'react-native';

/** Ghumify Design System
 *  Classy Indian-inspired palette: deep indigo + saffron gold
 */

export const PALETTE = {
  indigo: '#3B2DE0',
  indigoDeep: '#241B6B',
  indigoDarkest: '#16113B',
  saffron: '#F5930B',
  saffronLight: '#FFB938',
  saffronDark: '#D97706',
  cherry: '#E63946',
  cherryDark: '#C1121F',
  cherryLight: '#FF6B7A',
  teal: '#0DA98E',
  tealDark: '#0B7A66',
  rose: '#E8559E',
  plum: '#7C3AED',
  white: '#FFFFFF',
  cream: '#FBF8F3',
  ink: '#1A1733',
};

export interface Theme {
  mode: 'light' | 'dark';
  bg: string;
  bgElevated: string;
  card: string;
  cardAlt: string;
  text: string;
  textSoft: string;
  textMuted: string;
  border: string;
  brand: string;
  brandDeep: string;
  brandSoft: string;
  accent: string;
  accentSoft: string;
  teal: string;
  tealSoft: string;
  rose: string;
  roseSoft: string;
  plum: string;
  plumSoft: string;
  danger: string;
  success: string;
  warning: string;
}

export const light: Theme = {
  mode: 'light',
  bg: '#F4F2FD',
  bgElevated: '#FFFFFF',
  card: '#FFFFFF',
  cardAlt: '#F8F7FF',
  text: '#1A1733',
  textSoft: '#5C567A',
  textMuted: '#9089B0',
  border: '#ECE7FB',
  brand: PALETTE.indigo,
  brandDeep: PALETTE.indigoDeep,
  brandSoft: '#EEEBFF',
  accent: PALETTE.cherry,
  accentSoft: '#FFE5E7',
  teal: PALETTE.teal,
  tealSoft: '#DDF6F1',
  rose: PALETTE.rose,
  roseSoft: '#FCE7F2',
  plum: PALETTE.plum,
  plumSoft: '#F1E8FF',
  danger: '#E5484D',
  success: '#12B886',
  warning: PALETTE.saffronDark,
};

export const dark: Theme = {
  mode: 'dark',
  bg: '#100D27',
  bgElevated: '#181438',
  card: '#1E1A45',
  cardAlt: '#252055',
  text: '#F4F2FF',
  textSoft: '#B4ADD9',
  textMuted: '#817CB0',
  border: '#2E2A5C',
  brand: '#7C6FFF',
  brandDeep: '#5C4FE0',
  brandSoft: '#2A2560',
  accent: PALETTE.cherryLight,
  accentSoft: '#3D1819',
  teal: '#2DD4B5',
  tealSoft: '#103A33',
  rose: '#F086C9',
  roseSoft: '#3D2040',
  plum: '#B69BFF',
  plumSoft: '#2D2055',
  danger: '#FF6B6E',
  success: '#22D3A0',
  warning: PALETTE.saffronLight,
};

export function useTheme(): Theme {
  const scheme = useColorScheme();
  return scheme === 'dark' ? dark : light;
}

export const GRADIENTS: Record<string, [string, string, string]> = {
  indigo: ['#3B2DE0', '#6C4FE6', '#9B7CFF'],
  saffron: ['#F5930B', '#FF7A18', '#FF9D4D'],
  teal: ['#0DA98E', '#10B981', '#34D399'],
  rose: ['#E8559E', '#F472B6', '#FB7FC4'],
  plum: ['#7C3AED', '#9D5CFF', '#B988FF'],
  sunset: ['#FF6B6B', '#F5930B', '#FFD93D'],
  ocean: ['#2563EB', '#0EA5E9', '#06B6D4'],
  forest: ['#059669', '#10B981', '#6EE7B7'],
  cherry: ['#E63946', '#FF6B7A', '#FF9BAC'],
  crimson: ['#C1121F', '#E63946', '#FF6B7A'],
};

export const SPACING = {
  xs: 4,
  sm: 8,
  md: 14,
  lg: 20,
  xl: 28,
  xxl: 36,
};

export const RADIUS = {
  sm: 10,
  md: 16,
  lg: 22,
  xl: 28,
  pill: 999,
};

export function shadow(theme: Theme, level: 1 | 2 | 3 = 1) {
  if (theme.mode === 'dark') {
    return {
      shadowColor: '#000000',
      shadowOffset: { width: 0, height: level * 2 },
      shadowOpacity: 0.4,
      shadowRadius: level * 4,
      elevation: level * 3,
    };
  }
  return {
    shadowColor: PALETTE.cherryDark,
    shadowOffset: { width: 0, height: level * 2 },
    shadowOpacity: 0.10 + level * 0.04,
    shadowRadius: level * 5,
    elevation: level * 2,
  };
}
