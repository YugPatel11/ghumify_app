# Ghumify App — Task & Bug Tracking

## Resolved Issues

### BUG-001: Chatbot Raw JSON Dump on Itinerary Modification & Chat
* **Status:** Resolved
* **Description:**
  When a user typed an itinerary modification request or certain questions in `ItineraryChatSheet`, the assistant response displayed a raw JSON dump of the internal itinerary data structure (including `userId`, internal `id`, coordinates, and stop lists) instead of a natural-language conversational reply.
* **Root Causes:**
  1. `_buildChatPrompt` in `GeminiService` explicitly mandated the model to respond with "the FULL MODIFIED ITINERARY as JSON... output ONLY valid JSON (no markdown, no code blocks)" and injected unsanitized internal model data containing private user IDs and internal IDs.
  2. In `chatAboutItinerary`, when the model returned large or truncated JSON, `json.decode` threw a format exception that was caught by `catch (_)`, leaving `textContent` set to the raw `responseText` string.
  3. No defensive sanitization existed in `ChatMessageModel` or `ChatBubble`, causing the raw JSON to be rendered directly into the UI and persisted into `SharedPreferences`.
* **Design & Architectural Decisions:**
  1. **Strict Separation of Chat Reply & Structured Data:**
     * The conversational UI text (`ChatMessageModel.content`) and the background structured trip data (`ChatMessageModel.updatedItinerary`) are now strictly decoupled.
     * The prompt commands the model to return two separate keys: `chatMessage` (natural-language explanation with readable bullet-point summary) and `updatedItinerary` (structured itinerary map).
  2. **Prompt Data Sanitization:**
     * All internal IDs, Firebase Auth `userId`, database document IDs, timestamps, and save states are stripped before passing itinerary context to Gemini.
  3. **Multi-Layer Defensive Safety Net:**
     * `GeminiService`: Extracts JSON cleanly, extracts `chatMessage`, and if missing or malformed, formats the itinerary into a clean, human-readable summary.
     * `ChatMessageModel`: Sanitizes incoming text both on instantiation and during `fromMap` deserialization.
     * `ChatBubble`: Defensively ensures any raw JSON or serialized data structures are converted into readable text before rendering.
     * `ItineraryChatSheet`: Automatically heals and re-saves stored chat sessions upon loading.
* **Verification:**
  * Verified with comprehensive unit test suite in `test/chat_sanitization_test.dart` (6 test cases passing covering normal text, raw bug JSON, truncated JSON, explicit chatMessage, whitespace, and fromMap persistence).

### TASK-002: Craft Itinerary ("Plan Trip") Screen Redesign
* **Status:** Completed
* **Branch:** `redesign/craft-itinerary`
* **Description:**
  Autonomous, end-to-end editorial redesign of the "Craft Itinerary" page (`TripInputScreen` at `/plan-trip`). Transformed the legacy 877-line basic wizard into a high-polish, tactile, accessible, and responsive travel studio experience.
* **Key Improvements:**
  1. **Editorial Parallax Hero:** Layered glassmorphic header (`CraftHeader`) with cached imagery (`CachedNetworkImage`), real-time destination detection badge, and backdrop blur.
  2. **Segmented Progress Stepper:** Dynamic progress indicator (`CraftStepIndicator`) with percentage calculation, active glow states, and stage headers.
  3. **Tactile Selector Cards:** High-contrast `CraftSelectorCard` components with illuminated icon badges, micro-animations, and selection indicators for transport modes and pace preferences.
  4. **Smart Travel Presets:** 1-tap popular Indian destinations (Jaipur, Goa, Agra, Mumbai, Delhi, etc.), quick duration pills (1D, 2D, 3D, 5D, Custom Range), group size presets (Solo, Couple, Family, Group), and budget brackets.
  5. **Categorized Interest Matrix & Trip Dossier:** Grouped interest tags (Heritage, Flavors, Outdoor) with selection counters and an interactive live summary card previewing the complete itinerary configuration before launch.
  6. **Cinematic AI Synthesis Loading Screen:** High-fidelity `CraftLoadingDialog` featuring rotating orbital rings, pulsating center compass, progressive 4-stage pipeline statuses, and rotating travel tips.
  7. **Strict Contract Preservation:** Preserved exact routing arguments and payload contracts for `/itinerary` (single-day) and `/multi-day-itinerary` (multi-day) with full backward compatibility.
