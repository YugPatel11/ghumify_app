export type Category =
  | 'tourist'
  | 'food'
  | 'market'
  | 'culture'
  | 'nature'
  | 'hidden';

export type LangCode =
  | 'en'
  | 'hi'
  | 'gu'
  | 'mr'
  | 'bn'
  | 'ta'
  | 'te'
  | 'kn'
  | 'ml'
  | 'pa';

export interface OpeningHours {
  open: string; // "09:00"
  close: string; // "18:00"
  closedDays?: number[]; // 0 = Sunday
  note?: string;
}

export interface PlaceEvent {
  name: string;
  time: string;
  description: string;
}

export interface NearbyAttraction {
  name: string;
  distance: string;
  type: string;
}

export interface Place {
  id: string;
  name: string;
  cityId: string;
  category: Category;
  subcategory: string;
  shortDesc: string;
  description: string;
  history: string;
  facts: string[];
  address: string;
  timings: OpeningHours;
  entryFee: string;
  bestTime: string;
  whatToCarry: string[];
  nearby: NearbyAttraction[];
  rating: number;
  durationMin: number;
  distanceKm: number;
  gradient: keyof typeof import('./theme').GRADIENTS;
  icon: string; // Ionicons name
  tags: string[];
  events?: PlaceEvent[];
  mustTry?: string[]; // for food places
  isOutdoor: boolean;
}

export interface Stay {
  id: string;
  name: string;
  cityId: string;
  type: 'Luxury' | 'Premium' | 'Mid-Range' | 'Budget' | 'Dharamshala' | 'Hostel';
  pricePerNight: number;
  rating: number;
  address: string;
  amenities: string[];
  description: string;
  distanceKm: number;
  gradient: keyof typeof import('./theme').GRADIENTS;
}

export interface City {
  id: string;
  name: string;
  state: string;
  tagline: string;
  description: string;
  gradient: keyof typeof import('./theme').GRADIENTS;
  currentWeather: WeatherInfo;
}

export interface WeatherInfo {
  tempC: number;
  condition: 'sunny' | 'cloudy' | 'rainy' | 'partly-cloudy';
  conditionText: string;
  highC: number;
  lowC: number;
  humidity: number;
  rainChance: number;
  uvIndex: number;
  hourly: { time: string; tempC: number; condition: WeatherInfo['condition'] }[];
}

export interface ItineraryStop {
  id: string;
  startTime: string;
  endTime: string;
  type: 'visit' | 'travel' | 'meal' | 'event';
  title: string;
  subtitle: string;
  placeId?: string;
  category?: Category;
  durationMin: number;
  gradient: keyof typeof import('./theme').GRADIENTS;
  icon: string;
  note?: string;
  distanceKm?: number;
}

export interface Itinerary {
  cityId: string;
  cityName: string;
  date: string;
  startTime: string;
  endTime: string;
  stops: ItineraryStop[];
  weather: WeatherInfo;
  tips: string[];
  totalDistanceKm: number;
}

export interface TranslationPhrase {
  id: string;
  category: string;
  english: string;
  transliteration?: Record<LangCode, string>;
  translations: Record<LangCode, string>;
}
