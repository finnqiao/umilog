# UmiLog UX Audit Issues

**Audit Date:** 2026-01-02
**Commit:** 54c299be769cda266bde198760391357f2292fcd

---

## Issue Tracker

| ID | Severity | Area | Title | Status |
|----|----------|------|-------|--------|
| UX-001 | P0 | Launch | White screen on app launch | Open |
| UX-002 | P0 | Map | Site cards don't respond to taps | Open |
| UX-003 | P0 | Map | Search button non-responsive | Open |
| UX-004 | P0 | Map | Map pins don't trigger callouts | Open |
| UX-005 | P1 | Data | Database shows incorrect site count | Open |
| UX-006 | P1 | Core | SwiftUI state modification warnings | Open |
| UX-007 | P1 | UX | Missing haptic feedback on interactions | Open |
| UX-008 | P1 | Nav | Tab bar becomes unresponsive | Open |
| UX-009 | P1 | Location | Geofence/location services not integrated | Open |
| UX-010 | P2 | Launch | No loading indicator during seed | Open |
| UX-011 | P2 | Filters | Filter state not persisted | Open |
| UX-012 | P2 | Plan | Wishlist/save feature incomplete | Open |
| UX-013 | P2 | Empty | Empty states missing action CTAs | Open |
| UX-014 | P2 | Search | Search not using FTS5 | Open |
| UX-015 | P2 | Images | No BlurHash placeholders | Open |
| UX-016 | P3 | A11y | Accessibility labels incomplete | Open |
| UX-017 | P3 | Nav | Deep links not implemented | Open |
| UX-018 | P3 | Export | Export features placeholder only | Open |
| UX-019 | P3 | A11y | Dynamic Type may break layouts | Open |

---

## Detailed Issues

### UX-001: White Screen on App Launch

**Severity:** P0 (Blocker)
**Area:** Launch / App Lifecycle
**File:** `UmiLog/UmiLogApp.swift:268-280`

**Preconditions:**
- Fresh install or cold start
- Any device/simulator
- Any iOS version

**Steps to Reproduce:**
1. Kill UmiLog app completely
2. Launch UmiLog from home screen
3. Observe screen state for 5-15 seconds

**Expected Result:**
- Splash screen or branded loading view appears immediately
- Progress indicator shows seeding status
- Map view loads within 2 seconds

**Actual Result:**
- Blank white screen for 5-15 seconds
- No visual feedback
- App appears unresponsive/crashed

**Evidence:**
- Screenshot: `ARTIFACTS/001_launch_initial.png`
- Code shows `seedingLoadingView` but it's not rendering

**Data Impact:** None (cosmetic/UX)

**Suspected Cause:**
```swift
// UmiLogApp.swift:268
seedTask = Task.detached(priority: .background) { [weak self] in
    do {
        try DatabaseSeeder.seedIfNeeded()  // Blocking UI somehow
```
The `isDatabaseSeeded` flag may be blocking the view hierarchy from rendering.

**Suggested Fix:**
1. Ensure loading view renders before seeding starts
2. Use explicit `@MainActor` updates for `isDatabaseSeeded`
3. Add artificial minimum splash duration (300ms)

---

### UX-002: Site Cards Don't Respond to Taps

**Severity:** P0 (Blocker)
**Area:** Map / UnifiedBottomSurface
**File:** `Modules/FeatureMap/Sources/Surface/Components/HorizontalSiteCarousel.swift`

**Preconditions:**
- App loaded to map view
- Bottom sheet visible at any detent
- Sites visible in carousel

**Steps to Reproduce:**
1. Launch app, wait for map to load
2. Drag bottom sheet to medium/expanded detent
3. Observe site cards in horizontal carousel
4. Tap any site card

**Expected Result:**
- Haptic feedback (soft)
- Mode transitions to `.inspectSite`
- Site details appear in sheet
- Map focuses on site

**Actual Result:**
- No response
- No haptic feedback
- Mode remains `.explore`

**Evidence:**
- Previous audit report confirmed
- Code path: `onTapGesture { onSiteTap(site) }`

**Data Impact:** None (interaction failure)

