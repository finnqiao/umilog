# UmiLog v2 — Comprehensive Bug Fix & UI Improvement Plan

## Context
User testing of UmiLog v1 revealed critical bugs (crashes, broken navigation, missing map pins), UI/UX issues (overlapping components, lost state, no back navigation), and missing features (location button, unit toggles, crowdsourcing). This plan addresses every item from the feedback document, organized by priority and feature area.

---

## 1. Critical Bugs (Crashes & Broken Core)

### 1.1 App crashes after navigating content menu
- **Root cause:** Likely SwiftUI state mutations during view transitions in the enum-based `MapUIMode` state machine. The `UnifiedBottomSurface` manages 6 content modes with animated transitions — rapid switching may trigger concurrent state updates.
- **Files:** `NewMapView.swift`, `MapUIReducer.swift`, `UnifiedBottomSurface.swift`
- **Fix:** Add `@MainActor` isolation to all mode transitions in `MapUIReducer`. Wrap mode changes in `withTransaction` to batch updates. Add guard clauses preventing mode transitions while an animation is in-flight.

### 1.2 Region pills disappear after tapping and don't recover
- **Root cause:** Pills only show when ALL of: `isWorldView`, `isPeeked`, `isExploreMode`, `notInspecting` are true (`NewMapView.swift:1880-1886`). Tapping a pill navigates to a region → `isWorldView` becomes false → pills vanish. Navigating back doesn't restore world view state.
- **Files:** `NewMapView.swift:1880-1886`, `PopularRegionChips.swift`
- **Fix:** Change visibility logic — pills should show whenever user is in explore mode regardless of zoom level. When zoomed into a region, show that region's pill as "selected" and allow tapping another pill to switch regions. Only hide pills when in inspect/filter/search modes.

### 1.3 "65 sites nearby" but nothing on map
- **Root cause:** Site count comes from a text query (nearby radius search) but map pins load via viewport bounds (`fetchInBounds`). If the map is at world zoom (0°,0°), the viewport query returns different results than the nearby-count query. Lazy loading caps at 500 sites per viewport.
- **Files:** `SiteRepository.swift:84-169`, `NewMapView.swift:730-755`, `MapViewModel.swift`
- **Fix:** When a region is selected, auto-zoom the map to that region's bounds so viewport query aligns with displayed count. Ensure the site count label reflects actual visible pins, not a separate query.

### 1.4 Saved/Logged/Planned tabs all show same screen
- **Root cause:** Tabs apply a `FilterLens` to the same dataset, but if no dives are logged/saved/planned, the filter returns empty and falls back to showing the generic "Popular Regions" explorer view.
- **Files:** `NewMapView.swift:1995-2002`, `FilterContent.swift:84-100`
- **Fix:** Show proper empty states per tab ("No saved sites yet — tap the heart on any dive site to save it", etc.) instead of falling back to the explore view. Each tab should be clearly differentiated even when empty.

### 1.5 Explore/Trips/Near Me buttons non-functional
- **Root cause:** `MapEntryMode` enum exists with `.explore`, `.trips`, `.nearMe` but the UI handlers may not be wired to actual data loading for Trips and Near Me.
- **Files:** `MapEntryMode.swift`, `NewMapView.swift:962-974`
- **Fix:** Wire Trips mode to load saved `Trip` objects from the database. Wire Near Me to request location permission and filter sites by proximity (reuse `fetchNearby()` from `SiteRepository`).

---

## 2. Map View UI Fixes

### 2.1 Grey landing page — no default region
- **Root cause:** Map initializes at (0°, 0°) world view. `FeaturedDestinationService` only triggers for first launch; returning users see empty ocean.
- **Files:** `NewMapView.swift:325-328`, `FeaturedDestinationService`
- **Fix:** On launch, if user has location permission → center on their location. If no permission → center on nearest popular region or last-viewed region (persisted via `MapStatePersistence`). Never show empty ocean as default.

### 2.2 Remove Log Dive FAB from map
- **Root cause:** `QuickCaptureFAB.swift` renders a floating button on the map.
- **Files:** `QuickCaptureFAB.swift`, `NewMapView.swift:1782-1804`
- **Fix:** Remove `QuickCaptureFAB` from the map overlay entirely. Dive logging entry points become: (a) Log tab in bottom tab bar, (b) "Log" button on dive site detail page (already exists with pre-fill).

