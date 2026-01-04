# UmiLog Documentation Gaps

**Audit Date:** 2026-01-02

This document lists missing specifications, unclear behaviors, and proposed defaults.

---

## Missing Feature Specifications

### GAP-001: Trip Planning Feature (PlanContent)
**Location searched:** `FeatureMap/Sources/Surface/`, `project.yml`
**What's missing:** No spec for what "Plan Trip" should do
**Observed:** Button shows "Coming Soon" toast
**Proposed default:** N/A - feature explicitly marked as future

### GAP-002: Apple Watch Integration
**Location searched:** `ProfileView.swift`, project-wide
**What's missing:** No spec for Watch integration
**Observed:** UI row present ("Connect Apple Watch") but no implementation
**Proposed default:** Mark as "Coming Soon" in UI or remove row

### GAP-003: CSV/UDDF Import
**Location searched:** `ProfileView.swift`, `SettingsView.swift`
**What's missing:** Import format spec, mapping logic
**Observed:** UI row present but no implementation
**Proposed default:** Mark as "Coming Soon" or implement basic CSV parse

### GAP-004: Backfill Past Dives
**Location searched:** `ProfileView.swift`
**What's missing:** UX for bulk dive entry
**Observed:** UI row present with no action
**Proposed default:** Link to wizard or batch entry screen

---

## Unclear Behavior Specifications

### GAP-010: First Launch Loading Duration
**Location searched:** `UmiLogApp.swift`, `AppDatabase.swift`
**Expected behavior:** Branded loading screen during DB seeding
**Actual behavior:** White screen for 5-15 seconds
**Proposed specification:**
- Show `SeedingLoadingView` immediately on launch
- Move `AppDatabase.seedIfNeeded()` to background
- Target: < 3 second load to interactive

### GAP-011: Map Cluster Tap Behavior
**Location searched:** `NewMapView.swift`, `MapClusterFeatureState`
**What's unclear:** Should cluster tap zoom or open detail?
**Observed:** Expected zoom behavior, but clusters appear non-responsive
**Proposed specification (per Apple Maps):**
- Tap cluster → Zoom to show child pins
- Tap single pin → Show callout overlay

### GAP-012: Site Callout Actions
**Location searched:** `SiteCalloutCard.swift`
**What's unclear:** All available actions
**Observed:** "View Details", "Log Dive", wishlist toggle
**Proposed specification:**
- Primary: "View Details" → InspectContent
- Secondary: "Log Dive" → Wizard with pre-selected site
- Tertiary: Wishlist toggle (heart icon)

### GAP-013: Proximity Prompt Frequency
**Location searched:** `GeofenceManager.swift`, `ProximityPromptCard.swift`
**What's unclear:** How often should prompt appear?
**Observed:** Implementation exists but frequency logic unclear
**Proposed specification:**
- Once per site per session
- Cooldown: 30 minutes after dismiss
- Never repeat for same site on same day

### GAP-014: Wildlife "This Area" Scope
**Location searched:** `WildlifeView.swift`, `WildlifeViewModel.swift`
**What's unclear:** Exact area definition
**Observed:** Uses map viewport bounds from notification
**Proposed specification:**
- "This area" = current visible map viewport
- If user on Wildlife tab and map not visible, show hint
- Update when map pans (already implemented via notification)

### GAP-015: Empty State CTAs
**Location searched:** All view files
**What's unclear:** Consistent empty state behavior
**Observed:** Some views have CTAs, others just show message
**Proposed specification:**
- History empty: "Start Logging" → LogLauncher (implemented)
- Wildlife "This area" empty: "Explore the map to see species here"
- Profile 0 dives: Stats show 0, no special messaging
- Map 0 sites in viewport: "Zoom out or search to find sites"

### GAP-016: Dive Deletion Confirmation
**Location searched:** `DiveHistoryView.swift`
**What's unclear:** Should deletion require confirmation?
**Observed:** Swipe delete action with no confirmation dialog
**Proposed specification:**
- Single swipe reveals "Delete" button (destructive style)
- Tap "Delete" → Immediate delete (standard iOS pattern)
- Optional: Add undo toast for 3 seconds

---

## Missing Error Handling Specifications

### GAP-020: Database Seeding Failure
**Location searched:** `AppDatabase.swift`
**What's unclear:** Behavior when seeding fails
**Proposed specification:**
- Show error alert with retry option
- Allow app to function with empty DB
- Log error for debugging

### GAP-021: Location Permission Denial
**Location searched:** `QuickLogView.swift`, `LocationService.swift`
**What's unclear:** Full denial flow
**Observed:** Alert prompts to open Settings
**Proposed specification:**
- Show alert explaining why location helps
- Provide "Open Settings" action
- Allow GPS features to be skipped gracefully