### TASK-003: Smart Place-Name Autocomplete & Craft Itinerary Wording Polish
* **Status:** Completed
* **Branch:** `redesign/craft-itinerary`
* **Description:**
  Engineered a smart place-name suggestions (autocomplete) dropdown for the Craft Itinerary search bar (`TripInputScreen` at `/plan-trip`), backed by a multi-source architecture (in-memory query cache, curated Indian destinations & landmarks catalog with Hindi keyword matching, Google Places Autocomplete with session tokens, and OpenStreetMap Nominatim live fallback). Conducted a full audit of user-facing copy across the Craft Itinerary flow, resolving grammatical inconsistencies, technical jargon, and awkward phrasing.
* **Key Improvements:**
  1. **Multi-Source Places Autocomplete (`PlaceSuggestion` model & `PlacesService`):**
     * Debounced queries (300ms) with request cancellation / generation token tracking to eliminate race conditions.
     * Starts suggesting at >= 2 characters; caches results by normalized query string to save bandwidth/API quotas.
     * Focus-on-empty state displays quick-tap popular Indian destinations (Jaipur, Goa, Agra, Delhi, Varanasi, etc.).
     * Curated catalog of 20+ prominent Indian destinations and heritage landmarks with Hindi transliterations ("जयपुर", "ताज महल", "हवा महल") supporting fuzzy/local language input.
     * Google Places Autocomplete integration using session tokens (`sessionToken`) with fallback to OpenStreetMap Nominatim when Google Places is unconfigured or billing is inactive.
  2. **Tactile Search UI & UX:**
     * Clean floating suggestion card matching the dark theme design system (`AppColors.surfaceDark`, `AppColors.primary`, `AppColors.borderDark`).
     * `RichText` query highlighting bolding the typed substring in destination titles.
     * Category taxonomy badges with contextual icons (City, Monument/Heritage, Temple/Spiritual, Nature, Beach, Market, Food).
     * Clear empty ("No destinations found"), loading, and error states with tactile feedback.
     * Tapping a suggestion fills the search field, resolves lat/long coordinates, loads the hero photo dynamically, and dismisses the keyboard and dropdown cleanly.
  3. **Wording & Grammar Polish:**
     * Replaced awkward phrasing and tech jargon ("spot densities", "whirlwind", "TRIP DOSSIER PREVIEW") with clean, professional travel phrasing ("sightseeing density to your pace", "Single-day city exploration", "ITINERARY SUMMARY PREVIEW").
     * Fixed spacing, punctuation, and capitalization across `TripInputScreen` and `CraftLoadingDialog`.
* **Verification:**
  * `flutter analyze` completed with 0 errors and 0 warnings.
  * Comprehensive test suite in `test/places_autocomplete_test.dart` passing (9/9 tests).
  * Full test suite (`test/chat_sanitization_test.dart`, `test/craft_itinerary_test.dart`, `test/places_autocomplete_test.dart`) passing (18/18 tests).

### TASK-004: Splash Screen Replacement with "splash page" Image
* **Status:** Completed
* **Branch:** `redesign/craft-itinerary`
* **Description:**
  Replaced the legacy in-app splash screen (logo bounce, tagline animation, progress spinner) with the full-bleed "splash page" image (`assets/images/splash page.png` / `assets/images/splash_page.png`). Updated native Android launch themes and iOS LaunchScreen to match the image's top-edge sky blue color (`#5997C9`), completely eliminating white flashes on cold startup.
* **Key Improvements:**
  1. **Full-Bleed Visual Presentation:**
     * Implemented full-bleed rendering with `BoxFit.cover` on phones and edge-matched background color (`#5997C9`) to eliminate visible bars across all screen aspect ratios.
     * Edge-to-edge transparent system overlay for the status bar and navigation bar.
     * Smooth 350ms fade-out transition before route handover.
  2. **Startup Initialization & Defensive Navigation:**
     * Preserved 100% of startup logic: checks `AppSettingsProvider.isFirstLaunch` for `/onboarding` redirection.
     * Validates Firebase Auth session and hydrates user profile before routing to `/home` or `/login`.
     * Enforced a minimum 1600ms display duration to prevent flickering, with defensive try-finally fallback ensuring the app never hangs indefinitely.
  3. **Zero-Flash Native Splash Alignment:**
     * Configured Android `launch_background.xml` (standard and v21) with `@color/splash_background` (`#5997C9`).
     * Configured iOS `LaunchScreen.storyboard` background color to `#5997C9` (RGB: 0.349, 0.592, 0.788).
     * Completely removed legacy animation controllers, progress indicators, and unused splash UI code.
