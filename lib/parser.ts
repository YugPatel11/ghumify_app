import { Category, City, Place, Stay, WeatherInfo } from './types';
import { GRADIENTS } from './theme';
import { PLACES, STAYS } from './data';

// ─── Default weather for generic cities ───────────────────────
export const defaultWeather: WeatherInfo = {
  tempC: 26,
  condition: 'partly-cloudy',
  conditionText: 'Pleasant',
  highC: 29,
  lowC: 20,
  humidity: 55,
  rainChance: 15,
  uvIndex: 6,
  hourly: [
    { time: '09 AM', tempC: 23, condition: 'sunny' },
    { time: '11 AM', tempC: 26, condition: 'sunny' },
    { time: '1 PM', tempC: 28, condition: 'partly-cloudy' },
    { time: '3 PM', tempC: 29, condition: 'partly-cloudy' },
    { time: '5 PM', tempC: 27, condition: 'cloudy' },
    { time: '7 PM', tempC: 24, condition: 'cloudy' },
  ],
};

// ─── Natural Language Parser ───────────────────────────────────
// Extracts hours, start time, interests, and city from free text.

export interface ParsedTrip {
  cityName: string;
  cityId: string;
  isKnownCity: boolean;
  city: City;
  hours: number;
  startTime: string;
  interests: Category[];
  rawLocation: string;
  rawDescription: string;
}

const INTEREST_KEYWORDS: { category: Category; pattern: RegExp }[] = [
  { category: 'food', pattern: /\b(food|eat|cuisine|restaurant|dish|hungry|meal|breakfast|lunch|dinner|snack|street\s*food|culinary|flavour|flavor|tast)\b/i },
  { category: 'market', pattern: /\b(market|shop|shopping|bazaar|bazar|buy|souvenir|store|stall|craft|handicraft)\b/i },
  { category: 'culture', pattern: /\b(temple|god|prayer|worship|spiritual|religious|church|mosque|gurdwara|gurudwara|aarti|puja|cathedral|synagogue|faith|sacred)\b/i },
  { category: 'tourist', pattern: /\b(famous|popular|tourist|sightsee|monument|landmark|attraction|visit|see|explore|fort|palace|museum|heritage|history|historical|ancient|architecture|castle|tower|statue)\b/i },
  { category: 'nature', pattern: /\b(nature|park|garden|beach|mountain|trek|hike|waterfall|lake|river|outdoor|scenic|view|sunset|sunrise|hill|valley|forest)\b/i },
  { category: 'hidden', pattern: /\b(hidden|secret|gem|offbeat|less\s*known|unexplored|quirky|underground|lesser)\b/i },
];

export function parseHours(text: string): number {
  const match = text.match(/(\d+)\s*(?:hours?|hrs?|h\b)/i);
  if (match) return Math.min(24, Math.max(1, parseInt(match[1])));
  // Also try "half day" = 6, "full day" = 12
  if (/full\s*day/i.test(text)) return 12;
  if (/half\s*day/i.test(text)) return 6;
  if (/morning/i.test(text) && /evening|night/i.test(text)) return 10;
  if (/morning/i.test(text)) return 4;
  if (/evening|night/i.test(text)) return 4;
  return 6; // default
}

export function parseStartTime(text: string): string | null {
  // Match "10 AM", "2 PM", "10:00", "from 10", "starting at 3pm", "at 9"
  const match = text.match(/(?:from|starting(?:\s+at)?|at|@|begin|around)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m|p\.m)?/i);
  if (match) {
    let h = parseInt(match[1]);
    const m = match[2] ? parseInt(match[2]) : 0;
    const period = match[3]?.toLowerCase().replace(/\./g, '');
    if (period === 'pm' && h < 12) h += 12;
    if (period === 'am' && h === 12) h = 0;
    if (h >= 0 && h <= 23) {
      return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
    }
  }
  // Also match standalone "10am" or "2pm"
  const simple = text.match(/\b(\d{1,2})(am|pm|a\.m|p\.m)\b/i);
  if (simple) {
    let h = parseInt(simple[1]);
    const period = simple[2].toLowerCase().replace(/\./g, '');
    if (period === 'pm' && h < 12) h += 12;
    if (period === 'am' && h === 12) h = 0;
    if (h >= 0 && h <= 23) return `${String(h).padStart(2, '0')}:00`;
  }
  return null;
}

