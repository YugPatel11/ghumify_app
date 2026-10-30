# Ghumify App (घुमीफाई)

An AI-powered travel companion mobile application designed for exploring Indian cities. Ghumify crafts intelligent, sequential, time-boxed day-by-day itineraries tailored to user preferences, constraints, pace, and live weather.

## Key Features
- **Smart Destination Search (Autocomplete):** Real-time place suggestions with 300ms debouncing, in-memory caching, category badges, Hindi/local-language keyword matching, Google Places Autocomplete with session tokens, and OpenStreetMap (Nominatim) live fallback.
- **AI-Powered Itinerary Crafting:** Single-day and multi-day itinerary generation powered by Google Gemini multi-model rotation.
- **Conversational Trip Customization:** In-app AI travel chatbot to add, remove, and adjust stops on the fly without raw JSON leakage.
- **Local Language Support:** Translation across 10 major Indian languages with Firestore caching.
- **Full-Bleed Visual Splash Screen:** Immersive "splash page" visual with edge-matched native background and smooth fade-out transition.
- **Food Preference & Dietary Personalization:** 5-tier dietary preference selector (Veg, Veg + Egg, Jain, Non-Veg, All) with persistent offline and cloud sync, strict AI itinerary and chatbot adherence, and automated post-response safety validation.
- **OpenStreetMap Nearby Safety:** Emergency safety radar locating nearby hospitals, clinics, and police stations using OSM Overpass with multi-tier radius expansion (3km–10km), offline caching, Google Maps integration, direct calling, and attribution.
- **Essential Services Discovery:** Instant lookups for nearby hospitals, pharmacies, ATMs, police, restrooms, and petrol stations.

## Setup & Configuration
1. Clone the repository and install Flutter dependencies:
   ```bash
   flutter pub get
   ```
2. Configure `.env` in the root directory:
   ```env
   GEMINI_API_KEY=your_gemini_api_key
   GOOGLE_MAPS_API_KEY=your_google_places_api_key  # Optional: OSM Nominatim and curated catalog work without key
   OPENWEATHER_API_KEY=your_openweather_api_key
   ```
3. Run code analysis and tests:
   ```bash
   flutter analyze
   flutter test
   ```
4. Launch the application:
   ```bash
   flutter run
   ```