* **Verification:**
  * `flutter analyze` passed with 0 errors and 0 warnings.
  * Dedicated test suite in `test/splash_screen_test.dart` passing (2/2 tests).
  * Full test suite passing (20/20 tests).

### TASK-005: Complete Groups Feature (Architecture, Real-Time Sync, Shared Itinerary & Location)
* **Status:** Completed
* **Branch:** `redesign/craft-itinerary`
* **Description:**
  Engineered and shipped the full-stack Groups feature for Ghumify, enabling users to create and manage travel groups, plan one shared itinerary together with granular admin permissions, communicate via real-time WhatsApp-style chat with rich stop/location cards, and share one-time and live GPS locations with automatic expiration.
* **Key Improvements:**
  1. **Data Models & Security Rules (`firestore.rules`):**
     * Built models: `GroupModel`, `GroupMemberModel`, `GroupMessageModel`, `GroupLocationModel`, `GroupActivityModel`, and `GroupInvitationModel`.
     * Formal Firestore security rules covering role-based access, permission-gated itinerary edits, append-only activity logs, and live location expiration.
  2. **Membership & Invitation Management (`GroupService` & `GroupProvider`):**
     * Normalized email lookups; automatic member addition for registered users and pending invitations for unregistered users resolved upon sign-in.
     * Admin controls for promotion, demotion, member removal, and group ownership transfer.
  3. **Shared Itinerary with Real-Time Sync (`GroupItineraryTab`):**
     * Single shared group itinerary stored at `groups/{groupId}/group_itineraries/active`.
     * Admin-controlled policies (`admins_only`, `all_members`, `selected_members`).
     * Direct import of personal saved trips into group itineraries.
     * Stop reordering, custom stop creation, deletion, and 1-tap "Share to Chat" functionality.
     * Full audit history sheet (`GroupActivityModel`) logging all itinerary changes.
  4. **WhatsApp-Style Chat with Rich Cards (`GroupChatTab`):**
     * Real-time messaging with unread badges, system events, and sender differentiation.
     * Rich card rendering for location pins (with direct Google Maps intent), live location shares (with antenna radar and countdown timer), and itinerary stops.
     * Attachment drawer for 1-tap sharing of locations and trip stops.
  5. **Privacy-First Live Location Sharing (`GroupLiveMapTab`):**
     * One-time location pins and live location broadcasting (15m, 1h, 8h) with battery-friendly 30s background sync.
     * Haversine distance calculations displaying proximity of members to each other and to upcoming itinerary stops.
     * Auto-expiration and instant manual stop controls.
  6. **Tabbed Shell & Navigation Integration:**
     * Registered `/groups` in `AppRouter` and embedded Groups tab in `MainShell` bottom navigation with unread badges.
     * 4-tab container in `GroupDetailScreen` (Chat, Itinerary, Live Map, Info).
* **Verification:**
  * `flutter analyze` completed with 0 errors.
  * Comprehensive test suite in `test/group_feature_test.dart` passing (12/12 tests).
  * Full project test suite passing (32/32 feature tests).

### TASK-006: Food Preference Selector & Dietary AI Personalization Engine
* **Status:** Completed
* **Branch:** `redesign/craft-itinerary`
* **Description:**
  Added a 5-option radio button group for "Food Preference" across the app (`TripInputScreen` Step 4 and `SettingsScreen`), synced with `UserModel`, `AppSettingsProvider` (offline cache), and Firestore. Built a strict AI prompt injection and post-response validation/enrichment pipeline ensuring all meal stops and AI chatbot suggestions strictly follow dietary constraints (Jain, Veg, Veg + Egg, Non-Veg, All).