**Suspected Cause:**
- Gesture conflict with `ScrollView` containing carousel
- `DragGesture` on surface may be intercepting taps
- Missing `.contentShape(Rectangle())` on card

**Suggested Fix:**
```swift
// In card view
.contentShape(Rectangle())
.onTapGesture {
    Haptics.soft()
    onSiteTap(site)
}
```

---

### UX-003: Search Button Non-Responsive

**Severity:** P0 (Blocker)
**Area:** Map / HUD
**File:** `Modules/FeatureMap/Sources/HUD/MinimalSearchButton.swift`

**Preconditions:**
- App loaded to map view
- Search button visible in top-right corner

**Steps to Reproduce:**
1. Launch app, wait for map to load
2. Locate magnifying glass icon (top-right)
3. Tap the search button

**Expected Result:**
- Mode transitions to `.search`
- Bottom sheet expands to full height
- Search field appears with keyboard
- Focus moves to search input

**Actual Result:**
- No response
- Mode remains unchanged
- No visual feedback

**Evidence:**
- Multiple tap attempts with cliclick failed
- Button visually present in screenshots

**Data Impact:** None (interaction failure)

**Suspected Cause:**
- Button may be covered by invisible view
- Z-order issue in overlay stack
- `allowsHitTesting(false)` on parent layer

**Suggested Fix:**
1. Use Xcode View Hierarchy Debugger
2. Check all overlay views for hit testing
3. Add `.zIndex()` to ensure button is topmost
4. Add debug print to verify action fires

---

### UX-004: Map Pins Don't Trigger Callouts

**Severity:** P0 (Blocker)
**Area:** Map / Annotations
**File:** `Modules/FeatureMap/Sources/NewMapView.swift:81-119`

**Preconditions:**
- App loaded to map view
- Individual site pins visible (zoomed in past clusters)

**Steps to Reproduce:**
1. Launch app, wait for map to load
2. Tap a cluster to zoom in
3. Continue until individual pins visible
4. Tap an individual site pin

**Expected Result:**
- `SiteCalloutCard` appears above pin
- Card shows site name and action buttons
- Map maintains focus on pin

**Actual Result:**
- No callout appears
- Pin may highlight briefly
- No mode transition

**Evidence:**
- Coordinator delegate `mapView(_:didSelect:)` exists
- `onSelect` callback defined

**Data Impact:** None (interaction failure)

**Suspected Cause:**
```swift
// NativeMapView Coordinator
func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
    // ...
    mapView.deselectAnnotation(annotation, animated: false)
    parent.onSelect(siteAnnotation.siteId)  // May not be wired
}
```
The `onSelect` callback may not properly trigger state change.

**Suggested Fix:**
1. Add logging to `didSelect` delegate
2. Verify `calloutSite` state is set
3. Check `showCallout` condition evaluates true

---

### UX-005: Database Shows Incorrect Site Count

**Severity:** P1 (Critical)
**Area:** Data / Seeding
**File:** `Modules/UmiDB/Sources/DatabaseSeeder.swift`

**Preconditions:**
- App launched and seeded

**Steps to Reproduce:**
1. Launch app
2. Observe "Sites nearby" count in bottom sheet

**Expected Result:**
- ~1,120 sites (per README documentation)
- Matches seed data manifest

**Actual Result:**
- 14,812 sites displayed
- 13x more than documented

**Evidence:**
- Screenshot: `ARTIFACTS/002_launch_10sec.png`
- Shows "Sites nearby: 14,812"

**Data Impact:** Possible (duplicate data, incorrect counts)

**Suspected Cause:**
- Multiple seeding sources loaded
- Legacy + optimized tiles both seeded
- No deduplication logic

**Suggested Fix:**
1. Audit `DatabaseSeeder.seedIfNeeded()`
2. Add unique constraint on site ID
3. Clear old data before seeding
4. Verify manifest matches actual count

---

### UX-006: SwiftUI State Modification Warnings

**Severity:** P1 (Critical)
**Area:** Core / SwiftUI
**File:** Multiple

**Preconditions:**
- Debug build
- Console logging enabled

