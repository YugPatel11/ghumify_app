/**
 * Itinerary Creation Form & Remarks Merger Engine
 *
 * Implements strict merge rules:
 * 1. Form fields always win over remarks on conflict.
 * 2. Remarks fill any gaps (missing destination, dates, preferences) marked with source: 'remarks'.
 * 3. Contradictions are preserved with visible user warnings ("Your remarks mention X but form says Y").
 * 4. Empty/whitespace remarks skip LLM processing entirely.
 * 5. Missing critical data in both form and remarks triggers a blocking validation error.
 */

export interface FormFields {
  city?: string | null;
  date?: string | null;
  startDate?: string | null;
  endDate?: string | null;
  numberOfDays?: number | null;
  hours?: number | null;
  startTime?: string | null;
  endTime?: string | null;
  travelers?: number | null;
  budget?: number | null;
  travelMode?: string | null;
  pace?: string | null;
  foodPreference?: string | null;
  interests?: string[] | null;
}

export type FieldSource = 'form' | 'remarks' | 'default';

export interface ContradictionWarning {
  field: string;
  formValue: any;
  remarksValue: any;
  message: string;
}

export interface MergedItineraryPlan {
  city: string;
  numberOfDays: number;
  hours: number;
  startTime: string;
  endTime: string;
  travelers: number;
  budget: number | null;
  travelMode: string;
  pace: string;
  foodPreference: string;
  interests: string[];
  sources: Record<string, FieldSource>;
  contradictions: ContradictionWarning[];
  assumptions: string[];
  hasRemarks: boolean;
  remarksText: string;
  extractedPreferences: {
    dietary?: string;
    pacing?: string;
    kidFriendly?: boolean;
    wheelchairAccessible?: boolean;
    avoidEarlyMornings?: boolean;
    budgetType?: string;
  };
}

export interface MergeResult {
  valid: boolean;
  missingFields: string[];
  errorMessage?: string;
  plan?: MergedItineraryPlan;
}

const KNOWN_CITIES = [
  'jaipur', 'goa', 'agra', 'delhi', 'mumbai', 'varanasi',
  'udaipur', 'kerala', 'bengaluru', 'hyderabad', 'chennai',
  'kolkata', 'amritsar', 'shimla', 'manali', 'rishikesh', 'indore', 'dubai'
];

/**
 * Sanitizes untrusted remarks text and strips dangerous tokens.
 */