* **Key Improvements:**
  1. **Strict 5-Tier Dietary Taxonomy (`lib/core/constants/food_preferences.dart`):**
     * Options in exact order: `Veg`, `Veg + Egg`, `Jain`, `Non-Veg`, `All`.
     * Internal values: `"veg"`, `"veg_egg"`, `"jain"`, `"non_veg"`, `"all"`.
     * Default for legacy and new users: `"all"`.
     * Strictness hierarchy: Jain (4) > Veg (3) > Veg + Egg (2) > Non-Veg (1) > All (0).
     * Clear one-line explanations and colored indicator dots (Green for Veg/Jain, Orange/Yellow for Veg + Egg, Red for Non-Veg, Gray for All).
  2. **Tactile Selector Component (`FoodPreferenceSelector`):**
     * Responsive radio card group with accessible tap targets (min 48dp), semantic radio states, and helper caption: "We will suggest food and restaurants based on your choice."
     * Placed in `TripInputScreen` Step 4 (Passions & Review) and `SettingsScreen` (PREFERENCES tile opening bottom sheet).
     * Instant bidirectional synchronization between local `SharedPreferences` and remote Firestore `users/{uid}`.
  3. **Data Model & Legacy Preservation:**
     * `UserModel`: Default `"all"`; backward-compatible with legacy Firestore records missing the field.
     * `ItineraryModel` & `MultiDayItineraryModel`: Persists the `foodPreference` chosen at time of generation so historical trip fidelity is never lost.
     * `ItineraryStop`: Added `dietaryType` tag for visual badges on food stops.
     * `GroupMemberModel`: Stores each member's personal preference; group itinerary prompt directives harmonize choices and detect Jain vs Non-Veg conflicts.
  4. **Strict AI Prompt Directives & Validation Filter (`GeminiService` & `DietaryFilterService`):**
     * Injected strict rules into `_buildItineraryPrompt`, `_buildMultiDayPrompt`, and `_buildChatPrompt`.
     * Jain stops enforce zero meat, seafood, egg, onion, garlic, or root vegetables, with mandatory disclaimer: *"Please confirm Jain preparation with the restaurant."*
     * Veg stops enforce zero meat, seafood, or egg dishes; dairy allowed; prefers pure veg.
     * Veg + Egg allows eggs but strictly rejects meat and seafood.
     * Post-response validation auto-sanitizes offending items and enriches food cards with visual dietary badges.
     * Chatbot handles explicit conflicting requests (e.g. Veg asking for butter chicken) by politely acknowledging their setting and offering recommendations or preference changes.
* **Verification:**
  * 19 unit tests passing in `test/food_preference_test.dart`.
  * All 51 project unit and feature tests passing.
  * `flutter analyze` completed with 0 errors and 0 warnings.

### TASK-007: OpenStreetMap (OSM) Nearby Safety (Hospitals & Police Stations)
* **Status:** Completed
* **Branch:** `redesign/craft-itinerary`
* **Description:**
  Integrated OpenStreetMap Overpass API into the Itinerary section, Saved Itineraries, and Group Itineraries to discover nearby hospitals, clinics, and police stations. Includes multi-tier radius expansion (3km -> 5km -> 10km), official Google Maps search and turn-by-turn directions buttons, direct phone dialer actions, 24-hour location caching, coordinate rounding for privacy, and offline persistence.
* **Key Improvements:**
  1. **Multi-Element Overpass QL Pipeline (`PlacesService` & `SafetyConstants`):**
     * Queries `nodes`, `ways`, and `relations` with `out center body;` for exact latitude/longitude.
     * Comprehensive tags: `amenity=hospital`, `healthcare=hospital`, `amenity=clinic`, and `amenity=police`.
     * Distinguishes Hospitals from Clinics with dedicated UI badges and icons.
     * Multi-tier radius search starting at 3 km (3000m), auto-widening to 5 km (5000m) and 10 km (10000m) if sparse (<2 results).
     * Deduplication across OSM ways/relations and sorting by Haversine distance. Results capped to top 5 per category.
     * Exponential backoff retry for HTTP 429 and 504 with custom User-Agent (`SafetyConstants.overpassUserAgent`).
  2. **Privacy, Compliance & Attribution:**
     * Coordinates rounded to 3 decimal places (~110m) for privacy and cache hits.
     * Live user location is never stored.
     * Displays emergency notice and clickable "© OpenStreetMap contributors" attribution.
     * Speed-dial pills for national emergency numbers (112, 100, 108).
  3. **Google Maps & Direct Action Integration:**
     * "Open in Google Maps": `https://www.google.com/maps/search/?api=1&query=LAT,LNG`
     * "Directions": `https://www.google.com/maps/dir/?api=1&destination=LAT,LNG`
     * "Call": standard `tel:` intent, shown only when verified phone number exists in OSM tags.
  4. **Saved Itinerary & Groups Offline Persistence:**
     * `ItineraryModel` & `MultiDayItineraryModel`: Stored `nearbySafetyServices` field with full backward compatibility for legacy records (defaults to empty list).
     * Saved itineraries show saved places instantly with "Last updated: [time]" and "Refresh" action.
     * Old saved itineraries render clean empty state with 1-tap "Load nearby hospitals and police stations" button.
     * Group shared itineraries display saved safety places with refresh permission gated by admin policy.