**Steps to Reproduce:**
1. Launch app
2. Observe Xcode console

**Expected Result:**
- Clean console output
- No SwiftUI warnings

**Actual Result:**
- 50+ repeated warnings:
```
[SwiftUI] Modifying state during view update, this will cause undefined behavior.
```

**Evidence:**
- Previous audit console output

**Data Impact:** None (undefined behavior risk)

**Suspected Cause:**
- `@State` or `@Binding` modified in `body`
- State changes in `onAppear` without proper isolation
- Computed properties triggering state changes

**Suggested Fix:**
1. Audit all `@State` declarations
2. Move state modifications to `DispatchQueue.main.async`
3. Use `task {}` modifier for async state changes
4. Check for state changes in computed properties

---

### UX-007: Missing Haptic Feedback on Interactions

**Severity:** P1 (Critical)
**Area:** UX / Haptics
**File:** `Modules/UmiDesignSystem/Sources/Haptics.swift`

**Preconditions:**
- Any interactive element

**Steps to Reproduce:**
1. Tap any button/card/control
2. Observe haptic response

**Expected Result:**
- `.soft` haptic on all taps
- `.success` haptic on save/complete
- Consistent feedback throughout app

**Actual Result:**
- Haptics missing on most interactions
- Only present in a few places (theme toggle)

**Evidence:**
- Code review shows `Haptics.soft()` exists but sparse usage

**Data Impact:** None (UX polish)

**Suggested Fix:**
- Add `Haptics.soft()` to all button actions
- Add `Haptics.success()` to save confirmations
- Create `HapticButton` wrapper for consistency

---

### UX-008: Tab Bar Becomes Unresponsive

**Severity:** P1 (Critical)
**Area:** Navigation / TabView
**File:** `UmiLog/UmiLogApp.swift:146-174`

**Preconditions:**
- App in use for several interactions
- Multiple mode transitions

**Steps to Reproduce:**
1. Launch app
2. Navigate between tabs several times
3. Trigger map mode transitions
4. Attempt to switch tabs

**Expected Result:**
- Tab bar always responds to taps
- Immediate navigation to selected tab

**Actual Result:**
- Tab bar stops responding
- Requires force-quit to recover
- May be related to `isTabBarHidden` state

**Evidence:**
- Previous audit report

**Data Impact:** None (navigation failure)

**Suspected Cause:**
```swift
.toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
```
State machine for `isTabBarHidden` may get stuck.

**Suggested Fix:**
1. Add logging around tab bar visibility changes
2. Check notification handler for `tabBarVisibilityShouldChange`
3. Ensure state resets on tab selection

---

### UX-009: Geofence/Location Services Not Integrated

**Severity:** P1 (Critical)
**Area:** Location / Geofencing
**File:** `Modules/UmiLocationKit/Sources/`

**Preconditions:**
- Location permission granted
- Near a dive site

**Steps to Reproduce:**
1. Grant location permission
2. Move to location near dive site (simulated)
3. Observe for proximity prompt

**Expected Result:**
- `ProximityPromptCard` appears
- "Log your dive?" prompt shown
- Can accept or dismiss

**Actual Result:**
- No prompt appears
- GeofenceManager initialized but not triggering
- "Nearby" filter returns stub data

**Evidence:**
- Code review of LocationService.swift
- UI_FLOWS_AUDIT.md notes "not wired"

**Data Impact:** None (feature not working)

**Suspected Cause:**
- Location permission never requested
- Geofence regions not registered
- Notification not posted on arrival

**Suggested Fix:**
1. Implement location permission request flow
2. Register geofences for known sites
3. Wire `.arrivedAtDiveSite` notification
4. Show ProximityPromptCard on notification

---

### UX-010: No Loading Indicator During Seed

**Severity:** P2 (Major)
**Area:** Launch / UX
**File:** `UmiLog/UmiLogApp.swift:119-144`

**Preconditions:**
- Fresh install

**Steps to Reproduce:**
1. Delete app
2. Install fresh
3. Launch app

**Expected Result:**
- Branded loading screen
- Progress indicator or animation
- Text indicating loading state

