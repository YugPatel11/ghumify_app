export interface CatalogItem {
  namespace: string;
  key: string;
  text: string;
}

export const SOURCE_CATALOG: CatalogItem[] = [
  // Common / Navigation
  { namespace: 'common', key: 'common.appName', text: 'Ghumify' },
  { namespace: 'common', key: 'common.tagline', text: 'Your Smart Travel Companion' },
  { namespace: 'common', key: 'common.loading', text: 'Loading...' },
  { namespace: 'common', key: 'common.save', text: 'Save' },
  { namespace: 'common', key: 'common.cancel', text: 'Cancel' },
  { namespace: 'common', key: 'common.back', text: 'Back' },
  { namespace: 'common', key: 'common.search', text: 'Search' },
  { namespace: 'common', key: 'common.retry', text: 'Retry' },
  { namespace: 'common', key: 'common.mins', text: 'mins' },
  { namespace: 'common', key: 'common.hours', text: 'hours' },
  { namespace: 'common', key: 'common.km', text: 'km' },

  // Navigation tabs
  { namespace: 'nav', key: 'nav.plan', text: 'Plan' },
  { namespace: 'nav', key: 'nav.explore', text: 'Explore' },
  { namespace: 'nav', key: 'nav.translate', text: 'Translate' },
  { namespace: 'nav', key: 'nav.stays', text: 'Stays' },
  { namespace: 'nav', key: 'nav.settings', text: 'Settings' },

  // Home Screen
  { namespace: 'home', key: 'home.headerTitle', text: 'Create Your Plan' },
  { namespace: 'home', key: 'home.inputPlaceholder', text: 'e.g. 6 hours in Indore, want to try famous food and visit local markets' },
  { namespace: 'home', key: 'home.generateBtn', text: 'Generate Travel Plan' },
  { namespace: 'home', key: 'home.examplePrompts', text: 'Example Prompts' },
  { namespace: 'home', key: 'home.loadingSpots', text: 'Finding the best spots...' },
  { namespace: 'home', key: 'home.loadingHours', text: 'Checking opening hours...' },
  { namespace: 'home', key: 'home.loadingWeather', text: 'Looking at the weather...' },
  { namespace: 'home', key: 'home.loadingRoute', text: 'Planning your route...' },
  { namespace: 'home', key: 'home.loadingFood', text: 'Adding food stops...' },
  { namespace: 'home', key: 'home.loadingReady', text: 'Almost ready...' },
  { namespace: 'home', key: 'home.errLocation', text: 'Please enter a city or destination' },

  // Explore Screen
  { namespace: 'explore', key: 'explore.searchPlaceholder', text: 'Search places, food, markets...' },
  { namespace: 'explore', key: 'explore.showingIn', text: 'Showing places in {city}' },
  { namespace: 'explore', key: 'explore.all', text: 'All' },
  { namespace: 'explore', key: 'explore.tourist', text: 'Tourist Spots' },
  { namespace: 'explore', key: 'explore.food', text: 'Food & Dining' },
  { namespace: 'explore', key: 'explore.market', text: 'Markets & Shopping' },
  { namespace: 'explore', key: 'explore.culture', text: 'Culture & Heritage' },
  { namespace: 'explore', key: 'explore.nature', text: 'Nature & Parks' },
  { namespace: 'explore', key: 'explore.hidden', text: 'Hidden Gems' },
  { namespace: 'explore', key: 'explore.noPlacesFound', text: 'No places found' },
  { namespace: 'explore', key: 'explore.tryAnother', text: 'Try another category or search term' },

  // Place Detail Screen
  { namespace: 'place', key: 'place.overview', text: 'Overview' },
  { namespace: 'place', key: 'place.openingHours', text: 'Opening Hours' },
  { namespace: 'place', key: 'place.entryFee', text: 'Entry Fee' },
  { namespace: 'place', key: 'place.bestTime', text: 'Best Time to Visit' },
  { namespace: 'place', key: 'place.whatToCarry', text: 'What to Carry' },
  { namespace: 'place', key: 'place.facts', text: 'Interesting Facts' },
  { namespace: 'place', key: 'place.history', text: 'Historical Context' },
  { namespace: 'place', key: 'place.nearby', text: 'Nearby Attractions' },
  { namespace: 'place', key: 'place.audioGuide', text: 'Listen to Audio Guide' },
  { namespace: 'place', key: 'place.directions', text: 'Get Directions' },
  { namespace: 'place', key: 'place.share', text: 'Share Place' },

  // Plan Result Screen
  { namespace: 'plan', key: 'plan.yourPlan', text: 'Your Itinerary' },
  { namespace: 'plan', key: 'plan.totalDuration', text: 'Total Duration' },
  { namespace: 'plan', key: 'plan.placesToVisit', text: 'Places to Visit' },
  { namespace: 'plan', key: 'plan.startTime', text: 'Start Time' },
  { namespace: 'plan', key: 'plan.travelToNext', text: 'Travel to next destination' },
  { namespace: 'plan', key: 'plan.editPlan', text: 'Edit Plan' },
  { namespace: 'plan', key: 'plan.savePlan', text: 'Save Itinerary' },

  // Stays Screen
  { namespace: 'stays', key: 'stays.title', text: 'Budget Stays & Hostels' },
  { namespace: 'stays', key: 'stays.hostels', text: 'Hostels' },
  { namespace: 'stays', key: 'stays.hotels', text: 'Hotels' },
  { namespace: 'stays', key: 'stays.dharamshalas', text: 'Dharamshalas' },
  { namespace: 'stays', key: 'stays.noStays', text: 'No stays found in this area' },
  { namespace: 'stays', key: 'stays.perNight', text: 'per night' },

  // Translate Screen
  { namespace: 'translate', key: 'translate.title', text: 'Tourist Translator' },
  { namespace: 'translate', key: 'translate.subtitle', text: 'Instant translation for travel communication' },
  { namespace: 'translate', key: 'translate.speakPrompt', text: 'Tap microphone to speak' },
  { namespace: 'translate', key: 'translate.copy', text: 'Copy Translation' },
  { namespace: 'translate', key: 'translate.copied', text: 'Translation copied!' },

  // Settings Screen
  { namespace: 'settings', key: 'settings.title', text: 'Settings' },
  { namespace: 'settings', key: 'settings.defaultLanguage', text: 'Default Language' },
  { namespace: 'settings', key: 'settings.languageDesc', text: 'Applies automatically across all your devices' },
  { namespace: 'settings', key: 'settings.currently', text: 'Currently: {lang}' },
  { namespace: 'settings', key: 'settings.searchLang', text: 'Search language...' },
  { namespace: 'settings', key: 'settings.savedSuccess', text: 'Language updated successfully.' },
  { namespace: 'settings', key: 'settings.saveError', text: 'Failed to update language. Please try again.' },
  { namespace: 'settings', key: 'settings.aboutTitle', text: 'About Ghumify' },
  { namespace: 'settings', key: 'settings.aboutDesc', text: 'Ghumify is your complete travel companion for exploring India with personalized, time-based travel plans.' },
  { namespace: 'settings', key: 'settings.version', text: 'Ghumify v1.0 · Made in India 🇮🇳' },

  // Backend & Error Messages
  { namespace: 'errors', key: 'errors.unsupportedLanguage', text: 'Language {lang} is not supported.' },
  { namespace: 'errors', key: 'errors.rateLimitExceeded', text: 'Too many requests. Please try again later.' },
  { namespace: 'errors', key: 'errors.missingAuth', text: 'Authentication is required.' },
  { namespace: 'errors', key: 'errors.invalidInput', text: 'Invalid request parameters.' },
  { namespace: 'errors', key: 'errors.translationUnavailable', text: 'Translation service is temporarily unavailable.' },
  { namespace: 'errors', key: 'errors.originRequired', text: 'Origin and destination are required.' },
];