* **Verification:**
  * 13 unit tests passing in `test/nearby_safety_test.dart`.
  * All 62 project feature tests passing.
  * `flutter analyze` passing with 0 errors and 0 warnings.

### TASK-009: Travelers Feature (Adults, Children, Age Bands & Family-Friendly Itineraries)
* **Status:** Completed
* **Branch:** `redesign/craft-itinerary`
* **Description:**
  Engineered and shipped the end-to-end "Travelers" feature across the Craft Itinerary flow, single-day and multi-day itinerary generation, saved itineraries, and group trips. Enables users to specify Adults (18+, min 1, max 20) and Minors/Children (under 18, min 0, max 20) with tactile stepper controls and direct numeric input. When minors are present, users can customize age bands (Infant/Toddler 0–2, Young Child 3–5, Child 6–12, Teen 13–17) or skip to a safe default mix (6–12). Gemini AI prompts adapt pacing, dining, and venue selections (playgrounds, science museums, zoos, parks, no nightlife/bars). Post-response validation deterministically sanitizes any unsuitable places, enforces pace limits, and adds kid-friendly and stroller access tags.
* **Key Improvements:**
  1. **Tactile Travelers Input Component (`TravelersSelector` & `TravelersModel`):**
     * Built dedicated `TravelersSelector` widget in Step 3 ("Group & Budget") of `TripInputScreen`.
     * Tactile +/- steppers with >=44px touch targets, dynamic icon badges, and direct numeric input dialog on value tap.
     * Enforced strict bounds (1–20 adults, 0–20 minors, no negatives or decimals) with friendly limit notifications.
     * Solo trip auto-simplification: selects 1 adult, 0 minors.
     * Collapsible "Age of Children" chips with skippable fallback banner ("If skipped, we plan for a general mix of children ages 6–12").
     * Real-time dynamic summary line (e.g., "2 Adults, 2 Children (Ages 3–5 yrs, 6–12 yrs)").
     * Strict privacy compliance with India's DPDP Act: stores counts and age bands only; never requests or stores names, birth dates, or photos of children.
  2. **Backward-Compatible Data Persistence:**
     * `TravelersModel`: Clean immutable model with serialization to/from Map and Firestore.
     * `ItineraryModel` & `MultiDayItineraryModel`: Added `adultsCount`, `minorsCount`, `minorAgeBands`, `travelersSummary`, `isFamilyFriendly`, and `displayTravelersSummary`.
     * Full backward compatibility: legacy itineraries without travelers fields gracefully default to scalar `travelers` count (or 1 adult, 0 minors) without null reference crashes.
     * `ItineraryStop`: Added `isKidFriendly`, `ageRangeRecommendation`, `strollerAccess`, and `childTicketInfo` fields with safe fallbacks ("Please check on arrival" instead of guessing fake prices or limits).
  3. **AI Generation Directives & Deterministic Post-Response Filter (`FamilyTravelService`):**
     * Injected strict prompt directives into `GeminiService._buildItineraryPrompt` and `_buildMultiDayPrompt`.
     * Adult-only trips (minors = 0) retain existing behavior with zero regressions.
     * Family trips strictly ban nightclubs, bars, pubs, breweries, lounges, and dangerous cliffs, prioritizing parks, zoos, science centres, and early completion (by 8:30 PM).
     * Post-response validation (`validateAndEnrichStops`): automatically replaces forbidden nightlife stops with wholesome cultural gardens, enforces max stops per day (4 for toddlers/infants, 5 for older kids), and tags stroller and ticket information.
  4. **Visual Family Styling Across Screens:**
     * `ItineraryResultScreen` & `MultiDayResultScreen`: "Family-friendly" green header banner, composition pill ("2 Adults, 2 Children"), and stop card chips for "Kid-Friendly", recommended age, stroller access, and child tickets.
     * `SavedItinerariesScreen`: Added traveler composition row with family restroom icon and green badge for family trips.
     * `GroupItineraryTab`: Displays shared group traveler composition banner; permissions enforced so only group admins can modify shared group plans.
