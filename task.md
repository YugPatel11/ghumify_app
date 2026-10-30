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