### GAP-022: Export/Import Failure
**Location searched:** `SettingsView.swift`
**What's unclear:** Error recovery
**Observed:** Alert shows error message
**Proposed specification:**
- Export fail: "Export failed: [error]. Try again?"
- Import fail: "Import failed: [error]. Check file format."
- Import partial: "Imported X dives. Skipped Y duplicates."

---

## Missing Accessibility Specifications

### GAP-030: VoiceOver Labels
**Location searched:** All view files
**What's unclear:** Comprehensive VoiceOver support
**Observed:** Some views have labels, many don't
**Proposed specification:**
- All interactive elements must have `accessibilityLabel`
- Complex views should have `accessibilityHint`
- Map pins: "Dive site: [name], [difficulty]"
- Species cards: "[name], [category], seen [N] times"

### GAP-031: Dynamic Type Support
**Location searched:** All view files
**What's unclear:** Layout behavior at large text sizes
**Observed:** Some fixed widths may break
**Proposed specification:**
- All text views use `.font(.body)` or similar scalable fonts
- Fixed-width containers must accommodate 200% text
- Test at Accessibility > Larger Text > Maximum

---

## Missing Performance Specifications

### GAP-040: Map Loading Performance
**Location searched:** `NewMapView.swift`
**What's unclear:** Target load times
**Proposed specification:**
- Initial map render: < 1 second
- Pin clustering: < 500ms for 15K sites
- Pan/zoom: 60fps maintained

### GAP-041: Database Query Performance
**Location searched:** Repository files
**What's unclear:** Query timeout/limits
**Proposed specification:**
- Search queries: < 100ms
- List fetches: < 200ms
- Pagination: 50 items per page for large lists

---

## Data Model Clarifications Needed

### GAP-050: Dive Log Required Fields
**Location searched:** `DiveLog.swift`, `LogDraft.swift`
**Current required:** siteId OR GPS, maxDepth, bottomTime
**Proposed specification:**
| Field | Required | Default |
|-------|----------|---------|
| siteId | No (GPS alternative) | nil |
| date | Yes | Current date |
| startTime | Yes | Current time |
| maxDepth | Yes | N/A |
| bottomTime | Yes | N/A |
| startPressure | No | 200 bar |
| endPressure | No | 50 bar |
| temperature | No | 26°C |
| visibility | No | 15m |

### GAP-051: Site Wishlist vs Visited State
**Location searched:** `DiveSite.swift`
**What's unclear:** Relationship between wishlist and visited
**Proposed specification:**
- Wishlist: User wants to dive here (toggle)
- Visited: User has logged a dive here (computed from visitedCount > 0)
- On first dive at wishlist site: Auto-clear wishlist flag

---

## Navigation/Routing Clarifications

### GAP-060: Deep Link Schema
**Location searched:** `project.yml`, `Info.plist`, app files
**What's missing:** No deep link handling implemented
**Proposed specification:**
```
umilog://site/{siteId}     → Open map centered on site
umilog://dive/{diveId}     → Open dive detail
umilog://log?site={siteId} → Open wizard with site
```

### GAP-061: Tab Restoration
**Location searched:** `UmiLogApp.swift`
**What's unclear:** Should app remember last tab?
**Observed:** Always opens to Map tab
**Proposed specification:**
- Persist last active tab
- Restore on next launch
- Exception: After dive save, always go to History

---

## Summary Table

| Gap ID | Category | Severity | Resolution Needed |
|--------|----------|----------|-------------------|
| GAP-001 | Feature | Low | Label as future |
| GAP-002 | Feature | Medium | Label or remove |
| GAP-003 | Feature | Medium | Label or implement |
| GAP-004 | Feature | Medium | Label or implement |
| GAP-010 | Behavior | **High** | Fix loading screen |
| GAP-011 | Behavior | **High** | Fix tap handling |
| GAP-012 | Behavior | Medium | Document |
| GAP-013 | Behavior | Medium | Implement limits |
| GAP-014 | Behavior | Low | Add hint text |
| GAP-015 | Behavior | Medium | Standardize CTAs |
| GAP-016 | Behavior | Low | Document pattern |
| GAP-020 | Error | Medium | Add retry logic |
| GAP-021 | Error | Low | Already handled |
| GAP-022 | Error | Low | Already handled |
| GAP-030 | A11y | Medium | Add labels |
| GAP-031 | A11y | Medium | Test layouts |
| GAP-040 | Perf | Low | Define targets |
| GAP-041 | Perf | Low | Add pagination |
| GAP-050 | Data | Low | Document |
| GAP-051 | Data | Low | Document |
| GAP-060 | Nav | Low | Future feature |
| GAP-061 | Nav | Low | Implement |