* **Verification:**
  * 17 unit tests passing in `test/travelers_feature_test.dart`.
  * `flutter analyze` completed with 0 errors.
  * All 108 existing and new feature tests passing.

### TASK-010: Multi-City Trip Feature (Interactive Route Builder, Inter-City Transit, & Route Optimizer)
* **Status:** Completed
* **Branch:** `redesign/craft-itinerary`
* **Description:**
  Engineered and shipped the end-to-end "Multi-City Trip" feature across the Craft Itinerary wizard, AI generation, and itinerary display. Users can connect 2 to 8 cities in a single journey, configure days per city or auto-distribute, reorder cities with drag handles and accessible up/down buttons, toggle round trips, explore nearby city suggestions based on real coordinates, and optimize route sequencing with "Best order" (with Undo). Inter-city travel legs between consecutive cities display realistic transit options (Train, Bus, Car/Taxi, Domestic Flight) calculated using calibrated Indian tariffs and speeds, with adult and minor fare concessions, transparent "Estimated" tags, and direct official booking links (IRCTC, RedBus, Uber, MakeMyTrip).
* **Key Improvements:**
  1. **Route Builder & City Selection (`MultiCityRouteBuilder` & `CityStayModel`):**
     * Built tactile route builder widget with draggable city cards, stay days steppers, up/down accessibility buttons, between-city transit connectors, and "+" insert buttons.
     * Enforced strict limits (2 to 8 cities, duplicate prevention, min 1 day per city).
     * "Suggest nearby cities" chips calculated from real Haversine distance and road winding factors.
     * "Best order" button using Greedy Nearest-Neighbor heuristic to minimize backtracking, with instant Undo notification.
  2. **Inter-City Transit & Calibrated Fare Engine (`TransportConfig` & `TransportService`):**
     * Rule-based estimation engine adhering to real 2026 Indian tariffs: Train ₹1.60/km (3AC benchmark), Bus ₹1.75/km (AC Semi-Sleeper), Sedan Cab ₹14/km, SUV Cab ₹19/km, Flight ₹3.20/km (above 320km threshold and between 35 commercial airport cities).
     * Transparent data honesty: every option is explicitly tagged `isEstimate: true`, displays data source name and last updated timestamp, with zero hallucinated train/flight numbers or fake operator names.
     * Adult & minor fare concessions: child 50% train/bus fare, private cab vehicle-based split across travelers.
     * Deep-link actions launching official booking portals (IRCTC, RedBus, Uber, MakeMyTrip) without false partnership claims.
  3. **Multi-City Itinerary Generation & Post-Response Validation (`GeminiService`):**
     * City-by-city parallel/sequential generation with real-time UI progress updates ("Planning Jaipur (1 of 3)...").
     * Enforces continuous date sequencing, sequential day numbering (1 to N), lighter arrival schedules on travel transition days, and kid-friendly & dietary filter compliance per city.
  4. **Multi-City Result Screen & UI Updates (`MultiCityResultScreen`):**
     * Route overview banner with numbered city nodes, total days, total distance, and total travel cost badges.
     * City switcher tabs to jump between "Entire Route" and individual city itineraries.
     * Timeline with distinct `TravelLegCard` journey cards separating city sections.
     * Modal `TransportOptionsSheet` allowing travelers to switch preferred modes per leg and update total travel cost immediately.
     * Saved itineraries card in `SavedItinerariesScreen` with "MULTI-CITY" badge and route summary, maintaining 100% backward compatibility for single-city trips.
* **Verification:**
  * 6 dedicated unit tests passing in `test/multi_city_trip_test.dart`.
  * All 114 tests passing across the app suite.
  * Code analysis verified with 0 fatal errors.