export function parseInterests(text: string): Category[] {
  const interests = new Set<Category>();
  for (const { category, pattern } of INTEREST_KEYWORDS) {
    if (pattern.test(text)) interests.add(category);
  }
  if (interests.size === 0) return ['tourist', 'food'];
  return Array.from(interests);
}

export function matchCity(text: string, cities: City[]): City | null {
  const lower = text.toLowerCase().trim();
  // Exact match first
  for (const city of cities) {
    if (lower === city.name.toLowerCase()) return city;
  }
  // Contains match
  for (const city of cities) {
    if (lower.includes(city.name.toLowerCase())) return city;
  }
  // Fuzzy: check if any word in the text matches a city name
  const words = lower.split(/\s+/);
  for (const word of words) {
    for (const city of cities) {
      if (word.length > 2 && city.name.toLowerCase().includes(word)) return city;
    }
  }
  return null;
}

export function slugify(text: string): string {
  return text.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

// ─── Generic City / Place / Stay Generator ─────────────────────
// For cities not in our curated database, generate a city with
// plausible template places so the app works for ANY location.

function pickGradient(cityName: string): keyof typeof GRADIENTS {
  const gradients: (keyof typeof GRADIENTS)[] = ['cherry', 'crimson', 'sunset', 'ocean', 'plum', 'forest', 'indigo', 'saffron', 'rose', 'teal'];
  let hash = 0;
  for (let i = 0; i < cityName.length; i++) {
    hash = ((hash << 5) - hash) + cityName.charCodeAt(i);
    hash |= 0;
  }
  return gradients[Math.abs(hash) % gradients.length];
}

export function generateGenericCity(cityName: string): City {
  const slug = slugify(cityName);
  return {
    id: `gen-${slug}`,
    name: cityName,
    state: 'Explore',
    tagline: 'A destination to discover',
    description: `${cityName} is a wonderful destination with rich culture, fascinating attractions, delicious local cuisine, and hidden gems waiting to be explored. Let Ghumify craft the perfect plan for your visit.`,
    gradient: pickGradient(cityName),
    currentWeather: defaultWeather,
  };
}

export function generateGenericPlaces(cityName: string): Place[] {
  const slug = slugify(cityName);
  const baseId = `gen-${slug}`;
  const grad = pickGradient(cityName);

  const places: Place[] = [
    {
      id: `${baseId}-oldtown`,
      name: `${cityName} Old Town`,
      cityId: baseId,
      category: 'tourist',
      subcategory: 'Historic District',
      shortDesc: `The historic heart of ${cityName} with charming streets and architecture`,
      description: `Wander through the historic centre of ${cityName}, where centuries of history are etched into every cobblestone. The Old Town is a living museum of architecture, culture, and local life — perfect for photography, leisurely walks, and discovering hidden courtyards.`,
      history: `The Old Town of ${cityName} has been the cultural and commercial centre for centuries. Its narrow lanes and historic buildings tell the story of the city's evolution through different eras. Many of the structures showcase a blend of local and colonial architectural influences, reflecting the diverse cultures that have shaped this destination over the centuries.`,
      facts: [
        `The Old Town is the historic centre of ${cityName}`,
        'Features architecture spanning multiple centuries',
        'Home to artisan workshops and traditional craft shops',
        'Best explored on foot to appreciate the details',
        'Many hidden courtyards and alleys to discover',
      ],
      address: `Old Town, ${cityName}`,
      timings: { open: '09:00', close: '20:00', note: 'Open all days' },
      entryFee: 'Free',
      bestTime: 'Morning (9–11 AM) for fewer crowds and good light',
      whatToCarry: ['Comfortable walking shoes', 'Water bottle', 'Camera', 'Sun hat'],
      nearby: [
        { name: `${cityName} Central Market`, distance: '0.5 km', type: 'Market' },
        { name: `Local Food Street`, distance: '0.8 km', type: 'Food' },
      ],
      rating: 4.5,
      durationMin: 90,
      distanceKm: 1,
      gradient: grad,
      icon: 'business',
      tags: ['Historical', 'Architecture', 'Walking'],
      isOutdoor: true,
    },
    {
      id: `${baseId}-food`,
      name: `${cityName} Food Street`,
      cityId: baseId,
      category: 'food',
      subcategory: 'Local Food District',
      shortDesc: `The best of ${cityName}'s local cuisine and street food`,
      description: `Discover the culinary soul of ${cityName} at its most famous food district. From traditional local dishes to innovative street food, this is where the city's food culture comes alive. Sample regional specialities, enjoy the vibrant atmosphere, and experience flavours unique to ${cityName}.`,
      history: `Food has always been central to ${cityName}'s identity. The local food district grew organically around the old market area, where vendors have been serving traditional recipes for generations. Many of the dishes served here have roots in the region's agricultural heritage and cultural traditions, making every bite a taste of history.`,
      facts: [
        `The food capital of ${cityName}`,
        'Vendors have been serving here for generations',
        'Famous for regional specialities unique to the area',
        'Best visited during lunch and dinner hours',
        'A must for any food lover visiting the city',
      ],
      address: `Food Street, ${cityName}`,
      timings: { open: '08:00', close: '23:00', note: 'Open all days' },
      entryFee: 'Free',
      bestTime: 'Lunch (12 PM) or dinner (7 PM onwards)',
      whatToCarry: ['Cash', 'Hand sanitiser', 'Comfortable shoes', 'A big appetite!'],
      nearby: [{ name: `${cityName} Old Town`, distance: '0.8 km', type: 'Historic' }],
      rating: 4.6,
      durationMin: 60,
      distanceKm: 1.5,
      gradient: 'sunset',
      icon: 'fast-food',
      tags: ['Food', 'Street Food', 'Local Cuisine'],
      mustTry: [`Local specialty dish`, `Regional dessert`, `Famous street snack`, `Traditional beverage`],
      isOutdoor: false,
    },
    {
      id: `${baseId}-market`,
      name: `${cityName} Central Market`,
      cityId: baseId,
      category: 'market',
      subcategory: 'Shopping Market',
      shortDesc: `Bustling market for local crafts, souvenirs & more`,
      description: `The Central Market of ${cityName} is a vibrant bazaar where locals and visitors alike come to shop for everything from fresh produce and spices to handicrafts, textiles, and souvenirs. The colourful stalls and energetic atmosphere make it a must-visit cultural experience.`,
      history: `The market has been the commercial heart of ${cityName} for decades. Originally a traditional bazaar, it has evolved into a bustling hub while retaining its old-world charm. The vendors here represent generations of artisans and traders who have kept the local craft traditions alive. Bargaining is expected and part of the fun!`,
      facts: [
        `The main shopping hub of ${cityName}`,
        'Sells local handicrafts, textiles, spices & souvenirs',
        'Bargaining is expected and part of the experience',
        'Best visited in the afternoon and evening',
        'Generations of vendors with traditional craft expertise',
      ],
      address: `Central Market, ${cityName}`,
      timings: { open: '10:00', close: '21:00', note: 'Open all days' },
      entryFee: 'Free',
      bestTime: 'Afternoon & evening (4 PM–8 PM)',
      whatToCarry: ['Cash', 'Shopping bags', 'Bargaining skills', 'Comfortable shoes'],
      nearby: [{ name: `${cityName} Old Town`, distance: '0.5 km', type: 'Historic' }],
      rating: 4.3,
      durationMin: 75,
      distanceKm: 0.5,
      gradient: 'cherry',
      icon: 'cart',
      tags: ['Shopping', 'Market', 'Souvenirs', 'Handicrafts'],
      isOutdoor: true,
    },
    {
      id: `${baseId}-heritage`,
      name: `${cityName} Heritage Site`,
      cityId: baseId,
      category: 'culture',
      subcategory: 'Cultural Landmark',
      shortDesc: `A sacred and cultural landmark of ${cityName}`,
      description: `Visit one of ${cityName}'s most revered cultural landmarks, a site of deep spiritual and historical significance. The architecture, atmosphere, and traditions here offer a window into the soul of the city and its people. Whether you seek tranquillity, architectural beauty, or cultural immersion, this is a must-visit.`,
      history: `This heritage site has been a cornerstone of ${cityName}'s cultural identity for centuries. It has witnessed the city's growth through different eras and remains a living symbol of its traditions. The intricate architecture and spiritual ambience reflect the artistry and devotion of generations. Visitors are welcome to experience the peaceful atmosphere and learn about local traditions.`,
      facts: [
        `A cultural and spiritual landmark of ${cityName}`,
        'Architecture spanning multiple centuries',
        'A place of deep local significance',
        'Visitors are welcome to experience the atmosphere',
        'Photography may be restricted in certain areas',
      ],
      address: `Heritage Quarter, ${cityName}`,
      timings: { open: '06:00', close: '12:00', note: 'Evening: 4 PM–8 PM' },
      entryFee: 'Free',
      bestTime: 'Morning (6 AM) or evening (5 PM) for peaceful atmosphere',
      whatToCarry: ['Modest clothing', 'Water bottle', 'Offerings (optional)', 'Remove shoes at entrance'],
      nearby: [{ name: `${cityName} Old Town`, distance: '1.2 km', type: 'Historic' }],
      rating: 4.7,
      durationMin: 60,
      distanceKm: 2,
      gradient: 'saffron',
      icon: 'flower',
      tags: ['Culture', 'Heritage', 'Spiritual', 'Architecture'],
      events: [
        { name: 'Morning Ceremony', time: '07:00', description: 'Traditional morning ceremony with chanting and ritual — a deeply moving experience' },
      ],
      isOutdoor: false,
    },
    {
      id: `${baseId}-park`,
      name: `${cityName} Gardens`,
      cityId: baseId,
      category: 'nature',
      subcategory: 'Park & Gardens',
      shortDesc: `Scenic gardens and green space in ${cityName}`,
      description: `Escape the bustle of the city at ${cityName}'s most beautiful gardens. With manicured lawns, walking trails, fountains, and seasonal flowers, it's the perfect spot for a peaceful stroll, a picnic, or simply relaxing in nature. The gardens offer stunning views and a tranquil atmosphere.`,
      history: `The gardens were originally laid out as a retreat for the city's elite and have since become a beloved public space. The landscaping reflects both local and imported horticultural traditions, with native trees and ornamental plants creating a serene environment. The gardens have been carefully preserved and remain one of the city's most photographed locations.`,
      facts: [
        `${cityName}'s premier green space`,
        'Features walking trails, fountains & seasonal flowers',
        'Perfect for picnics and relaxation',
        'Great for photography especially in golden hour',
        'Free entry and open throughout the day',
      ],
      address: `Gardens, ${cityName}`,
      timings: { open: '06:00', close: '19:00', note: 'Open all days' },
      entryFee: 'Free',
      bestTime: 'Morning (7 AM) or late afternoon (4 PM)',
      whatToCarry: ['Water bottle', 'Sunscreen', 'Comfortable shoes', 'Picnic mat (optional)'],
      nearby: [{ name: `${cityName} Old Town`, distance: '1.5 km', type: 'Historic' }],
      rating: 4.4,
      durationMin: 60,
      distanceKm: 3,
      gradient: 'forest',
      icon: 'leaf',
      tags: ['Nature', 'Gardens', 'Relaxation', 'Photography'],
      isOutdoor: true,
    },
    {
      id: `${baseId}-hidden`,
      name: `${cityName} Hidden Quarter`,
      cityId: baseId,
      category: 'hidden',
      subcategory: 'Off-the-Beaten-Path',
      shortDesc: `A lesser-known neighbourhood full of surprises`,
      description: `Discover the side of ${cityName} that most tourists never see. The Hidden Quarter is a neighbourhood of narrow lanes, local art, street murals, and quirky cafes — a place where the city's creative spirit thrives away from the main tourist trail. Every corner holds a surprise.`,
      history: `The Hidden Quarter developed as an artists' and artisans' neighbourhood, where creatives and craftspeople settled away from the main commercial areas. Over time, it became a hub of local culture, with galleries, studios, and independent shops. Today it's a favourite of locals and in-the-know travellers who seek authentic experiences beyond the typical tourist spots.`,
      facts: [
        `A hidden neighbourhood most tourists miss`,
        'Home to local artists, murals, and independent shops',
        'The creative soul of the city',
        'Great for photography and authentic experiences',
        'Ask locals for directions — it is worth finding',
      ],
      address: `Hidden Quarter, ${cityName}`,
      timings: { open: '10:00', close: '19:00', note: 'Some shops closed on Sundays' },
      entryFee: 'Free',
      bestTime: 'Afternoon (2 PM–5 PM) when shops and cafes are open',
      whatToCarry: ['Camera', 'Cash for small shops & cafes', 'Comfortable walking shoes'],
      nearby: [{ name: `${cityName} Old Town`, distance: '1 km', type: 'Historic' }],
      rating: 4.5,
      durationMin: 75,
      distanceKm: 2.5,
      gradient: 'plum',
      icon: 'compass',
      tags: ['Hidden Gem', 'Art', 'Local Culture', 'Photography'],
      isOutdoor: true,
    },
  ];

  return places;
}

export function generateGenericStays(cityName: string): Stay[] {
  const slug = slugify(cityName);
  const baseId = `gen-${slug}`;
  return [
    {
      id: `${baseId}-luxury`,
      name: `Grand ${cityName} Hotel`,
      cityId: baseId,
      type: 'Luxury',
      pricePerNight: 12000,
      rating: 4.7,
      address: `Central ${cityName}`,
      amenities: ['Pool', 'Spa', 'Restaurant', 'Gym', 'WiFi', 'Parking'],
      description: `Luxurious 5-star hotel in the heart of ${cityName} with world-class amenities and fine dining.`,
      distanceKm: 2,
      gradient: 'plum',
    },
    {
      id: `${baseId}-premium`,
      name: `${cityName} Boutique Inn`,
      cityId: baseId,
      type: 'Premium',
      pricePerNight: 5000,
      rating: 4.5,
      address: `Downtown ${cityName}`,
      amenities: ['Restaurant', 'WiFi', 'Gym', 'Parking'],
      description: `Stylish boutique hotel with personalised service and a prime location in ${cityName}.`,
      distanceKm: 3,
      gradient: 'indigo',
    },
    {
      id: `${baseId}-budget`,
      name: `${cityName} City Lodge`,
      cityId: baseId,
      type: 'Budget',
      pricePerNight: 1500,
      rating: 4.1,
      address: `Old Town, ${cityName}`,
      amenities: ['WiFi', 'AC', 'Parking'],
      description: `Affordable and comfortable lodge near the Old Town with clean rooms and friendly staff.`,
      distanceKm: 1,
      gradient: 'saffron',
    },
    {
      id: `${baseId}-hostel`,
      name: `${cityName} Backpackers Hub`,
      cityId: baseId,
      type: 'Hostel',
      pricePerNight: 500,
      rating: 4.3,
      address: `Central ${cityName}`,
      amenities: ['WiFi', 'Cafe', 'Lockers', 'Common Area', 'Kitchen'],
      description: `Popular backpacker hostel with dorms and private rooms, a lively social scene, and travel desk.`,
      distanceKm: 2,
      gradient: 'ocean',
    },
  ];
}

// ─── Unified accessors (known + generic) ───────────────────────

const genericCache = new Map<string, { city: City; places: Place[]; stays: Stay[] }>();

export function getOrCreateCity(cityName: string, cities: City[]): { city: City; places: Place[]; stays: Stay[]; isKnown: boolean } {
  const matched = matchCity(cityName, cities);
  if (matched) {
    return {
      city: matched,
      places: PLACES.filter((p) => p.cityId === matched.id),
      stays: STAYS.filter((s) => s.cityId === matched.id),
      isKnown: true,
    };
  }
  const slug = slugify(cityName);
  if (genericCache.has(slug)) {
    return { ...genericCache.get(slug)!, isKnown: false };
  }
  const city = generateGenericCity(cityName);
  const places = generateGenericPlaces(cityName);
  const stays = generateGenericStays(cityName);
  genericCache.set(slug, { city, places, stays });
  return { city, places, stays, isKnown: false };
}

export function getGenericPlace(id: string): Place | undefined {
  for (const entry of genericCache.values()) {
    const place = entry.places.find((p) => p.id === id);
    if (place) return place;
  }
  return undefined;
}

export function getGenericCity(id: string): City | undefined {
  for (const entry of genericCache.values()) {
    if (entry.city.id === id) return entry.city;
  }
  return undefined;
}

export function getGenericStays(cityId: string): Stay[] {
  for (const entry of genericCache.values()) {
    if (entry.city.id === cityId) return entry.stays;
  }
  return [];
}

export function getAllPlacesByCity(cityId: string): Place[] {
  const known = PLACES.filter((p) => p.cityId === cityId);
  if (known.length > 0) return known;
  for (const entry of genericCache.values()) {
    if (entry.city.id === cityId) return entry.places;
  }
  return [];
}

export function getAllStaysByCity(cityId: string): Stay[] {
  const known = STAYS.filter((s) => s.cityId === cityId);
  if (known.length > 0) return known;
  for (const entry of genericCache.values()) {
    if (entry.city.id === cityId) return entry.stays;
  }
  return [];
}

export function findCityById(cityId: string, cities: City[]): City | undefined {
  const known = cities.find((c) => c.id === cityId);
  if (known) return known;
  return getGenericCity(cityId);
}