### 2.3 Add "My Location" button
- **Root cause:** No location-center button exists anywhere in the UI. `recenterMap()` recenters on last fitted region, not user location.
- **Files:** `NewMapView.swift:1768` (overlay controls area), `LocationService.swift`
- **Fix:** Add a location button (standard iOS arrow icon) to the bottom-right of the map, above the bottom sheet peek. On tap: request location if needed → animate map to user's coordinates with ~500m zoom. Use `LocationService.getCurrentLocation()`.

### 2.4 Move search button to bottom-right
- **Root cause:** Currently at top-right (`NewMapView.swift:1853-1862`).
- **Files:** `MinimalSearchButton.swift`, `NewMapView.swift:1853-1862`
- **Fix:** Move to bottom-right, stacked above the location button with 12pt spacing. Both buttons bottom-right, properly spaced above the bottom sheet.

### 2.5 Region pills flush to top
- **Root cause:** Padding calculation includes `safeAreaInsets.top + 8 + 44 + 12` which adds space for the (now-relocated) search button.
- **Files:** `NewMapView.swift:1815, 1842-1851`
- **Fix:** With search button moved to bottom-right, pills can sit flush at `safeAreaInsets.top + 8` only.

### 2.6 Dive shops need distinct markers
- **Root cause:** Shops use same `DiveMapAnnotation.Kind = .site` as dive sites (`NewMapView.swift:757-770`).
- **Files:** `NewMapView.swift:757-770`, `DiveMapView.swift` (MapLibre annotation rendering)
- **Fix:** Add a `.shop` case to `DiveMapAnnotation.Kind`. Render shops with a distinct icon (e.g., storefront/building icon) and different color. In MapLibre layer, add a separate symbol layer for shops.

---

## 3. Bottom Sheet & Navigation Redesign

### 3.1 Redesign bottom sheet as collapsible panel
- **Root cause:** Current `UnifiedBottomSurface` overlaps with pills and tab bar. Too many overlapping layers.
- **Files:** `UnifiedBottomSurface.swift`, `NewMapView.swift:1273-1474`
- **Fix — Full-width opaque panel:**
  - **Peek state:** Small handle/arrow visible just above the tab bar (~44pt). Shows region name or "Explore" label.
  - **Half-screen:** On tap or swipe up, expands to 50% screen height. Shows the explore/inspect/filter content.
  - **Full-screen:** Expand button or continued swipe fills the screen (minus status bar). Full content with scroll.
  - **Dismiss:** Swipe down returns to peek → half → peek. Or tap the map area above to collapse.
  - Keep existing detent system (`.hidden`, `.peek`, `.medium`, `.expanded`) but adjust heights and transitions.
  - **Full-width opaque container** with solid dark background matching app theme. No blur/transparency — clean visual separation from the map. Remove Liquid Glass styling from the bottom sheet.

### 3.2 Tab bar always flush to bottom, content above it
- **Root cause:** Filter buttons and bottom sheet content render at the same z-level as the tab bar.
- **Files:** `UmiLogApp.swift:356-393`, `FilterContent.swift`
- **Fix:** Ensure all bottom sheet content has `padding(.bottom, tabBarHeight)` so nothing renders behind the tab bar. The tab bar stays at the absolute bottom at all times. Remove the current tab-bar-hiding logic for expanded state — instead, keep tab bar visible and let content scroll above it.

### 3.3 Add back navigation / breadcrumb persistence
- **Root cause:** Enum-based `MapUIMode` state machine has no history stack. Dismissing resets to default `ExploreContext`.
- **Files:** `MapUIMode.swift`, `MapUIReducer.swift`
- **Fix:** Maintain a navigation history stack (`[MapUIMode]`). Add explicit back button to the bottom sheet header. On dismiss, pop to previous mode instead of resetting to root. Limit stack depth to ~5 to prevent memory bloat.

---

## 4. Filters Cleanup

### 4.1 Rename "My Sites" → "Sites"
- **File:** `FilterContent.swift:86`
- **Fix:** Change `Text("My Sites")` to `Text("Sites")`

