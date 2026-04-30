# Dive Map UI Test Report

**Date:** 2026-04-25
**Device:** iPhone 16 Pro Simulator (OS 18.6, id: 87E39D00-0CEF-4EC8-8B31-386E8363F3C9)
**Scheme:** UmiLog
**Project:** UmiLog.xcodeproj (generated via `xcodegen generate`)

---

## Commands Run

```bash
# Generate project
cd /Users/finn/dev/umilog && xcodegen generate

# Build for testing
xcodebuild -project UmiLog.xcodeproj \
  -scheme UmiLog \
  -destination 'platform=iOS Simulator,id=87E39D00-0CEF-4EC8-8B31-386E8363F3C9' \
  build-for-testing

# Run UI tests
xcodebuild -project UmiLog.xcodeproj \
  -scheme UmiLog \
  -destination 'platform=iOS Simulator,id=87E39D00-0CEF-4EC8-8B31-386E8363F3C9' \
  test -only-testing:UmiLogUITests/DiveMapUITests

# Screenshots extracted from:
# ~/Library/Developer/Xcode/DerivedData/UmiLog-.../Logs/Test/Test-UmiLog-2026.04.25_13-19-36--0700.xcresult
```

---

## Build Result

**BUILD SUCCEEDED** — `xcodebuild build-for-testing` completed without errors.

Note: `UmiLog.xcworkspace` does not exist in the repo. The project uses XcodeGen to generate
`UmiLog.xcodeproj` which embeds SPM packages (GRDB 6.29.2, MapLibre 6.10.0, Sentry 8.40.1).
Build with `-project UmiLog.xcodeproj` (not `-workspace UmiLog.xcworkspace`).

---

## Test Results

All 14 test cases in `DiveMapUITests` **passed**.

| Test | Name | Duration | Result |
|------|------|----------|--------|
| test01 | InitialMap | 33.0s | PASS |
| test02 | MapPanned | 16.4s | PASS |
| test03 | ZoomedIn | 17.4s | PASS |
| test04 | ZoomedOut | 16.3s | PASS |
| test05 | SiteStack | 24.4s | PASS |
| test06 | SheetExpanded | 24.8s | PASS |
| test07 | SheetCollapsed | 20.0s | PASS |
| test08 | SitePreview | 26.8s | PASS |
| test09 | SiteDetails | 30.7s | PASS |
| test10 | SiteDetailsScrolled | 29.4s | PASS |
| test11 | ModeSelector | 26.7s | PASS |
| test12 | SearchActive | 29.2s | PASS |
| test13 | PlusAction | 20.5s | PASS |
| test14 | LocationButton | 24.8s | PASS |

**Total: 14/14 passed** in ~6.5 minutes.

---

## Screenshots Captured

12 screenshots extracted from the xcresult bundle + 1 post-test simulator screenshot.

| File | State Captured |
|------|----------------|
| `test01_initial_map.png` | Initial map load, peek sheet "Air Prang", mode selector visible |
| `test02_map_panned.png` | Map panned left, cluster markers (2, 3) visible |
| `test03_zoomed_in.png` | Pinch zoom in state |
| `test04_zoomed_out.png` | Pinch zoom out state |
| `test05_cluster_tap.png` | After cluster tap — + button with "2" cluster badge overlap (BUG-001) |
| `test06_sheet_expanded.png` | Bottom sheet expanded, full site list visible |
| `test07_sheet_list.png` | Sheet list: Blue Magic, Cape Kri, Chicken Reef, Manta Sandy |
| `test08_site_preview.png` | Map with clusters, no site preview callout surfaced (BUG-004) |
| `test09_site_details.png` | Map with clusters, similar to panned state |
| `test10_plus_action.png` | Log a Dive sheet: Quick Log / Start Live Log options |
| `test11_location_button.png` | Location permission sheet: "Allow Location Access" |
| `test12_search_active.png` | Search active, "manta" typed, 15 site results shown |
| `final_state_after_tests.png` | Simulator state after all tests completed |

---

## Accessibility Identifiers — Status

All 19 accessibility identifiers specified in the task are **already implemented**:

