# Ghumify UI/UX Design System & Stop Card Specification

## 1. Design Reference & Visual Language
- **Reference Model:** `media_1793371671885.jpg` (Mobile Itinerary view)
- **Aesthetic Principles:**
  - Modern, clean, and scannable interface optimized for mobile travel execution.
  - Left timeline connector line linking circular categorical nodes.
  - Curated categorical color palette with soft pastel tint backgrounds and high-contrast text badges.
  - Smooth micro-interactions for expanding/collapsing stops to prevent layout jumps.

## 2. Itinerary Stop Card Specification

### 2.1 Collapsed Card (Default State)
- **Geometry:** Horizontal card with rounded corners (`16px`), light border (`0.5px #E2E8F0`), elevated card background (`#FFFFFF` in light mode, `#1E293B` in dark mode).
- **Left Timeline Node:**
  - 32x32 circular icon node with category-specific icon and subtle brand tint background (`#EEF2FF`).
  - Vertical timeline connector (`2px #E2E8F0`) between consecutive stops.
- **Thumbnail Image:**
  - 48x48 rounded thumbnail (`10px` radius) with `BoxFit.cover`.
  - Placeholder fallback: Soft category-tinted container with a centered category icon when no photo exists (avoids broken image states or fake stock photos).
- **Typography & Content:**
  - **Title:** Place name in bold outfit typography (`15px`, `FontWeight.w700`), max 2 lines with clean ellipsis truncation.
  - **Subline:** Compact single-line summary (`12px`, muted `#64748B`): Category · Planned Time · Duration · Inter-stop Distance (e.g. `Garden · 10:15 AM · 90 min · 1.2 km`).
- **Category Badge:**
  - Food: Green pill (`#E8F5E9` bg, `#2E7D32` text)
  - Sightseeing / Beach: Blue pill (`#EFF6FF` bg, `#1D4ED8` text)
  - Historical Site / Heritage: Purple pill (`#F5F3FF` bg, `#6D28D9` text)
  - Scenic Spot / Nature: Orange pill (`#FFF7ED` bg, `#C2410C` text)
- **Expand Indicator:** Compact chevron icon (`Icons.keyboard_arrow_down_rounded`, 18px).

### 2.2 Expanded Card (Accordion Tap Interaction)
- **Accordion Policy:** Exactly one card expanded at a time (`_expandedIndex == index`). Tapping an expanded card collapses it; tapping another card collapses the previous one and smoothly opens the new one. This keeps the daily timeline compact and prevents infinite vertical scrolling.
- **Brief Description:** Clamped strictly to 200–300 characters at word boundaries with ellipsis (`...`).
- **Wikimedia Photo Gallery:**
  - Lazy-loaded horizontal swipeable carousel (up to 4–5 licensed photos).
  - Subtle attribution bar citing "Photo via Wikimedia Commons / CC-BY-SA".
  - Tap-to-zoom interactive modal dialog.
- **Verified Practical Details:**
  - Displayed only when verified data exists (no invented numbers):
    - Opening Hours: `Icons.schedule_rounded` with verified time range or "Check on arrival".
    - Ticket Price: `Icons.confirmation_number_outlined` (e.g. `₹50 per adult`).
    - Best Time to Visit: `Icons.wb_sunny_outlined` (e.g. `Morning / Sunset`).
- **Tips:** Maximum 2 concise tips per stop, each under 100 characters.
- **Keyless Action Buttons:**
  - "Open in Google Maps": Keyless official URL `https://www.google.com/maps/search/?api=1&query=LAT,LNG`
  - "Directions": Keyless official URL `https://www.google.com/maps/dir/?api=1&destination=LAT,LNG`
  - Pin Stop: Toggles fixed anchor status (`isPinned: true`) preventing automatic reordering.

## 3. Nearest-First Ordering Rules & Distance Logic
- **Pure Code Engine:** Implemented in `RouteProximityOptimizer.optimizeStopsProximity`.
- **Start Point Fallback Order:**
  1. User GPS location (with user permission; rounded to 4 decimals for privacy; live position never stored).
  2. User-picked custom start point.
  3. Hotel or stay accommodation.
  4. City geographical center.
- **Distance Measure:** Straight-line spherical Haversine formula with 1.25 urban road-winding multiplier. Batched in memory with 0 network calls and cached in the data model.
- **Anchor Protection:** Meals, inter-city travel legs, group meeting points, and hand-pinned stops remain strictly fixed at their scheduled position.
- **Opening Hours:** Closed stops are swapped with the next open unanchored stop.
- **Manual Preservation:** Hand-ordered stops retain custom ordering; user can tap "Re-order by nearest" with preview and undo.


## 4. Responsive Layout & Overflow Prevention Guidelines

### 4.1 Row Content & Dynamic Text Truncation
- **Constrained Row Children:** Every text widget positioned alongside other siblings in a Row (such as titles, email badges, city names, or status pills) must be wrapped in Expanded or Flexible with explicit maxLines: 1 and TextOverflow.ellipsis.
- **Button Text Scaling:** Multi-action button text in side-by-side rows must be wrapped in FittedBox(fit: BoxFit.scaleDown) to prevent horizontal overflow on 320px viewports and high accessibility font scale settings.

### 4.2 Multi-Action Button Groups
- **Wrap over Row:** Any cluster of action buttons (e.g. 'Maps', 'Directions', 'Call', 'Add to itinerary') must use Wrap with spacing: 6 and 
unSpacing: 6 instead of fixed Row(children: ...). This ensures buttons wrap onto a secondary row automatically on narrow screens without RenderFlex exceptions.

### 4.3 Dialogs, Bottom Sheets & Keyboard Safety
- **Dynamic Constraints:** Modals and bottom sheets must use dynamic constraints (maxHeight: MediaQuery.of(context).size.height * 0.85) rather than hardcoded pixel heights (e.g. 680px).
- **Keyboard Resilience:** Centered empty states, reset password dialogs, and forms must wrap their inner column in SingleChildScrollView(physics: BouncingScrollPhysics()) to prevent bottom RenderFlex overflows when the virtual keyboard opens.
- **Auto-Scrolling in Sheets:** For chat bottom sheets (ItineraryChatSheet), message lists must connect auto-scroll callbacks directly to the active ScrollController driving the draggable sheet view.