### 4.2 Remove "Time Period" filter
- **File:** `FilterContent.swift:190-211`
- **Fix:** Remove the Time Period section entirely. Date-based sorting can be added later as a sort option, not a filter.

### 4.3 Add "Other" to Site Type
- **Files:** `DiveSite.swift:93-100` (enum), `FilterContent.swift:157-176`
- **Fix:** Add `.other` case to `SiteType` enum. Add corresponding filter chip. Run a database migration to support the new enum value.

### 4.4 Fix hardcoded region site counts
- **Root cause:** `RegionSummary.popular` has hardcoded counts (Caribbean: 500, Red Sea: 200, etc.)
- **Files:** `RegionSummary.swift`
- **Fix:** Replace hardcoded counts with actual database queries. Add `SiteRepository.countByRegion()` method. Fall back to "—" if count unavailable, never show fake numbers.

---

## 5. Dive Site Detail Improvements

### 5.1 Missing descriptions — empty state
- **File:** `InspectContent.swift:77-84`
- **Fix:** When description is nil/empty, show a subtle placeholder: "No description available yet" in muted text. Optionally add "Contribute a description" CTA for crowdsourcing later.

### 5.2 Generic images by dive type
- **Files:** `AsyncSiteImage.swift:128-143`, `SiteImage.swift`
- **Current state:** Already has type-based gradient fallbacks (reef: water waves, wreck: amber, etc.)
- **Fix:** The gradient fallbacks are functional. Optionally enhance with curated stock photos per type (one photo per SiteType) bundled in the app assets. This is low priority since the gradient system works.

---

## 6. Dive Logging Improvements

### 6.1 Add 60+ minute bottom time pill
- **File:** `QuickLogView.swift` (time pills array)
- **Fix:** Add `70`, `80`, `90` pills or a single `60+` pill that opens a custom input. Simplest: extend pills to `[30, 40, 45, 50, 60, 75, 90]`.

### 6.2 Temperature unit toggle (°C / °F)
- **Files:** `QuickLogView.swift:382`, `LiveLogWizardView.swift`
- **Fix:** Add a unit preference in Profile/Settings (stored in `@AppStorage`). Display and accept input in user's preferred unit. Convert to Celsius for storage. Show unit label dynamically.

### 6.3 Visibility unit toggle (m / ft)
- **Files:** `QuickLogView.swift:403`, `LiveLogWizardView.swift`
- **Fix:** Same approach as temperature — user preference stored, display in preferred unit, store in meters.

### 6.4 Allow custom dive sites (not just database)
- **Current state:** Already supports GPS-based logging + `CreateSiteFromGPSView` for naming custom sites.
- **Fix:** Also allow free-text site name entry without GPS (for logging past dives at sites not in DB). Add a "Can't find your site? Enter manually" option in the site picker.

### 6.5 Rethink live log flow
- **Root cause:** The 4-step wizard asks for depth/duration/pressure up front — impossible to know mid-dive.
- **Files:** `LiveLogWizardView.swift`
- **Fix:** Build full "Start Dive" timer flow:
  1. **Pre-dive:** Select site (or GPS) + tap "Start Dive". Start time auto-captured.
  2. **During dive:** App tracks elapsed time in background. Minimal/no UI needed (phone in bag).
  3. **Surface:** Local notification: "Welcome back! Ready to log your dive?"
  4. **Post-dive logging:** Opens wizard with site + start time + duration pre-filled. User confirms/adjusts depth, adds notes, wildlife, buddy.
  - Uses `BackgroundTasks` framework for reliable timer + `UNUserNotificationCenter` for the reminder.
  - If user ignores notification, show badge on Log tab + reminder on next app open.
  - This matches real diver behavior (log after surfacing, not during).

---

## 7. Planning Feature (PADI/SSI)

### 7.1 Enhance trip planning with dive planning fields
- **Current state:** Basic itinerary (list of sites + trip name).
- **Files:** `PlanContent.swift`, `Trip.swift`
- **Fix:** Add optional dive planning fields per planned site:
  - Target depth, planned bottom time, gas mix (Air/Nitrox %), surface interval
  - These are all optional — casual divers skip them, technical divers use them
  - No need for decompression calculations in v2, just data capture