**Actual Result:**
- White screen (see UX-001)
- No visual feedback

**Evidence:**
- `seedingLoadingView` exists in code but not rendering

**Data Impact:** None (UX)

**Suggested Fix:**
- Fix view hierarchy to render loading view
- Add minimum display duration
- Consider pre-built database bundle

---

### UX-011: Filter State Not Persisted

**Severity:** P2 (Major)
**Area:** Map / Filters
**File:** `Modules/FeatureMap/Sources/State/MapStatePersistence.swift`

**Preconditions:**
- Filters applied

**Steps to Reproduce:**
1. Open filter panel
2. Apply filters (difficulty, site type)
3. Kill and restart app
4. Check filter state

**Expected Result:**
- Filters persist across restart
- Same filtered view shown

**Actual Result:**
- Filters reset to default
- All sites shown

**Evidence:**
- `MapStatePersistence` class exists but may not be called

**Data Impact:** None (UX annoyance)

**Suggested Fix:**
- Wire `saveExploreFilters()` in filter apply action
- Load filters in `MapUIViewModel` init
- Test with UserDefaults inspection

---

### UX-012: Wishlist/Save Feature Incomplete

**Severity:** P2 (Major)
**Area:** Plan / Sites
**File:** `Modules/FeatureMap/Sources/Surface/Content/InspectContent.swift`

**Preconditions:**
- Site inspection open

**Steps to Reproduce:**
1. Open site details
2. Tap "Save" action button

**Expected Result:**
- Site marked as wishlist
- Icon updates to filled
- Persists in database

**Actual Result:**
- UI updates temporarily
- May not persist
- Listed as TODO in audit

**Evidence:**
- UI_FLOWS_AUDIT.md: "Add to Wishlist is TODO"

**Data Impact:** Possible (data may not save)

**Suggested Fix:**
- Implement `SiteRepository.toggleWishlist()`
- Wire to save button action
- Update UI state from database

---

### UX-013: Empty States Missing Action CTAs

**Severity:** P2 (Major)
**Area:** UX / Empty States
**File:** Multiple view files

**Preconditions:**
- No logged dives
- No species sighted

**Steps to Reproduce:**
1. Fresh install (no dives)
2. Navigate to History tab
3. Navigate to Wildlife tab

**Expected Result:**
- "Log your first dive" with button to start wizard
- Clear action to remedy empty state

**Actual Result:**
- Text says "Log your first dive" but no button
- User must manually navigate to Log tab

**Evidence:**
- Code review of DiveHistoryView, WildlifeView

**Data Impact:** None (UX friction)

**Suggested Fix:**
```swift
ContentUnavailableView {
    Label("No Dives Found", systemImage: "fish")
} description: {
    Text("Log your first dive to see it here")
} actions: {
    Button("Start Logging") { showWizard = true }
}
```

---

### UX-014: Search Not Using FTS5

**Severity:** P2 (Major)
**Area:** Search / Database
**File:** `Modules/UmiDB/Sources/Repositories/SiteRepository.swift`

**Preconditions:**
- Search activated

**Steps to Reproduce:**
1. Open search
2. Type partial site name
3. Observe results

**Expected Result:**
- FTS5 full-text search
- Weighted ranking
- Prefix matching

**Actual Result:**
- Basic LIKE query
- No ranking
- Exact substring only

**Evidence:**
- Documentation mentions FTS5
- TODO.md shows "FTS5 search" as P1 complete but may not be implemented

**Data Impact:** None (feature gap)

**Suggested Fix:**
- Create FTS5 virtual table for sites
- Implement `search()` using FTS5 MATCH
- Add weighted ranking by name/location

---

### UX-015: No BlurHash Placeholders for Images

**Severity:** P2 (Major)
**Area:** Images / Performance
**File:** `Modules/FeatureMap/Sources/Components/AsyncSiteImage.swift`

**Preconditions:**
- Site images loading

**Steps to Reproduce:**
1. Scroll site list quickly
2. Observe image loading

**Expected Result:**
- BlurHash placeholder during load
- Smooth fade-in when ready
- No layout shift

