# UmiLog Coverage Plan

**Audit Date:** 2026-01-02

---

## Coverage Matrix

### Flow × State Dimension Matrix

| Flow | Fresh Install | With Data | Location Granted | Location Denied | Dark Mode | Reduce Motion |
|------|---------------|-----------|------------------|-----------------|-----------|---------------|
| F001 First Launch | **Required** | N/A | Optional | Optional | Required | Optional |
| F002 Explore Map | Required | Required | Optional | Required | Required | Optional |
| F003 Search Site | N/A | Required | Optional | Required | Required | Optional |
| F004 Quick Log | Required | Required | Required | Required | Required | Optional |
| F005 Live Log Wizard | Required | Required | Optional | Required | Required | Optional |
| F006 View History | Required | Required | N/A | N/A | Required | Optional |
| F007 Browse Wildlife | Required | Required | N/A | N/A | Required | Optional |
| F008 View Profile | Required | Required | N/A | N/A | Required | Optional |
| F009 Inspect Site | N/A | Required | Optional | Required | Required | Optional |
| F010 Filter Sites | N/A | Required | N/A | N/A | Required | Optional |
| F011 Proximity Prompt | N/A | Required | **Required** | N/A | Required | Optional |
| F012 Export Data | N/A | Required | N/A | N/A | N/A | N/A |
| F013 Create Site GPS | N/A | N/A | **Required** | N/A | N/A | N/A |

**Legend**: Required = must test, Optional = nice to have, N/A = not applicable

---

## Test Suite Organization

### Manual Test Suite (Smoke)

Priority order for manual testing:

```
SMOKE SUITE (15-20 min)
━━━━━━━━━━━━━━━━━━━━━━━━
1. Launch app → verify loading screen (not white)      [F001]
2. Wait for map → verify pins visible                  [F001]
3. Tap Log FAB → verify launcher sheet                 [F004]
4. Quick Log: select site, enter depth/time, save      [F004]
5. History tab → verify dive appears with NEW badge    [F006]
6. Tap dive → verify detail view                       [F006]
7. Wildlife tab → verify species grid                  [F007]
8. Tap species → verify detail                         [F007]
9. Profile tab → verify stats reflect 1 dive           [F008]
10. Profile menu → Settings → Export → verify share    [F012]

BLOCKED TESTS (require fix first)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A. Tap map pin → verify callout                        [F002/F009]
B. Tap search button → verify search opens             [F003]
C. Tap site card in list → verify inspect              [F002]
D. Filter button → verify filter sheet                 [F010]
```

### XCUITest Automation Candidates

```swift
// testFirstLaunchLoading
// Verify: Launch → Loading view visible (not white screen)
// Verify: < 5s to interactive

// testTabNavigation
// Verify: All 5 tab icons accessible
// Verify: Each tab shows correct title

// testQuickLogFlow
// Action: Tap Log FAB
// Action: Tap "Quick Log"
// Action: Tap site selector → select first site
// Action: Tap "18m" quick button
// Action: Tap "45min" quick button
// Action: Tap "Log Dive"
// Verify: History tab shows new dive

// testLiveLogWizard
// Action: Tap Log FAB → "Start Live Log"
// Action: Step 1: Select site, Continue
// Action: Step 2: Enter depth 20, time 45, Continue
// Action: Step 3: Continue
// Action: Step 4: Save
// Verify: Success banner, History shows dive

// testHistorySearch
// Precondition: At least one dive logged
// Action: History tab → type in search
// Verify: List filters

// testWildlifeNavigation
// Action: Wildlife tab
// Action: Tap first species
// Verify: Detail view title matches species name
// Action: Back
// Verify: Grid visible

// testExportData
// Action: Profile → Menu → Settings
// Action: Tap "Export Data"
// Verify: Share sheet appears

// testEmptyStates (Fresh install)
// Verify: History shows "No Dives Found" + CTA
// Verify: Profile stats show 0
```

### Device-Only Tests

```
GEOFENCING (Requires real device + location)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Grant location permission
2. Register geofence for test site
3. Physically move to location (or use GPX)
4. Verify proximity prompt appears
5. Tap "Start Dive" → verify wizard with site

GPS LOGGING (Requires real device + location)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Quick Log → "Use Current Location"
2. Save dive
3. Verify CreateSiteFromGPSView appears
4. Enter site name, save
5. Verify site on map
```

---

## State Setup Scripts

### Fresh Install State
```bash
# Reset simulator
xcrun simctl erase <DEVICE_ID>

# Install fresh app
xcodebuild -scheme UmiLog -destination 'id=<DEVICE_ID>' install
```

### With Data State
```swift
// In test setup or debug menu:
func seedTestData() {
    let diveRepo = DiveRepository(database: AppDatabase.shared)

    // Add 5 test dives
    for i in 1...5 {
        let dive = DiveLog(
            siteId: "site-\(i % 3)",  // Spread across sites
            date: Date().addingTimeInterval(TimeInterval(-86400 * i)),
            maxDepth: Double(18 + i * 2),
            bottomTime: 40 + i * 5
        )
        try? diveRepo.create(dive)
    }
}
```

### Location Permission States
```
// Not Determined: Fresh install
// When In Use: Grant via UI when prompted
// Denied: Settings > UmiLog > Location > Never
```

---

## Blockers List

### Critical (P0) - Blocks multiple flows

| Blocker | Affected Flows | Resolution |
|---------|----------------|------------|
| Map pins/cards don't respond to tap | F002, F003, F009, F010 | Debug gesture recognizers, add contentShape |
| White screen on first launch | F001 | Move seeding to background, show loading UI |

### High (P1) - Blocks single flow

| Blocker | Affected Flow | Resolution |
|---------|---------------|------------|
| Search button not responsive | F003 | Fix hit testing |
| Filter persistence not working | F010 | Wire MapStatePersistence |

### Medium (P2) - Degrades experience

| Blocker | Affected Flow | Resolution |
|---------|---------------|------------|
| Slow tab switch (underwater animation) | All tabs | Optimize transition |
| No location permission prompt on first GPS use | F004, F013 | Add explicit prompt |

### Low (P3) - Edge cases

| Blocker | Affected Flow | Resolution |
|---------|---------------|------------|
| "This area" scope unclear when map not visible | F007 | Add hint text |

---

## Recommended Test Priority

### Phase 1: Unblock Core Flows
1. Fix map tap gesture issues (P0)
2. Fix first launch loading (P0)
3. Run Smoke Suite

### Phase 2: Automate Happy Paths
1. Write XCUITests for F004, F005, F006, F007
2. CI integration

### Phase 3: Edge Cases
1. Empty state testing
2. Permission denial flows
3. Offline mode

### Phase 4: Device Testing
1. Geofencing (F011)
2. GPS logging (F013)
3. Performance profiling

---

## Estimated Coverage

| Category | Current | Target |
|----------|---------|--------|
| Manual Smoke | 60% | 100% |
| XCUITest | 0% | 50% |
| Unit Tests | Unknown | 30% |
| Device Tests | 0% | 20% |

**Total estimated coverage after blockers fixed: 70%**