---

## 8. Future Features (Minimal v2 Scope)

### 8.1 Crowdsource site elevation
- **Current:** Users can create sites from GPS, but they stay personal.
- **v2 scope:** Track `visitedCount` across all users (requires CloudKit). If a user-created site gets 3+ independent logs at similar coordinates, flag it for potential inclusion in the main database. Full implementation is a backend feature — for now, just ensure the data model supports it.

### 8.2 Hot locations / trending
- **v2 scope:** Skip for now. Requires multi-user analytics infrastructure. Can revisit when CloudKit sync is more mature.

### 8.3 Send to dive shop
- **v2 scope:** Skip for now. Models exist (`DiveShop`, `ShopRepository`). UI can be added in a future release.

---

## Implementation Order

| Phase | Items | Estimated Scope |
|-------|-------|-----------------|
| **Phase A: Critical Bugs** | 1.1 crashes, 1.2 pills vanish, 1.3 missing pins, 1.4 tab filters, 1.5 non-functional buttons | High priority, fix first |
| **Phase B: Map UI** | 2.1 default region, 2.2 remove FAB, 2.3 location button, 2.4 search position, 2.5 pills flush, 2.6 shop markers | Medium-large, visual impact |
| **Phase C: Bottom Sheet** | 3.1 redesign, 3.2 tab bar z-order, 3.3 back navigation | Largest single change |
| **Phase D: Quick Wins** | 4.1-4.4 filter fixes, 5.1 empty states, 6.1 pills, 6.2-6.3 units | Small, independent changes |
| **Phase E: Logging** | 6.4 custom sites, 6.5 live log rethink, 7.1 planning fields | Medium, feature work |

---

## Key Files Reference

| Area | File | Path |
|------|------|------|
| Main map | NewMapView.swift | `Modules/FeatureMap/Sources/NewMapView.swift` |
| Map state | MapUIReducer.swift | `Modules/FeatureMap/Sources/State/MapUIReducer.swift` |
| Map modes | MapUIMode.swift | `Modules/FeatureMap/Sources/State/MapUIMode.swift` |
| Bottom sheet | UnifiedBottomSurface.swift | `Modules/FeatureMap/Sources/Surface/UnifiedBottomSurface.swift` |
| Region pills | PopularRegionChips.swift | `Modules/FeatureMap/Sources/HUD/PopularRegionChips.swift` |
| FAB (remove) | QuickCaptureFAB.swift | `Modules/FeatureMap/Sources/HUD/QuickCaptureFAB.swift` |
| Search button | MinimalSearchButton.swift | `Modules/FeatureMap/Sources/HUD/MinimalSearchButton.swift` |
| Filters | FilterContent.swift | `Modules/FeatureMap/Sources/Surface/Content/FilterContent.swift` |
| Site detail | InspectContent.swift | `Modules/FeatureMap/Sources/Surface/Content/InspectContent.swift` |
| Quick log | QuickLogView.swift | `Modules/FeatureLiveLog/Sources/QuickLogView.swift` |
| Log wizard | LiveLogWizardView.swift | `Modules/FeatureLiveLog/Sources/LiveLogWizardView.swift` |
| Site model | DiveSite.swift | `Modules/UmiDB/Sources/Models/DiveSite.swift` |
| Region counts | RegionSummary.swift | `Modules/UmiDB/Sources/Models/RegionSummary.swift` |
| Site repo | SiteRepository.swift | `Modules/UmiDB/Sources/Repositories/SiteRepository.swift` |
| App entry | UmiLogApp.swift | `UmiLog/UmiLogApp.swift` |
| Location | LocationService.swift | `Modules/UmiLocationKit/Sources/LocationService.swift` |
| Trip planning | PlanContent.swift | `Modules/FeatureMap/Sources/Surface/Content/PlanContent.swift` |

## Verification

After each phase:
1. Build: `cd /Users/finn/dev/umilog && xcodegen generate && xcodebuild -scheme UmiLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
2. Manual test on simulator: launch app, verify no grey screen, tap pills, navigate tabs, log a dive, check filters
3. Crash test: rapidly switch between tabs, open/close bottom sheet, tap pills in sequence