### TASK-011: Context-Aware Meal Suggestions (Lunch & Dinner)
* **Status:** Completed
* **Branch:** `main`
* **Description:**
  Engineered and integrated the context-aware "Meal Suggestions" feature into the Ghumify itinerary timeline across single-day, multi-day, and multi-city trips. At Lunch (12:30–14:30) and Dinner (19:00–21:00), the app suggests 2 to 3 real, verified restaurants located near the user's specific route coordinates at that time of day rather than a generic city center point. Restaurant search leverages the OpenStreetMap Overpass API with progressive radius widening, strict 5-tier dietary adherence, minor/family safety rules, and direct keyless external actions.
* **Key Improvements:**
  1. **Configurable Meal Engine (`MealConfig` & `RestaurantService`):**
     * Centralized meal windows (`MealConfig.lunchStart` = 12:30, `MealConfig.lunchEnd` = 14:30, `MealConfig.dinnerStart` = 19:00, `MealConfig.dinnerEnd` = 21:00).
     * Search anchor determination: searches around the exact stop the user is at or travelling from just before the meal window.
     * Progressive multi-tier radius expansion (1 km -> 2 km -> 3 km -> 5 km) with explicit distance and estimated travel time calculated.
     * Overpass query filters `amenity=restaurant`, `amenity=cafe`, and `amenity=fast_food` with dietary tags (`diet:vegetarian`, `diet:vegan`, `diet:jain`, `cuisine`, `opening_hours`, `phone`).
  2. **Dietary & Family Compliance:**
     * Adheres to user's 5 Food Preferences (`veg`, `veg_egg`, `jain`, `non_veg`, `all`).
     * Pure-veg vs veg-options distinction with dual visual indicator (colored dot + text badge).
     * Mandatory Jain advisory note: *"Please confirm Jain preparation with the restaurant"*.
     * Family safety: filters bars, pubs, nightclubs, lounges, and late dinner hours when minors are present.
  3. **Timeline UI & Actions (`MealSuggestionCard`):**
     * Compact cards with restaurant name, cuisine, distance, travel time, verified ratings, opening hours status, and contextual recommendation reason.
     * Actions: Google Maps Search (`https://www.google.com/maps/search/?api=1&query=LAT,LNG`), Directions (`https://www.google.com/maps/dir/?api=1&destination=LAT,LNG`), direct phone dialing (`tel:PHONE`), "Show other options" pagination, and manual refresh.
     * "Add to itinerary": seamlessly inserts an `ItineraryStop` of type `'food'` at target meal times (75 min lunch, 90 min dinner) with undo and replace capabilities.
  4. **Clean Persistence & Backward Compatibility:**
     * `MealSuggestionModel` and `DayMealSuggestions` saved in lightweight form with timestamp and coordinates.
     * Fully backward compatible with legacy itineraries lacking meal suggestions.
* **Verification:**
  * 18 unit and regression tests passing in `test/meal_suggestions_test.dart`.
  * Static analysis verified with 0 fatal errors.

### TASK-012: Split Expenses (Group Spending Tracking, Equal Split, Greedy Settle-Up & Offline Settlements)
* **Status:** Completed
* **Branch:** `main`
* **Description:**
  Engineered and shipped the full-stack "Split Expenses" feature for Ghumify travel groups. Group members can record shared expenses, calculate exact equal shares with zero floating-point errors (integer paise precision), determine who owes whom with greedy transaction minimization, and record offline peer settlements with two-way confirmation. The feature is prominently accessible from the home screen via a dynamic balance card and from within each group via a dedicated "Expenses" tab.