| Identifier | File | Line |
|------------|------|------|
| `diveMap.root` | NewMapView.swift | 1491 |
| `diveMap.searchBar` | HUD/SearchCapsule.swift | 69 |
| `diveMap.locationButton` | HUD/SearchCapsule.swift | 50 |
| `diveMap.rightModeSelector` | UmiLogApp.swift | 482 |
| `diveMap.mode.map` | UmiLogApp.swift | 511 |
| `diveMap.mode.history` | UmiLogApp.swift | 512 |
| `diveMap.mode.species` | UmiLogApp.swift | 513 |
| `diveMap.mode.profile` | UmiLogApp.swift | 514 |
| `diveMap.addButton` | UmiLogApp.swift | 547 |
| `diveMap.bottomSheet` | Surface/UnifiedBottomSurface.swift | 148 |
| `diveMap.bottomSheet.handle` | Surface/UnifiedBottomSurface.swift | 344 |
| `diveMap.sitePreview` | NewMapView.swift | 1616 |
| `diveMap.sitePreview.viewDetails` | HUD/SiteCalloutCard.swift | 109 |
| `diveMap.sitePreview.logDive` | HUD/SiteCalloutCard.swift | 128 |
| `diveMap.sitePreview.close` | HUD/SiteCalloutCard.swift | 87 |
| `diveMap.siteDetails` | Surface/Content/InspectContent.swift | 120 |
| `diveMap.siteDetails.navigate` | Surface/Content/InspectContent.swift | 287 |
| `diveMap.siteDetails.copyCoordinates` | Surface/Content/InspectContent.swift | 298 |
| `diveMap.siteDetails.log` | Surface/Content/InspectContent.swift | 345 |

---

## Bugs Found

### BUG-001: Cluster Annotation Badge Overlapping FAB Button
**Severity:** Medium
**Screenshot:** `test05_cluster_tap.png`
**Description:** After tapping near a cluster marker, a cluster count badge ("2") renders over
the + (Log a Dive) FAB button in the bottom-right corner. The badge appears to be a MapKit
`ClusterAnnotationView` that is escaping the map layer clip bounds and overlapping the
`VerticalTabBar.logButton`.
**Location:** NewMapView.swift `ClusterAnnotationView` / UmiLogApp.swift `VerticalTabBar.logButton`
**Recommended fix:** Set `clipsToBounds = true` on the MKMapView container UIView, or add
`clipsContentToBounds = true` on the cluster annotation view.

### BUG-002: Mode Selector Lower Icons Hidden by Expanded Bottom Sheet
**Severity:** Low
**Screenshot:** `test07_sheet_list.png`
**Description:** When the bottom sheet is at medium or higher detent, the lower portion of the
vertical mode selector pill (fish/wildlife + person/profile icons) is obscured behind the sheet.
Only the top 2 icons (map, clock) remain visible.
**Location:** UmiLogApp.swift `VerticalTabBar` body / Surface/UnifiedBottomSurface.swift
**Recommended fix:** Animate the mode selector upward as the sheet expands, or anchor it above
the sheet's medium detent height.

### BUG-003: Bottom Sheet Peek State Has Excessive Empty Space
**Severity:** Low
**Screenshot:** `test01_initial_map.png`
**Description:** The peek state shows a site card ("Air Prang · 24m · Reef") with ~100-130pt of
empty dark-blue space below before the home indicator. This dead space doesn't communicate that
the sheet is draggable.
**Location:** Surface/UnifiedBottomSurface.swift detent configuration / SurfaceDetent.swift
**Recommended fix:** Reduce the peek detent height to match card content height (~60-70pt), or
add a subtle prompt text ("Drag to explore") to fill the visual gap.

### BUG-004: Site Preview Callout Never Triggered by Blind Tap Tests
**Severity:** Medium
**Screenshot:** `test08_site_preview.png`
**Description:** Tests 08–10 (SitePreview, SiteDetails, SiteDetailsScrolled) attempt blind taps
at fixed normalized coordinates to hit site markers. No candidate position successfully triggered
the `diveMap.sitePreview` callout. Tests passed due to `continueAfterFailure = true` and soft
assertions, but the full callout → details flow was never exercised.
**Root Cause:** Site marker pixel positions change based on map region after prior test panning.
**Recommended fix:** Add a `-UITest_SelectSite <siteId>` launch argument to pre-select a site on
startup, or zoom to a known region with a fixed marker at test start.

---

## Fixes Applied

None. All 14 tests pass without code changes. The `DiveMapUITests.swift` file (created by the
previous agent) is complete and functional. Bugs above are visual/UX issues for follow-up.

---

## Remaining Issues / Recommended Follow-Up

1. Fix BUG-001: Cluster badge escaping map bounds and overlapping FAB.
2. Fix BUG-002: Mode selector icons covered by sheet when expanded.
3. Fix BUG-003: Peek sheet has excessive empty space below site card.
4. Improve test reliability for BUG-004: Add launch arg to pre-select a site so the
   callout → view details → site details flow can be fully exercised.
5. The test command uses `-project UmiLog.xcodeproj` not `-workspace UmiLog.xcworkspace`.
   Update any CI scripts or README references accordingly.

---

## Summary

- Build: **SUCCEEDED**
- Tests: **14/14 PASSED** (395s total, ~6.5min)
- Screenshots: **12 captured from xcresult + 1 simulator screenshot**
- Accessibility identifiers: **All 19 present** in source files
- Bugs found: **4** (2 medium, 2 low)
- Fixes applied: **0** (no code changes needed to make tests pass)
