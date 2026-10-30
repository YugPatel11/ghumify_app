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
* **Verification:**
  * `flutter analyze` completed with 0 errors and 0 warnings.
  * Unit tests in `test/chat_sanitization_test.dart` passing (6/6).
  * Widget tests in `test/craft_itinerary_test.dart` passing (3/3).

