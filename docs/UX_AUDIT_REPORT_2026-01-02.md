# UmiLog iOS UX Audit Report

**Date:** 2026-01-02
**Auditor:** Claude Code (Automated)
**Commit:** 54c299b (main branch)
**Environment:** Xcode (latest), iOS 18.6, iPhone 16 Pro Simulator
**Device ID:** 87E39D00-0CEF-4EC8-8B31-386E8363F3C9

---

## Executive Summary

UmiLog has significant UX blocking issues that prevent core user journeys from completing. While the map rendering and basic navigation framework work, **critical interactive elements are non-functional**, making the app largely unusable for its primary purpose.

**Overall Status: FAIL**

---

## Journey Scoreboard

| Journey | Status | Summary |
|---------|--------|---------|
| 1. First Dive Log | **FAIL** | Cannot complete - Quick Log button accessible but site selection requires working search/pins |
| 2. Explore & Plan | **FAIL** | Cannot tap pins or cards to view site details or add to wishlist |
| 3. Search & Discover | **FAIL** | Search button completely non-responsive |
| 4. Log at Location | **PARTIAL** | Log launcher modal works, but cannot select a site |

---

## Critical Findings (P0)

### 1. White Screen on Launch (SwiftUI State Bug)
**Severity:** P0
**Location:** App-wide, likely in `UmiLogApp.swift` or `NewMapView.swift`
**Repro:** Launch app from cold start
**Expected:** Splash screen → Map view in <3 seconds
**Actual:** Blank white screen for 15-30 seconds with console errors:
```
[SwiftUI] Modifying state during view update, this will cause undefined behavior.
```
**Impact:** Users may think app is crashed/broken and abandon it

### 2. Site Cards Don't Respond to Taps
**Severity:** P0
**Location:** `HorizontalSiteCarousel.swift:20` - `onTapGesture { onSiteTap(site) }`
**Repro:** Tap any site card in the bottom sheet carousel
**Expected:** Bottom sheet expands to show site inspection view, map focuses on site
**Actual:** No response, no haptic feedback, no visual change
**Root Cause Hypothesis:** Gesture conflict with surface drag gestures, or callback not properly wired

### 3. Search Button Non-Responsive
**Severity:** P0
**Location:** `NewMapView.swift:1550-1554` - `MinimalSearchButton`
**Repro:** Tap the magnifying glass icon in top-right corner
**Expected:** Search interface opens in expanded bottom sheet
**Actual:** No response
**Root Cause Hypothesis:** Button may be overlaid by invisible hit-test-blocking view, or action not firing

### 4. Map Pins Don't Show Callouts
**Severity:** P0
**Location:** `NewMapView.swift:1382` (NativeMapView) or `:1447` (DiveMap)
**Repro:** Tap an individual site pin on the map
**Expected:** SiteCalloutCard appears with View Details/Log Dive/Dismiss buttons
**Actual:** No callout appears, pin remains static
**Root Cause Hypothesis:** `didSelect` delegate may not be firing, or `calloutSite` state not being set

### 5. Inter-App Navigation Bug (Handoff Issue)
**Severity:** P0
**Location:** Unknown - likely URL scheme or NSUserActivity configuration
**Repro:** Tap near screen edges or certain UI elements
**Expected:** Action within UmiLog
**Actual:** App switches to NutriTrack or Manabi apps
**Root Cause Hypothesis:** Conflicting Handoff/Universal Links configuration between the three apps

---

## Significant Findings (P1)

### 6. Tab Bar Becomes Unresponsive
**Severity:** P1
**Repro:** After multiple interactions, tab buttons stop responding
**Impact:** Users cannot navigate between app sections

### 7. Slow Initial Database Seeding
**Severity:** P1
**Location:** `DatabaseSeeder.swift`
**Details:** 15,375 sites from 10MB JSON file causes 3+ minute initial load on cold install
**Recommendation:** Implement progressive loading or pre-built SQLite database

---

## Working Features

| Feature | Status | Notes |
|---------|--------|-------|
| Map rendering (MapLibre) | **PASS** | Clusters and pins display correctly |
| Cluster tap to zoom | **PASS** | Tapping clusters zooms in properly |
| Tab bar navigation | **PARTIAL** | Works initially but becomes unresponsive |
| History empty state | **PASS** | Shows correct "No Dives Found" message |
| Log launcher modal | **PASS** | Quick Log/Live Log options appear |
| Bottom sheet peek/drag | **PARTIAL** | Visual display works, interaction broken |

---

## Benchmarking Notes

**Compared against:** Apple Maps, Google Maps, AllTrails, Dive+

**Gap Analysis:**
- Best-in-class apps show map pin details on single tap (UmiLog: broken)
- Best-in-class apps have <2s cold start time (UmiLog: 15-30s white screen)
- Best-in-class apps have reliable search accessibility (UmiLog: non-functional)
- Best-in-class apps use haptic feedback on all interactions (UmiLog: missing on most)

---

## Recommendations

### Immediate (Before Any Release)

1. **Fix SwiftUI state modification errors**
   - Audit all `@State` and `@Binding` modifications
   - Ensure state changes happen outside view update cycle (use `DispatchQueue.main.async` if needed)
   - Add `onAppear` guards to prevent redundant state changes

2. **Fix site card tap handling**
   - Check if `ScrollView` is intercepting gestures
   - Add `.contentShape(Rectangle())` to ensure hit testing
   - Verify `onSiteTap` callback chain is connected

3. **Fix search button**
   - Verify button is not covered by another view (use View Hierarchy Debugger)
   - Check `allowsHitTesting` on overlaying views
   - Add debug logging to verify action fires

4. **Fix map pin selection**
   - Add debug logging to `mapView(_:didSelect:)` delegate
   - Verify `calloutSite` state is being set
   - Check if `showCallout` condition is evaluating true

5. **Investigate inter-app navigation**
   - Review `NSUserActivity` and `SceneDelegate` handoff code
   - Check URL scheme registrations in Info.plist
   - Ensure no conflicting universal links with NutriTrack/Manabi

### Short-term

6. **Optimize initial load time**
   - Ship pre-built SQLite database in app bundle
   - Implement lazy loading for site data
   - Show progress indicator during seeding

7. **Add haptic feedback consistently**
   - All tappable elements should have `.soft` haptic on tap
   - Navigation actions should have `.light` haptic
   - Success actions (save dive) should have `.success` haptic

### Medium-term

8. **Implement proper error states**
   - Handle and display errors gracefully
   - Add retry mechanisms for failed operations

9. **Add accessibility testing**
   - VoiceOver full navigation test
   - Dynamic Type support verification

---

## Test Coverage Gaps

Due to blocking issues, the following were not testable:

- [ ] Quick Log flow completion
- [ ] Live Log flow
- [ ] Site inspection view
- [ ] Search results and filtering
- [ ] Wildlife tab functionality
- [ ] Profile tab functionality
- [ ] Wishlist feature
- [ ] Dive detail view

---

## Appendix: Console Errors

```
[SwiftUI] Modifying state during view update, this will cause undefined behavior.
(repeated 50+ times on launch)

[libsqlite3] automatic index on sc(site_id)
```

---

## Next Steps

1. Developer to investigate and fix P0 issues
2. Re-run audit after fixes
3. Proceed with full journey testing once core interactions work