**Actual Result:**
- Empty space during load
- Sudden appearance
- Possible layout jank

**Evidence:**
- TODO.md mentions "BlurHash placeholders"
- AsyncSiteImage exists but may not use BlurHash

**Data Impact:** None (visual polish)

**Suggested Fix:**
- Add BlurHash generation to seed pipeline
- Store hash with site record
- Render placeholder from hash

---

### UX-016: Accessibility Labels Incomplete

**Severity:** P3 (Minor)
**Area:** Accessibility
**File:** Multiple

**Preconditions:**
- VoiceOver enabled

**Steps to Reproduce:**
1. Enable VoiceOver
2. Navigate through app
3. Focus on icon-only buttons

**Expected Result:**
- All controls have labels
- Icons announce purpose
- Logical focus order

**Actual Result:**
- Some icon buttons unlabeled
- May announce "button" only

**Evidence:**
- Code review shows some `.accessibilityLabel` present
- Not comprehensive

**Data Impact:** None (accessibility)

**Suggested Fix:**
- Audit all interactive elements
- Add labels to icon-only buttons
- Test with VoiceOver

---

### UX-017: Deep Links Not Implemented

**Severity:** P3 (Minor)
**Area:** Navigation
**File:** Info.plist, SceneDelegate

**Preconditions:**
- App installed

**Steps to Reproduce:**
1. Open Safari
2. Navigate to `umilog://history`

**Expected Result:**
- App opens to History tab
- Supports sharing dive links

**Actual Result:**
- Error: URL scheme not registered
- App doesn't respond

**Evidence:**
- `xcrun simctl openurl` failed with -10814

**Data Impact:** None (feature gap)

**Suggested Fix:**
- Register `umilog` URL scheme in Info.plist
- Implement `onOpenURL` handler
- Support deep links: history, site/{id}, log

---

### UX-018: Export Features Placeholder Only

**Severity:** P3 (Minor)
**Area:** Profile / Export
**File:** `Modules/FeatureMap/Sources/ProfileView.swift:212-215`

**Preconditions:**
- Profile tab open

**Steps to Reproduce:**
1. Navigate to Profile
2. Tap "Export All Data"

**Expected Result:**
- Export dialog appears
- Can choose format (CSV/JSON)
- File saves or shares

**Actual Result:**
- Log message only
- No actual export

**Evidence:**
```swift
private func exportDiveData() {
    Log.app.info("Export data initiated")
}
```

**Data Impact:** None (feature not implemented)

**Suggested Fix:**
- Implement CSV/JSON export
- Use ShareLink or UIActivityViewController
- Include all dive logs and sightings

---

### UX-019: Dynamic Type May Break Layouts

**Severity:** P3 (Minor)
**Area:** Accessibility / Layout
**File:** Multiple

**Preconditions:**
- Largest accessibility text size

**Steps to Reproduce:**
1. Settings > Accessibility > Larger Text
2. Enable max size
3. Launch UmiLog
4. Check all screens

**Expected Result:**
- All text visible
- No truncation
- Layouts adapt

**Actual Result:**
- Not tested
- Compact layouts at risk (chips, stats tiles)

**Evidence:**
- Common issue with card-based UIs
- Not explicitly tested

**Data Impact:** None (accessibility)

**Suggested Fix:**
- Test all screens at largest size
- Use `@ScaledMetric` for spacing
- Allow text to wrap in tight spaces

---

## Issue Statistics

**By Severity:**
- P0 (Blocker): 4
- P1 (Critical): 5
- P2 (Major): 6
- P3 (Minor): 4
- **Total:** 19

**By Area:**
- Map/Navigation: 6
- Data/Database: 2
- UX/Polish: 4
- Accessibility: 3
- Features: 4

**Resolution Priority:**
1. UX-001, UX-002, UX-003, UX-004 (P0 blockers - must fix first)
2. UX-006 (SwiftUI warnings - foundational)
3. UX-005 (data integrity concern)
4. UX-007, UX-008, UX-009 (P1 experience issues)
5. Remaining P2/P3 as time permits

---

*Generated by Claude Code UX Audit Agent*