export function sanitizeRemarks(raw?: string | null): string {
  if (!raw || typeof raw !== 'string') return '';
  // Strip invisible Unicode whitespace (\u200B-\u200D, \uFEFF, \u00A0)
  let clean = raw.replace(/[\u200B-\u200D\uFEFF\u00A0]/g, ' ').trim();
  if (clean.length === 0) return '';
  // Bound length to max 4000 characters
  if (clean.length > 4000) {
    clean = clean.slice(0, 4000);
  }
  // Strip script tags and content
  clean = clean.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
  // Strip any remaining HTML tags
  clean = clean.replace(/<[^>]+>/g, '');
  // Strip inline JavaScript handlers like onerror=alert(1)
  clean = clean.replace(/\bon\w+\s*=\s*(?:'[^']*'|"[^"]*"|[^\s>]+)/gi, '');
  // Strip control characters
  clean = clean.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
  return clean.replace(/[\u200B-\u200D\uFEFF\u00A0]/g, '').trim();
}

/**
 * Deterministic regex & keyword extractor for trip details from user remarks.
 */
export function extractFromRemarks(remarks: string): {
  city?: string;
  numberOfDays?: number;
  hours?: number;
  travelMode?: string;
  pace?: string;
  foodPreference?: string;
  interests?: string[];
  kidFriendly?: boolean;
  wheelchairAccessible?: boolean;
  avoidEarlyMornings?: boolean;
  budgetType?: string;
} {
  const lower = remarks.toLowerCase();
  const extracted: ReturnType<typeof extractFromRemarks> = {};

  // 1. City extraction
  for (const c of KNOWN_CITIES) {
    const cityRegex = new RegExp(`\\b(${c})\\b`, 'i');
    if (cityRegex.test(lower)) {
      extracted.city = c.charAt(0).toUpperCase() + c.slice(1);
      break;
    }
  }

  // 2. Duration / Days extraction
  const weekMatch = lower.match(/\b(1|one|a)\s+week\b/);
  if (weekMatch) {
    extracted.numberOfDays = 7;
  } else {
    const daysMatch = lower.match(/\b(\d+)\s*(?:days?|nights?)\b/);
    if (daysMatch) {
      extracted.numberOfDays = parseInt(daysMatch[1], 10);
    } else if (lower.includes('weekend')) {
      extracted.numberOfDays = 2;
    }
  }

  // 3. Hours extraction (e.g. "6 hours", "half day", "full day")
  const hoursMatch = lower.match(/\b(\d+)\s*(?:hours?|hrs?)\b/);
  if (hoursMatch) {
    extracted.hours = parseInt(hoursMatch[1], 10);
  } else if (lower.includes('half day')) {
    extracted.hours = 4;
  } else if (lower.includes('full day')) {
    extracted.hours = 8;
  }

  // 4. Pace extraction (multilingual support)
  if (
    lower.includes('relaxed') ||
    lower.includes('chill') ||
    lower.includes('slow pace') ||
    lower.includes('no rush') ||
    lower.includes('unhurried') ||
    lower.includes('leisurely') ||
    lower.includes('धीमी') ||
    lower.includes('هادئ')
  ) {
    extracted.pace = 'relaxed';
  } else if (lower.includes('fast pace') || lower.includes('action packed') || lower.includes('whirlwind')) {
    extracted.pace = 'fast';
  } else if (lower.includes('moderate')) {
    extracted.pace = 'moderate';
  }

  // 5. Dietary extraction (multilingual: Hindi शाकाहारी, Arabic نباتي)
  if (lower.includes('jain')) {
    extracted.foodPreference = 'jain';
  } else if (
    lower.includes('pure veg') ||
    lower.includes('vegetarian') ||
    lower.includes('veg only') ||
    lower.includes('शाकाहारी') ||
    lower.includes('نباتي')
  ) {
    extracted.foodPreference = 'vegetarian';
  } else if (lower.includes('non-veg') || lower.includes('meat') || lower.includes('chicken')) {
    extracted.foodPreference = 'non_veg';
  } else if (lower.includes('egg') && lower.includes('veg')) {
    extracted.foodPreference = 'veg_egg';
  }

  // 6. Travel Mode
  if (lower.includes('walking') || lower.includes('on foot')) {
    extracted.travelMode = 'walking';
  } else if (lower.includes('cab') || lower.includes('taxi') || lower.includes('car') || lower.includes('driving')) {
    extracted.travelMode = 'driving';
  } else if (lower.includes('metro') || lower.includes('transit') || lower.includes('bus')) {
    extracted.travelMode = 'transit';
  }

  // 7. Quick Preferences & Chips (multilingual)
  if (
    lower.includes('kid') ||
    lower.includes('children') ||
    lower.includes('family') ||
    lower.includes('बच्च') ||
    lower.includes('अस्पताल') ||
    lower.includes('أطفال') ||
    lower.includes('اطفال')
  ) {
    extracted.kidFriendly = true;
  }
  if (
    lower.includes('wheelchair') ||
    lower.includes('accessible') ||
    lower.includes('ह्वीलचेयर') ||
    lower.includes('کرسي متحرك')
  ) {
    extracted.wheelchairAccessible = true;
  }
  if (
    lower.includes('avoid early morning') ||
    lower.includes('no early morning') ||
    lower.includes('late start') ||
    lower.includes('जल्दी नहीं') ||
    lower.includes('صباح')
  ) {
    extracted.avoidEarlyMornings = true;
  }
  if (
    lower.includes('budget trip') ||
    lower.includes('low budget') ||
    lower.includes('pocket friendly') ||
    lower.includes('luxury') ||
    lower.includes('high budget')
  ) {
    extracted.budgetType = lower.includes('luxury') || lower.includes('high budget') ? 'luxury' : 'budget';
  }

  // 8. Interests
  const interests: string[] = [];
  if (lower.includes('heritage') || lower.includes('history') || lower.includes('fort') || lower.includes('palace')) {
    interests.push('Heritage & History');
  }
  if (lower.includes('food') || lower.includes('street food') || lower.includes('culinary')) {
    interests.push('Local Food');
  }
  if (lower.includes('shopping') || lower.includes('market') || lower.includes('bazaar')) {
    interests.push('Markets & Shopping');
  }
  if (lower.includes('temple') || lower.includes('spiritual') || lower.includes('ashram')) {
    interests.push('Temples & Spirituality');
  }
  if (lower.includes('nature') || lower.includes('park') || lower.includes('garden')) {
    interests.push('Nature & Parks');
  }
  if (interests.length > 0) {
    extracted.interests = interests;
  }

  return extracted;
}

/**
 * Merges form fields and remarks applying the strict conflict and precedence rules.
 */
export function mergeFormAndRemarks(
  form: FormFields,
  rawRemarks?: string | null,
  language: string = 'en'
): MergeResult {
  const remarks = sanitizeRemarks(rawRemarks);
  const hasRemarks = remarks.length > 0;
  const sources: Record<string, FieldSource> = {};
  const contradictions: ContradictionWarning[] = [];
  const assumptions: string[] = [];

  // 1. If remarks are completely empty, execute FAST-PATH (deterministic, zero LLM, no change)
  if (!hasRemarks) {
    const city = form.city?.trim();
    if (!city) {
      return {
        valid: false,
        missingFields: ['city'],
        errorMessage: 'Destination city is required.',
      };
    }

    const plan: MergedItineraryPlan = {
      city,
      numberOfDays: form.numberOfDays || (form.startDate && form.endDate ? 3 : 1),
      hours: form.hours || 6,
      startTime: form.startTime || '09:00',
      endTime: form.endTime || '18:00',
      travelers: form.travelers || 1,
      budget: form.budget ?? null,
      travelMode: form.travelMode || 'driving',
      pace: form.pace || 'moderate',
      foodPreference: form.foodPreference || 'all',
      interests: form.interests && form.interests.length > 0 ? form.interests : ['Famous Places', 'Local Food'],
      sources: {
        city: 'form',
        numberOfDays: form.numberOfDays ? 'form' : 'default',
        hours: form.hours ? 'form' : 'default',
        startTime: form.startTime ? 'form' : 'default',
        endTime: form.endTime ? 'form' : 'default',
        travelers: form.travelers ? 'form' : 'default',
        travelMode: form.travelMode ? 'form' : 'default',
        pace: form.pace ? 'form' : 'default',
        foodPreference: form.foodPreference ? 'form' : 'default',
        interests: form.interests?.length ? 'form' : 'default',
      },
      contradictions: [],
      assumptions: ['Standard sightseeing pace assumed', 'Default active hours 09:00 - 18:00 applied'],
      hasRemarks: false,
      remarksText: '',
      extractedPreferences: {},
    };

    return { valid: true, missingFields: [], plan };
  }

  // 2. Remarks are present: Extract fields
  const extracted = extractFromRemarks(remarks);

  // 3. Resolve City (Form wins, remarks fills gap, missing in both blocks)
  let finalCity = '';
  if (form.city && form.city.trim().length > 0) {
    finalCity = form.city.trim();
    sources['city'] = 'form';
    // Check if remarks mention a different city
    if (extracted.city && extracted.city.toLowerCase() !== finalCity.toLowerCase()) {
      contradictions.push({
        field: 'city',
        formValue: finalCity,
        remarksValue: extracted.city,
        message: `Your remarks mention "${extracted.city}" but the form says "${finalCity}". We used "${finalCity}". Tap to change.`,
      });
    }
  } else if (extracted.city) {
    finalCity = extracted.city;
    sources['city'] = 'remarks';
  } else {
    return {
      valid: false,
      missingFields: ['city'],
      errorMessage: 'Please enter a destination city in the form or mention it in your remarks.',
    };
  }

  // 4. Resolve Number of Days
  let finalDays = 1;
  if (form.numberOfDays && form.numberOfDays > 0) {
    finalDays = form.numberOfDays;
    sources['numberOfDays'] = 'form';
    if (extracted.numberOfDays && extracted.numberOfDays !== finalDays) {
      contradictions.push({
        field: 'numberOfDays',
        formValue: finalDays,
        remarksValue: extracted.numberOfDays,
        message: `Your remarks mention ${extracted.numberOfDays} days but the form says ${finalDays} days. We used ${finalDays} days. Tap to change.`,
      });
    }
  } else if (extracted.numberOfDays && extracted.numberOfDays > 0) {
    finalDays = extracted.numberOfDays;
    sources['numberOfDays'] = 'remarks';
  } else {
    finalDays = 1;
    sources['numberOfDays'] = 'default';
    assumptions.push('1-day itinerary assumed');
  }

  // 5. Resolve Hours & Timing
  let finalHours = 6;
  if (form.hours && form.hours > 0) {
    finalHours = form.hours;
    sources['hours'] = 'form';
  } else if (extracted.hours && extracted.hours > 0) {
    finalHours = extracted.hours;
    sources['hours'] = 'remarks';
  } else {
    finalHours = 6;
    sources['hours'] = 'default';
  }

  // Avoid early morning shift
  let startTime = form.startTime || '09:00';
  let endTime = form.endTime || '18:00';
  if (extracted.avoidEarlyMornings && !form.startTime) {
    startTime = '10:30';
    endTime = '19:30';
    sources['startTime'] = 'remarks';
    sources['endTime'] = 'remarks';
  } else {
    sources['startTime'] = form.startTime ? 'form' : 'default';
    sources['endTime'] = form.endTime ? 'form' : 'default';
  }

  // 6. Resolve Pace (Form wins, remarks fills gap, contradiction flagged)
  let finalPace = 'moderate';
  if (form.pace) {
    finalPace = form.pace;
    sources['pace'] = 'form';
    if (extracted.pace && extracted.pace !== finalPace) {
      contradictions.push({
        field: 'pace',
        formValue: finalPace,
        remarksValue: extracted.pace,
        message: `Your remarks suggest a "${extracted.pace}" pace, but form is set to "${finalPace}". We kept "${finalPace}". Tap to change.`,
      });
    }
  } else if (extracted.pace) {
    finalPace = extracted.pace;
    sources['pace'] = 'remarks';
  } else {
    finalPace = 'moderate';
    sources['pace'] = 'default';
  }

  // 7. Resolve Dietary Preference
  let finalFood = 'all';
  if (form.foodPreference && form.foodPreference !== 'all') {
    finalFood = form.foodPreference;
    sources['foodPreference'] = 'form';
    if (extracted.foodPreference && extracted.foodPreference !== finalFood) {
      contradictions.push({
        field: 'foodPreference',
        formValue: finalFood,
        remarksValue: extracted.foodPreference,
        message: `Your remarks request "${extracted.foodPreference}" food, but form has "${finalFood}". We kept "${finalFood}". Tap to change.`,
      });
    }
  } else if (extracted.foodPreference) {
    finalFood = extracted.foodPreference;
    sources['foodPreference'] = 'remarks';
  } else {
    finalFood = 'all';
    sources['foodPreference'] = 'default';
  }

  // 8. Resolve Travel Mode
  let finalMode = form.travelMode || extracted.travelMode || 'driving';
  sources['travelMode'] = form.travelMode ? 'form' : (extracted.travelMode ? 'remarks' : 'default');

  // 9. Resolve Travelers
  let finalTravelers = form.travelers || 1;
  sources['travelers'] = form.travelers ? 'form' : 'default';

  // 10. Combine Interests (Union of form + remarks)
  const combinedInterests = new Set<string>(form.interests || []);
  if (extracted.interests) {
    for (const item of extracted.interests) {
      combinedInterests.add(item);
    }
  }
  if (combinedInterests.size === 0) {
    combinedInterests.add('Famous Places');
    combinedInterests.add('Local Food');
    sources['interests'] = 'default';
  } else {
    sources['interests'] = form.interests?.length ? 'form' : 'remarks';
  }

  const plan: MergedItineraryPlan = {
    city: finalCity,
    numberOfDays: finalDays,
    hours: finalHours,
    startTime,
    endTime,
    travelers: finalTravelers,
    budget: form.budget ?? null,
    travelMode: finalMode,
    pace: finalPace,
    foodPreference: finalFood,
    interests: Array.from(combinedInterests),
    sources,
    contradictions,
    assumptions,
    hasRemarks: true,
    remarksText: remarks,
    extractedPreferences: {
      dietary: extracted.foodPreference,
      pacing: extracted.pace,
      kidFriendly: extracted.kidFriendly,
      wheelchairAccessible: extracted.wheelchairAccessible,
      avoidEarlyMornings: extracted.avoidEarlyMornings,
      budgetType: extracted.budgetType,
    },
  };

  return { valid: true, missingFields: [], plan };
}