* **Key Improvements:**
  1. **Pure Math & Balance Calculation Engine (`ExpenseCalculator` & `ExpenseCurrencyHelper`):**
     * 100% integer paise precision (1 INR = 100 paise) eliminating floating-point rounding inaccuracies.
     * Deterministic leftover distribution: extra paise distributed lexicographically so shares always sum exactly to total.
     * Net balance calculation per member with zero-sum invariant (`Σ NetBalances == 0`).
     * Greedy settle-up minimization: repeatedly pairs largest debtor with largest creditor to clear all group debts with minimal peer-to-peer transfers.
  2. **Backend & Security (`ExpenseService` & `firestore.rules`):**
     * Firestore security rules restricting expense read/write to current group members (`isGroupMember`).
     * Only creator or group admin can edit or soft-delete an expense.
     * Settlement workflow: debtor marks paid (`status: 'pending'`), creditor confirms or rejects, payer can cancel before confirmation.
     * Chat system notifications and append-only activity audit logging on all expense additions, edits, and settlements.
  3. **UI Components & User Experience:**
     * `SplitExpensesHomeCard`: Home screen entry card displaying dynamic aggregate balance ("You owe" or "You get back" with icon + text), single-group direct launch, multi-group picker sheet, and zero-group empty state.
     * `GroupExpensesTab`: Dedicated tab in `GroupDetailScreen` with 3-column metric card (Total Group Spend, You Paid, Your Share, Net Balance), settle-up cards with "Mark as paid" action, interactive pending settlement alerts, search, and category filters.
     * `AddExpenseScreen`: Tactile expense creation form with live per-person share preview, multi-member checkboxes, and validation.
     * `ExpenseDetailSheet`: Bottom sheet with full audit breakdown, per-person share table, edit & soft-delete capabilities.
     * `MarkPaidDialog`: Clean dialog for recording offline peer settlements.
* **Verification:**
  * 17 unit and regression tests passing in `test/split_expenses_test.dart` covering equal splits, leftover paise, worked examples, edge cases, partial settlements, removed members, late joiners, stress test (100 expenses), and serialization.
  * All 90 unit and regression tests passing across the app suite.

### TASK-013: Nearest-First Proximity Ordering & Accordion Stop Card Redesign
* **Status:** Completed
* **Branch:** `main`
* **Description:**
  Engineered and shipped nearest-first proximity ordering and the stop card redesign inspired by the reference design (`media_1793371671885`). The app now orders unvisited stops by geographic proximity starting from the user's location (or fallback cascade) using a deterministic pure code function. Stops are presented as compact, scannable cards by default showing essential metadata, expanding on tap into an accordion view with Wikimedia image gallery, practical details, brief description, and keyless Google Maps actions.
* **Key Improvements:**
  1. **Pure Ordering Engine (`RouteProximityOptimizer`):**
     * Pure, deterministic nearest-neighbor algorithm in Dart code (never trusted to AI).
     * Haversine spherical distance calculation with 1.25 urban road-winding multiplier.
     * Ties broken deterministically by place name alphabetically.
     * Strict anchored item protection (meals, transit legs, meeting points, hand-pinned stops stay fixed).
     * Opening hours constraint: closed stops shifted after open ones without guessing.
     * Sequential time recalculation with pace buffers and family/minor rest additions.
  2. **Location Fallback & Privacy (`LocationService.resolveStartPoint`):**
     * Cascade: User GPS -> User-picked -> Hotel stay -> City center.
     * Coordinates rounded to 4 decimals (~11m) for privacy; never persisted or sent to external trackers.
     * Start point banner informs user of origin (e.g. "Route starts from your current location").
     * "Re-order by nearest" button with preview and undo; manual reorders strictly preserved.
  3. **Stop Card Redesign (`ItineraryStopCard`):**
     * Pixel-perfect reference match with left category circular node and horizontal card layout.
     * Compact default view with title, single-line info (category, time, duration, distance), thumbnail, category pill, and chevron.
     * Category placeholder icon fallback for stops without photos (no broken image icons).
     * Accordion expansion (single card open at a time for scannability).
     * Swipeable Wikimedia Commons gallery with license attribution and zoom dialog.
     * Verified practical details (hours, entry fee, best time), max 2 short tips (<100 chars), and official keyless Google Maps search & directions links.
  4. **AI Prompt & Response Validation (`GeminiService`):**
     * Prompt enriches `shortLabel`, `briefDescription`, `openingHours`, `ticketPrice`, `bestTimeToVisit`.
     * Word-boundary length clamping: `shortLabel` <= 80 chars, `briefDescription` <= 300 chars, `tips` <= 2 x 100 chars.
     * Full backward compatibility with legacy saved itineraries.
* **Verification:**
  * 12 comprehensive unit and integration tests passing in `test/nearest_first_ordering_test.dart`.
  * Regression test suites passing across all itinerary screens and group tabs.


