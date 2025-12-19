# UmiLog Map-First UI Redesign

## Progress Tracker

| Field | Value |
|-------|-------|
| **Status** | In Progress |
| **Current Step** | Step 13: Remove Old UI Elements |
| **Last Updated** | Session 5 |
| **Total Steps** | 15 (78 sub-tasks) |
| **Completed** | Steps 1-12 (Phase A+B+C complete, ready for cleanup) |

---

## Table of Contents

1. [Design Rationale](#design-rationale)
2. [Architecture Overview](#architecture-overview)
3. [File Inventory](#file-inventory)
4. [State Machine Specification](#state-machine-specification)
5. [Implementation Steps](#implementation-steps)
6. [Validation & Testing](#validation--testing)
7. [Rollback Plan](#rollback-plan)

---

## Design Rationale

### Problem Statement

The current UmiLog map view has **fragmented state** spread across multiple sources:
- `MapViewModel` with 10+ `@Published` properties
- `NewMapView` with 15+ `@State` variables
- Multiple competing UI surfaces (rail, chips, preview card, modals)

This causes:
- Impossible to reason about valid state combinations
- No formal mode transitions—any state change is allowed
- UI elements compete for attention
- Complex `onChange` handlers to sync state

### Solution

Implement the **map-first redesign spec** with:
1. **Unified state machine** - Single source of truth for UI mode
2. **Single bottom surface** - One morphing component replaces all overlays
3. **Explicit transitions** - Reducer pattern enforces valid state changes
4. **Filter lens pattern** - "My Sites" becomes a filter, not a mode

### Key Decisions

| Decision | Rationale |
|----------|-----------|
| Merge My Map + Explore | Reduces cognitive load; "My Sites" as filter is more flexible |
| Keep hierarchy navigation | User requested; provides structure for large datasets |
| Search via corner icon | Removes always-visible search bar per spec |
| Immediate dismiss on viewport exit | Per spec: selected site does not persist when offscreen |
| Parallel operation during migration | Allows gradual rollout, easy rollback |

---

## Architecture Overview

### State Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        MapUIViewModel                            │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  @Published mode: MapUIMode                              │    │
│  │    .explore(ExploreContext)                              │    │
│  │    .inspectSite(SiteInspectionContext)                   │    │
│  │    .filter(FilterContext)                                │    │
│  │    .search(SearchContext)                                │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                    send(MapUIAction)                             │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  MapUIReducer.reduce(state, action) → newState          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  handleSideEffects(action)                               │    │
│  │  - Camera updates                                        │    │
│  │  - Persistence                                           │    │
│  │  - Notifications                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     UnifiedBottomSurface                         │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐  │
│  │ ExploreContent│InspectContent│FilterContent │SearchContent │  │
│  └──────────────┴──────────────┴──────────────┴──────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Mode Transition Diagram

```
                              ┌─────────────┐
                              │   EXPLORE   │ ◄─── App Launch
                              │  (default)  │
                              └──────┬──────┘
                                     │
            ┌────────────────────────┼────────────────────────┐
            │                        │                        │
            ▼                        ▼                        ▼
     ┌─────────────┐          ┌─────────────┐          ┌─────────────┐
     │   INSPECT   │          │   FILTER    │          │   SEARCH    │
     │  (site tap) │          │(filter tap) │          │(search tap) │
     └──────┬──────┘          └──────┬──────┘          └──────┬──────┘
            │                        │                        │
            │ dismiss/               │ apply/                 │ select/
            │ viewport exit          │ cancel                 │ dismiss
            │                        │                        │
            └────────────────────────┴────────────────────────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │   EXPLORE   │
                              │(returnCtx)  │
                              └─────────────┘

Note: Proximity Prompt is an OVERLAY, not a mode transition.
It appears above current mode and dismisses without affecting mode.
```

### Bottom Surface Height by Mode

```
Mode: EXPLORE
┌────────────────────────────────┐
│ Peek (24% / 160pt min)         │  "Sites nearby: 42" + filter icon
├────────────────────────────────┤
│ Medium (60%)                   │  + Breadcrumbs + Site list
├────────────────────────────────┤
│ Expanded (100% - 44pt)         │  + Full discovery content
└────────────────────────────────┘

Mode: INSPECT
┌────────────────────────────────┐
│ Medium (60%)                   │  Site card + Save/Plan/Log actions
├────────────────────────────────┤
│ Expanded (100% - 44pt)         │  + Hero image + Full details
└────────────────────────────────┘

Mode: FILTER / SEARCH
┌────────────────────────────────┐
│ Expanded only (100% - 44pt)    │  Full filter controls / Search UI
└────────────────────────────────┘
```

---

## File Inventory

### Files to Create (New)

| File Path | Purpose | Step |
|-----------|---------|------|
| `Modules/FeatureMap/Sources/State/HierarchyLevel.swift` | Hierarchy enum (world/region/area) | 1.1 |
| `Modules/FeatureMap/Sources/State/FilterLens.swift` | My Sites lens enum | 1.2 |
| `Modules/FeatureMap/Sources/State/ExploreFilters.swift` | Filter criteria struct | 1.3 |
| `Modules/FeatureMap/Sources/State/MapUIMode.swift` | Mode enum + contexts | 1.4 |
| `Modules/FeatureMap/Sources/State/ProximityPromptState.swift` | Prompt overlay state | 1.5 |
| `Modules/FeatureMap/Sources/State/MapUIAction.swift` | Action enum | 2.1 |
| `Modules/FeatureMap/Sources/State/MapUIReducer.swift` | State reducer | 2.2 |
| `Modules/FeatureMap/Sources/State/MapUIViewModel.swift` | Unified view model | 3.1 |
| `Modules/FeatureMap/Sources/State/MapStatePersistence.swift` | UserDefaults persistence | 3.2 |
| `Modules/FeatureMap/Sources/Surface/SurfaceDetent.swift` | Detent enum + heights | 4.1 |
| `Modules/FeatureMap/Sources/Surface/SurfaceGestures.swift` | Drag gesture logic | 4.2 |
| `Modules/FeatureMap/Sources/Surface/UnifiedBottomSurface.swift` | Main surface container | 5.1 |
| `Modules/FeatureMap/Sources/Surface/Content/ExploreContent.swift` | Explore mode content | 6.1 |
| `Modules/FeatureMap/Sources/Surface/Content/InspectContent.swift` | Inspect mode content | 7.1 |
| `Modules/FeatureMap/Sources/Surface/Content/FilterContent.swift` | Filter mode content | 8.1 |
| `Modules/FeatureMap/Sources/Surface/Content/SearchContent.swift` | Search mode content | 9.1 |
| `Modules/FeatureMap/Sources/Surface/Components/BreadcrumbRow.swift` | Hierarchy breadcrumb | 6.3 |
| `Modules/FeatureMap/Sources/Surface/Components/ActionButton.swift` | Action button style | 7.2 |
| `Modules/FeatureMap/Sources/HUD/MinimalSearchButton.swift` | Search icon button | 11.1 |
| `Modules/FeatureMap/Sources/HUD/ContextLabel.swift` | Status context label | 11.2 |
| `Modules/FeatureMap/Sources/HUD/ProximityPromptCard.swift` | Proximity prompt overlay | 12.1 |
| `Modules/FeatureMap/Tests/MapUIReducerTests.swift` | Reducer unit tests | 2.3 |

### Files to Modify

| File Path | Changes | Step |
|-----------|---------|------|
| `Modules/FeatureMap/Sources/NewMapView.swift` | Add new VM, replace sheet, remove old UI | 10, 13 |
| `Modules/FeatureMap/Sources/MapViewModel.swift` | Remove UI state, keep data | 14 |
| `UmiLog/UmiLogApp.swift` | Simplify tab bar visibility | 15.3 |

### Files to Deprecate/Delete

| File Path | Reason | Step |
|-----------|--------|------|
| `Modules/FeatureMap/Sources/SitePreviewCard.swift` | Merged into InspectContent | 13.4 |
| `Modules/FeatureMap/Sources/SiteDetailSheet.swift` | Merged into InspectContent | 7.1 |

### Files Referenced (Read-Only)

| File Path | Used For |
|-----------|----------|
| `Modules/DiveMap/Sources/MapVC.swift` | MapLibre integration patterns |
| `Modules/DiveMap/Sources/MapTheme.swift` | Color/styling constants |
| `Modules/UmiLocationKit/Sources/GeofenceManager.swift` | Proximity detection API |
| `Modules/UmiDB/Sources/Models/DiveSite.swift` | Site model definition |
| `Modules/UmiDB/Sources/Models/SiteFilters.swift` | Existing filter patterns |
| `Modules/UmiDesignSystem/Sources/Colors.swift` | Color tokens |
| `Modules/FeatureLiveLog/Sources/LiveLogWizardView.swift` | Log wizard presentation |

---

## State Machine Specification

### MapUIMode Cases

| Mode | Context | Allowed Detents | Entry Actions | Exit Actions |
|------|---------|-----------------|---------------|--------------|
| `explore` | `ExploreContext` | peek, medium, expanded | App launch, dismiss from other modes | N/A |
| `inspectSite` | `SiteInspectionContext` | medium, expanded | Site tap, search selection | Swipe down, tap map, viewport exit |
| `filter` | `FilterContext` | expanded only | Filter button tap | Apply, Cancel |
| `search` | `SearchContext` | expanded only | Search icon tap | Selection, dismiss |

### ExploreContext Properties

| Property | Type | Persisted? | Purpose |
|----------|------|------------|---------|
| `hierarchyLevel` | `HierarchyLevel` | No | Current drill-down (world/region/area) |
| `filterLens` | `FilterLens?` | Yes | My Sites filter (saved/logged/planned) |
| `previewingSite` | `String?` | No | Quick preview site ID (within Explore) |

### Action → Transition Table

| Current Mode | Action | Result Mode | Side Effects |
|--------------|--------|-------------|--------------|
| explore | `drillDownToRegion(id)` | explore (updated hierarchy) | Camera focus on region |
| explore | `drillDownToArea(id)` | explore (updated hierarchy) | Camera focus on area |
| explore | `navigateUp` | explore (parent hierarchy) | Camera adjust |
| explore | `applyFilterLens(lens)` | explore (with lens) | Persist lens |
| explore | `clearFilterLens` | explore (no lens) | Clear persisted lens |
| explore | `showPreview(siteId)` | explore (with preview) | None |
| explore | `openSiteInspection(siteId)` | inspectSite | Camera focus on site |
| explore | `openFilter` | filter | Capture returnContext |
| explore | `openSearch` | search | Capture returnContext |
| inspectSite | `closeSiteInspection` | explore (returnContext) | None |
| filter | `closeFilter(apply: true)` | explore (returnContext) | Apply filters, persist |
| filter | `closeFilter(apply: false)` | explore (returnContext) | Discard changes |
| search | `closeSearch(selectedSite)` | inspectSite or explore | Focus if selected |

### Persistence Rules

| State | Persist? | Storage | Restore On |
|-------|----------|---------|------------|
| `exploreFilters` | Yes | UserDefaults (Codable) | App launch |
| `filterLens` | Yes | UserDefaults (Codable) | App launch |
| Camera position | Yes | UserDefaults (lat/lon/zoom) | App launch |
| `hierarchyLevel` | No | — | Reset to `.world` |
| Current mode | No | — | Reset to `.explore` |
| Selected site | No | — | Cleared |
| Proximity prompt | No | — | Re-triggered by geofence |

---

## Implementation Steps

### Phase A: State Infrastructure (Steps 1-3)

**Goal:** Create all state types and the reducer without touching existing views.

---

### Step 1: State Machine Types

**Dependencies:** None
**Deliverables:** 5 new files with type definitions

#### Step 1.1: Create HierarchyLevel enum

**File:** `Modules/FeatureMap/Sources/State/HierarchyLevel.swift`

- [ ] Create `State/` directory in `FeatureMap/Sources/`
- [ ] Define `HierarchyLevel` enum with cases: `.world`, `.region(String)`, `.area(regionId:areaId:)`
- [ ] Implement `parent` computed property for back navigation
- [ ] Implement `breadcrumbPath` computed property returning `[String]`
- [ ] Add `Equatable`, `Hashable` conformance
- [ ] Verify compiles

**Current code reference:** `MapViewModel.swift` lines 82-84 (`tier`, `selectedRegion`, `selectedArea`)

#### Step 1.2: Create FilterLens enum

**File:** `Modules/FeatureMap/Sources/State/FilterLens.swift`

- [ ] Define `FilterLens` enum with cases: `.saved`, `.logged`, `.planned`
- [ ] Add `Codable` conformance for persistence
- [ ] Implement `displayName: String` computed property
- [ ] Implement `iconName: String` computed property (SF Symbol names)
- [ ] Add `CaseIterable` for UI iteration
- [ ] Verify compiles

**Current code reference:** `MapViewModel.swift` lines 72-75 (`statusFilter: StatusFilter`)

#### Step 1.3: Create ExploreFilters struct

**File:** `Modules/FeatureMap/Sources/State/ExploreFilters.swift`

- [ ] Import `UmiDB` for `DiveSite.Difficulty` and `DiveSite.SiteType`
- [ ] Define struct with properties:
  - `difficulty: Set<DiveSite.Difficulty>`
  - `siteType: Set<DiveSite.SiteType>`
  - `showShops: Bool`
  - `maxDepthRange: ClosedRange<Double>?`
- [ ] Add `static let default` with empty/false values
- [ ] Implement `isActive: Bool` computed property
- [ ] Implement `activeCount: Int` computed property
- [ ] Add `Codable`, `Equatable`, `Hashable` conformance
- [ ] Verify compiles

**Current code reference:** `MapViewModel.swift` lines 77-80 (`exploreFilter: ExploreFilter`)

#### Step 1.4: Create MapUIMode enum and contexts

**File:** `Modules/FeatureMap/Sources/State/MapUIMode.swift`

- [ ] Define `MapUIMode` enum with cases:
  - `.explore(ExploreContext)`
  - `.inspectSite(SiteInspectionContext)`
  - `.filter(FilterContext)`
  - `.search(SearchContext)`
- [ ] Define `ExploreContext` struct:
  - `hierarchyLevel: HierarchyLevel = .world`
  - `filterLens: FilterLens?`
  - `previewingSite: String?`
- [ ] Define `SiteInspectionContext` struct:
  - `siteId: String`
  - `returnContext: ExploreContext`
- [ ] Define `FilterContext` struct:
  - `exploreFilters: ExploreFilters`
  - `returnContext: ExploreContext`
- [ ] Define `SearchContext` struct:
  - `query: String = ""`
  - `returnContext: ExploreContext`
- [ ] Add `Equatable` conformance to all types
- [ ] Verify compiles

**Current code reference:** `NewMapView.swift` lines 44-50 (`selectedSite`, `previewSite`, `showingSiteDetail`, `showSearch`, `showFilterLayers`)

#### Step 1.5: Create ProximityPromptState

**File:** `Modules/FeatureMap/Sources/State/ProximityPromptState.swift`

- [ ] Import `UmiDB` for `DiveSite`
- [ ] Define struct with properties:
  - `site: DiveSite`
  - `enteredAt: Date`
  - `isDismissed: Bool = false`
- [ ] Add `Equatable` conformance
- [ ] Verify compiles

**Current code reference:** `GeofenceManager.swift` `.arrivedAtDiveSite` notification

**✓ Checkpoint 1:** All 5 files compile. Run `xcodebuild` to verify.

---

### Step 2: State Machine Actions & Reducer

**Dependencies:** Step 1 complete
**Deliverables:** 2 new files + 1 test file

#### Step 2.1: Create MapUIAction enum

**File:** `Modules/FeatureMap/Sources/State/MapUIAction.swift`

- [ ] Import `UmiDB` for `DiveSite`
- [ ] Define enum with cases organized by category:

**Hierarchy navigation:**
- [ ] `drillDownToRegion(String)`
- [ ] `drillDownToArea(String)`
- [ ] `navigateUp`
- [ ] `resetToWorld`

**Filter lens:**
- [ ] `applyFilterLens(FilterLens)`
- [ ] `clearFilterLens`

**Preview (within Explore):**
- [ ] `showPreview(String)` — siteId
- [ ] `dismissPreview`
- [ ] `promotePreviewToInspect`

**Mode transitions:**
- [ ] `openSiteInspection(String)` — siteId
- [ ] `closeSiteInspection`
- [ ] `openFilter`
- [ ] `closeFilter(apply: Bool)`
- [ ] `openSearch`
- [ ] `closeSearch(selectedSite: String?)`

**Proximity prompt:**
- [ ] `showProximityPrompt(DiveSite)`
- [ ] `dismissProximityPrompt`
- [ ] `acceptProximityPrompt`

- [ ] Verify compiles

#### Step 2.2: Create MapUIReducer

**File:** `Modules/FeatureMap/Sources/State/MapUIReducer.swift`

- [ ] Define `MapUIReducer` struct with static `reduce` function
- [ ] Function signature: `reduce(state: MapUIMode, action: MapUIAction, currentFilters: ExploreFilters) -> MapUIMode`
- [ ] Implement switch on `(state, action)` tuple

**Implement transitions:**

- [ ] `(.explore(var ctx), .drillDownToRegion(let id))` → update hierarchyLevel, clear preview
- [ ] `(.explore(var ctx), .drillDownToArea(let id))` → must be in region, update hierarchyLevel
- [ ] `(.explore(var ctx), .navigateUp)` → move to parent hierarchyLevel
- [ ] `(.explore(var ctx), .resetToWorld)` → set hierarchyLevel to .world
- [ ] `(.explore(var ctx), .applyFilterLens(let lens))` → set filterLens
- [ ] `(.explore(var ctx), .clearFilterLens)` → clear filterLens
- [ ] `(.explore(var ctx), .showPreview(let id))` → set previewingSite
- [ ] `(.explore(var ctx), .dismissPreview)` → clear previewingSite
- [ ] `(.explore(var ctx), .promotePreviewToInspect)` → transition to inspectSite if preview exists
- [ ] `(.explore(let ctx), .openSiteInspection(let id))` → transition to inspectSite with returnContext
- [ ] `(.inspectSite(let ctx), .closeSiteInspection)` → return to explore with returnContext
- [ ] `(.explore(let ctx), .openFilter)` → transition to filter with returnContext
- [ ] `(.filter(let ctx), .closeFilter)` → return to explore with returnContext
- [ ] `(.explore(let ctx), .openSearch)` → transition to search with returnContext
- [ ] `(.search(let ctx), .closeSearch(let selected))` → if selected, go to inspect; else explore

- [ ] Default case returns current state unchanged (invalid transitions)
- [ ] Verify compiles

#### Step 2.3: Write reducer unit tests

**File:** `Modules/FeatureMap/Tests/MapUIReducerTests.swift`

- [ ] Create test class `MapUIReducerTests`
- [ ] Import XCTest and module

**Test cases:**

- [ ] `testDrillDownToRegion` — explore.world → explore.region
- [ ] `testDrillDownToArea` — explore.region → explore.area
- [ ] `testDrillDownToAreaFromWorld_NoOp` — invalid: explore.world + drillDownToArea = no change
- [ ] `testNavigateUp_FromArea` — explore.area → explore.region
- [ ] `testNavigateUp_FromRegion` — explore.region → explore.world
- [ ] `testNavigateUp_FromWorld_NoOp` — explore.world → explore.world
- [ ] `testApplyFilterLens` — sets lens
- [ ] `testClearFilterLens` — clears lens
- [ ] `testOpenSiteInspection` — explore → inspectSite with correct returnContext
- [ ] `testCloseSiteInspection` — inspectSite → explore (returnContext restored)
- [ ] `testOpenFilter` — explore → filter with returnContext
- [ ] `testCloseFilterApply` — filter → explore (returnContext restored)
- [ ] `testCloseFilterCancel` — filter → explore (filters unchanged)
- [ ] `testOpenSearch` — explore → search
- [ ] `testCloseSearchWithSelection` — search → inspectSite
- [ ] `testCloseSearchWithoutSelection` — search → explore
- [ ] `testInvalidTransition_InspectToFilter` — inspectSite + openFilter = no change

- [ ] Run tests: `xcodebuild test -scheme FeatureMap`

**✓ Checkpoint 2:** All reducer tests pass.

---

### Step 3: Unified ViewModel

**Dependencies:** Steps 1-2 complete
**Deliverables:** 2 new files

#### Step 3.1: Create MapUIViewModel shell

**File:** `Modules/FeatureMap/Sources/State/MapUIViewModel.swift`

- [ ] Add `@MainActor` attribute
- [ ] Define `MapUIViewModel: ObservableObject`
- [ ] Add published properties:
  - `@Published private(set) var mode: MapUIMode = .explore(ExploreContext())`
  - `@Published var exploreFilters: ExploreFilters = .default`
  - `@Published var proximityPrompt: ProximityPromptState?`
- [ ] Add `send(_ action: MapUIAction)` function
- [ ] Implement `send` to call reducer and update mode
- [ ] Add `private func handleSideEffects(for action: MapUIAction)` stub
- [ ] Verify compiles

#### Step 3.2: Add persistence layer

**File:** `Modules/FeatureMap/Sources/State/MapStatePersistence.swift`

- [ ] Define `MapStatePersistence` class
- [ ] Add `static let shared` singleton
- [ ] Define UserDefaults keys as constants:
  - `map.exploreFilters`
  - `map.filterLens`
  - `map.camera.lat`, `map.camera.lon`, `map.camera.zoom`
- [ ] Implement `saveExploreFilters(_ filters: ExploreFilters)`
- [ ] Implement `loadExploreFilters() -> ExploreFilters`
- [ ] Implement `saveFilterLens(_ lens: FilterLens)`
- [ ] Implement `loadFilterLens() -> FilterLens?`
- [ ] Implement `clearFilterLens()`
- [ ] Implement `saveCamera(lat: Double, lon: Double, zoom: Double)`
- [ ] Implement `loadCamera() -> (lat: Double, lon: Double, zoom: Double)?`
- [ ] Wire persistence into MapUIViewModel:
  - Load on init
  - Save in `exploreFilters` didSet
  - Save lens in side effects

#### Step 3.3: Add computed properties to MapUIViewModel

- [ ] Add `exploreContext: ExploreContext?` — extracts context if in explore mode
- [ ] Add `isShowingMySites: Bool` — true if filterLens is set
- [ ] Add `currentHierarchyLevel: HierarchyLevel` — returns hierarchy or .world
- [ ] Add `inspectedSiteId: String?` — extracts siteId if in inspect mode

#### Step 3.4: Add geofence notification binding

- [ ] Import Combine
- [ ] Add `private var cancellables = Set<AnyCancellable>()`
- [ ] In init, subscribe to `.arrivedAtDiveSite` notification
- [ ] Extract site from notification userInfo
- [ ] Call `send(.showProximityPrompt(site))`
- [ ] Implement `handleSideEffects` for proximity actions:
  - `.showProximityPrompt` → set proximityPrompt
  - `.dismissProximityPrompt` → set proximityPrompt.isDismissed
  - `.acceptProximityPrompt` → post `.startLiveLogRequested`, clear prompt

**✓ Checkpoint 3:** MapUIViewModel compiles and loads persisted state on init.

---

### Phase B: Surface Components (Steps 4-9)

**Goal:** Build the unified bottom surface and all content views.

---

### Step 4: Surface Detent System

**Dependencies:** Step 1 complete (needs MapUIMode)
**Deliverables:** 2 new files

#### Step 4.1: Create SurfaceDetent enum

**File:** `Modules/FeatureMap/Sources/Surface/SurfaceDetent.swift`

- [ ] Create `Surface/` directory in `FeatureMap/Sources/`
- [ ] Define `SurfaceDetent` enum with cases: `.peek`, `.medium`, `.expanded`
- [ ] Implement `height(in containerHeight: CGFloat) -> CGFloat`:
  - peek: `max(containerHeight * 0.24, 160)`
  - medium: `containerHeight * 0.60`
  - expanded: `containerHeight - 44`
- [ ] Implement `static func allowed(for mode: MapUIMode) -> [SurfaceDetent]`:
  - explore: `[.peek, .medium, .expanded]`
  - inspectSite: `[.medium, .expanded]`
  - filter, search: `[.expanded]`
- [ ] Add `Equatable`, `CaseIterable` conformance
- [ ] Verify compiles

#### Step 4.2: Create SurfaceGestures extension

**File:** `Modules/FeatureMap/Sources/Surface/SurfaceGestures.swift`

- [ ] Import SwiftUI
- [ ] Define extension on a protocol or create helper struct
- [ ] Implement `makeDragGesture(containerHeight:currentDetent:mode:onDetentChange:) -> some Gesture`
- [ ] Implement `finalizeDrag(translation:velocity:containerHeight:currentDetent:allowedDetents:) -> SurfaceDetent`:
  - Calculate projected height
  - Find nearest allowed detent
  - Apply velocity bias
- [ ] Implement `computeRubberBandOffset(translation:baseHeight:minHeight:maxHeight:) -> CGFloat`:
  - Apply rubber-band effect at boundaries
- [ ] Verify compiles

**Current code reference:** `NewMapView.swift` lines 655-688 (`sheetDragGesture`)

**✓ Checkpoint 4:** Detent system ready.

---

### Step 5: Unified Bottom Surface Container

**Dependencies:** Steps 1, 3, 4 complete
**Deliverables:** 1 new file

#### Step 5.1: Create UnifiedBottomSurface shell

**File:** `Modules/FeatureMap/Sources/Surface/UnifiedBottomSurface.swift`

- [ ] Define `UnifiedBottomSurface: View`
- [ ] Add bindings:
  - `@Binding var mode: MapUIMode`
  - `@Binding var detent: SurfaceDetent`
- [ ] Add `@GestureState private var dragTranslation: CGFloat = 0`
- [ ] Add callbacks:
  - `onSiteTap: (DiveSite) -> Void`
  - `onDismissInspect: () -> Void`
  - `onApplyFilters: () -> Void`
  - `onCancelFilters: () -> Void`
  - `onSearchSelect: (DiveSite) -> Void`
  - `onOpenFilter: () -> Void`
  - `onOpenSearch: () -> Void`
- [ ] Add `@ObservedObject var dataViewModel: MapViewModel` for site data
- [ ] Implement body with GeometryReader
- [ ] Add `surfaceContent` ViewBuilder with VStack(dragHandle + modeContent)
- [ ] Add `modeContent` ViewBuilder switching on mode (placeholder Text for now)
- [ ] Add `.frame(height:)` using computed target height
- [ ] Add `.gesture()` using drag gesture
- [ ] Add `.animation(.spring())` for mode/detent changes

#### Step 5.2: Add drag handle and background styling

- [ ] Create `dragHandle` view:
  - ZStack with centered Capsule
  - Capsule: 36pt width, 4pt height, Color.kelp.opacity(0.35)
  - Container: 44pt height, full width
  - `.contentShape(Rectangle())` for hit testing
- [ ] Create `surfaceBackground` view:
  - RoundedRectangle cornerRadius 24
  - Fill: Color.glass
  - Overlay: Material.thin
  - Overlay: stroke Color.oceanBlue.opacity(0.2), lineWidth 1
  - Shadow: color .black.opacity(0.18), radius 10, y -4
- [ ] Apply background to surfaceContent
- [ ] Verify preview renders

**✓ Checkpoint 5:** Empty surface shell renders and drags between detents.

---

### Step 6: Explore Content

**Dependencies:** Step 5 complete
**Deliverables:** 2 new files

#### Step 6.1: Create ExploreContent view

**File:** `Modules/FeatureMap/Sources/Surface/Content/ExploreContent.swift`

- [ ] Create `Content/` directory in `Surface/`
- [ ] Define `ExploreContent: View`
- [ ] Add properties:
  - `let context: ExploreContext`
  - `let detent: SurfaceDetent`
  - `@ObservedObject var dataViewModel: MapViewModel`
  - `var onSiteTap: (DiveSite) -> Void`
  - `var onOpenFilter: () -> Void`
- [ ] Implement body with VStack:
  - `peekHeader` (always visible)
  - If detent != .peek: `breadcrumbRow` + `siteList`
- [ ] Implement `peekHeader`:
  - HStack with count label + Spacer + filter button
  - If context.filterLens != nil: show lens chip
- [ ] Implement `countLabel: String` computed property:
  - Format: "Sites nearby: N" or "Saved: N" based on lens
- [ ] Implement `filterEntryButton`:
  - Button with slider.horizontal.3 icon
  - Badge showing active filter count
  - onTap calls onOpenFilter
- [ ] Add padding and styling

#### Step 6.2: Port site list from existing sheet

- [ ] Implement `siteList` ViewBuilder
- [ ] Add ScrollView with LazyVStack
- [ ] Filter sites using `context.hierarchyLevel`
- [ ] Filter sites using `context.filterLens`
- [ ] For each site, create row with:
  - Site name
  - Difficulty indicator
  - Quick stats (depth, temp)
  - onTap calls onSiteTap
- [ ] Add empty state when no sites match

**Current code reference:** `NewMapView.swift` lines 1376-1500 (bottomSheetContent site lists)

#### Step 6.3: Create breadcrumb component

**File:** `Modules/FeatureMap/Sources/Surface/Components/BreadcrumbRow.swift`

- [ ] Create `Components/` directory in `Surface/`
- [ ] Define `BreadcrumbRow: View`
- [ ] Add properties:
  - `let hierarchyLevel: HierarchyLevel`
  - `var onNavigateUp: () -> Void`
  - `var onResetToWorld: () -> Void`
- [ ] Implement body:
  - HStack with back button + path segments
  - Tappable segments to navigate
- [ ] Style with kelp/mist colors

**✓ Checkpoint 6:** Explore content renders at all detents with real data.

---

### Step 7: Inspect Content

**Dependencies:** Step 5 complete
**Deliverables:** 2 new files

#### Step 7.1: Create InspectContent view

**File:** `Modules/FeatureMap/Sources/Surface/Content/InspectContent.swift`

- [ ] Define `InspectContent: View`
- [ ] Add properties:
  - `let context: SiteInspectionContext`
  - `let detent: SurfaceDetent`
  - `let site: DiveSite` (resolved from context.siteId)
  - `var onDismiss: () -> Void`
  - `var onLog: () -> Void`
  - `var onSave: () -> Void`
- [ ] Add state:
  - `@State private var isWishlist: Bool`
  - `@State private var showingLogWizard = false`
- [ ] Initialize isWishlist from site.wishlist
- [ ] Implement body with VStack:
  - `siteHeader` (always visible)
  - If detent != .peek: `actionsRow`
  - If detent == .expanded: ScrollView with expanded content

#### Step 7.2: Implement medium detent layout

- [ ] Implement `siteHeader`:
  - HStack: status dot + name/stats + dismiss button
  - Status dot color: logged=green, saved=blue, baseline=gray
  - Name: headline font, lineLimit 1
  - Stats: difficulty, depth, temp in caption
  - Dismiss: xmark.circle.fill button
- [ ] Implement `actionsRow`:
  - HStack with 3 ActionButtons
  - Save (star icon, toggles wishlist)
  - Plan (calendar icon, future)
  - Log (waveform icon, primary)

**File:** `Modules/FeatureMap/Sources/Surface/Components/ActionButton.swift`

- [ ] Define `ActionButton: View`
- [ ] Properties: icon, title, isActive, isPrimary, action
- [ ] Style: rounded rect, icon + label, primary uses reef color

#### Step 7.3: Implement expanded detent layout

- [ ] Add ScrollView for expanded content
- [ ] Include:
  - Hero image (if site has image)
  - Quick facts chips (difficulty, depth, temp, visibility, type)
  - Description section
  - Difficulty strip indicator
- [ ] Add bottom padding for safe area

**Current code reference:** `SitePreviewCard.swift` (header), `SiteDetailSheet.swift` (expanded)

#### Step 7.4: Wire up actions

- [ ] Save button: toggle `isWishlist`, call persistence, post notification
- [ ] Log button: set `showingLogWizard = true`
- [ ] Add `.sheet(isPresented: $showingLogWizard)` presenting `LiveLogWizardView`
- [ ] Pass site to LiveLogWizardView

**✓ Checkpoint 7:** Inspect content renders at medium/expanded, actions work.

---

### Step 8: Filter Content

**Dependencies:** Step 5 complete
**Deliverables:** 1 new file

#### Step 8.1: Create FilterContent view

**File:** `Modules/FeatureMap/Sources/Surface/Content/FilterContent.swift`

- [ ] Define `FilterContent: View`
- [ ] Add properties:
  - `@Binding var exploreFilters: ExploreFilters`
  - `@Binding var filterLens: FilterLens?`
  - `var onApply: () -> Void`
  - `var onCancel: () -> Void`
- [ ] Implement body with NavigationStack

#### Step 8.2: Implement progressive filter sections

- [ ] Add ScrollView with VStack
- [ ] **Section: My Sites lens**
  - Segmented picker: All / Saved / Logged
  - Maps to filterLens
- [ ] **Section: Difficulty**
  - Multi-select chips for Beginner/Intermediate/Advanced
  - Maps to exploreFilters.difficulty
- [ ] **Section: Site Type**
  - Multi-select chips for Reef/Wreck/Wall/Cave/Shore/Drift
  - Maps to exploreFilters.siteType
- [ ] **Section: Shops**
  - Toggle for showShops
- [ ] Add dividers between sections

**Current code reference:** `NewMapView.swift` lines 2525-2575 (CombinedFilterLayersSheet)

#### Step 8.3: Add Apply/Cancel footer

- [ ] Add sticky footer at bottom
- [ ] HStack: Reset button (left) + Active count (center) + Apply button (right)
- [ ] Reset: clears all filters, haptic
- [ ] Apply: calls onApply, haptic
- [ ] Active count: "N active" text

**✓ Checkpoint 8:** Filter content works, changes reflect in filters.

---

### Step 9: Search Content

**Dependencies:** Step 5 complete
**Deliverables:** 1 new file

#### Step 9.1: Create SearchContent view

**File:** `Modules/FeatureMap/Sources/Surface/Content/SearchContent.swift`

- [ ] Define `SearchContent: View`
- [ ] Add properties:
  - `@Binding var query: String`
  - `let sites: [DiveSite]`
  - `var onSelect: (DiveSite) -> Void`
  - `var onDismiss: () -> Void`
- [ ] Add `@FocusState private var isSearchFocused: Bool`

#### Step 9.2: Implement search UI

- [ ] Implement `searchField`:
  - HStack: magnifyingglass icon + TextField + clear button
  - Rounded rect background
  - Focused on appear
- [ ] Implement `filteredSites: [DiveSite]`:
  - Filter by query in name, location, region
  - Limit to 20 results
- [ ] Implement `resultsList`:
  - ScrollView with LazyVStack
  - For each site: SearchResultRow
- [ ] Implement `emptyState`:
  - Show when query not empty but no results
  - "No sites found" message

#### Step 9.3: Wire up selection

- [ ] On row tap: haptic, call onSelect(site)
- [ ] On select: dismiss keyboard
- [ ] On clear button: clear query, keep focus

**Current code reference:** `NewMapView.swift` lines 2418-2447 (SearchSheet)

**✓ Checkpoint 9:** Search works end-to-end with keyboard.

---

### Phase C: Integration (Steps 10-12)

**Goal:** Wire up the new surface into NewMapView alongside existing UI.

---

### Step 10: Integrate Surface into NewMapView

**Dependencies:** Steps 1-9 complete
**Deliverables:** Modifications to NewMapView.swift

#### Step 10.1: Add MapUIViewModel as secondary StateObject

**File:** `Modules/FeatureMap/Sources/NewMapView.swift`

- [ ] Add import for new State module
- [ ] Add `@StateObject private var uiViewModel = MapUIViewModel()`
- [ ] Add `@State private var surfaceDetent: SurfaceDetent = .peek`
- [ ] Keep existing `viewModel: MapViewModel` (parallel operation)

#### Step 10.2: Replace bottom sheet with UnifiedBottomSurface

- [ ] Locate `bottomSheetOverlay` in body (around line 540)
- [ ] Comment out (don't delete yet)
- [ ] Add UnifiedBottomSurface in same location:
  - Bind mode to uiViewModel.mode
  - Bind detent to surfaceDetent
  - Pass dataViewModel: viewModel
  - Wire all callbacks to uiViewModel.send()
- [ ] Verify surface appears

#### Step 10.3: Update map tap handler

- [ ] Locate `onSelect:` callback in DiveMapView (around line 740)
- [ ] Add: `uiViewModel.send(.openSiteInspection(identifier))`
- [ ] Update `surfaceDetent = .medium`
- [ ] Keep existing camera focus logic

#### Step 10.4: Add viewport change dismiss

- [ ] Locate `onRegionChange:` callback
- [ ] Add check: if in inspectSite mode
- [ ] Get inspected site coordinates
- [ ] Check if site is within visible bounds
- [ ] If not: `uiViewModel.send(.closeSiteInspection)`, `surfaceDetent = .peek`

**Edge case:** Use debounce to avoid dismissing during pan animation

**✓ Checkpoint 10:** New surface works. Can tap sites, inspect, filter, search.

---

### Step 11: Minimal HUD

**Dependencies:** Step 10 complete
**Deliverables:** 2 new files + modifications to NewMapView

#### Step 11.1: Create MinimalSearchButton

**File:** `Modules/FeatureMap/Sources/HUD/MinimalSearchButton.swift`

- [ ] Create `HUD/` directory in `FeatureMap/Sources/`
- [ ] Define `MinimalSearchButton: View`
- [ ] Add `var onTap: () -> Void`
- [ ] Implement body:
  - Button with magnifyingglass icon
  - 36x36pt size
  - .glass background with corner radius
  - Subtle shadow
- [ ] Add accessibility label: "Search dive sites"

#### Step 11.2: Create ContextLabel

**File:** `Modules/FeatureMap/Sources/HUD/ContextLabel.swift`

- [ ] Define `ContextLabel: View`
- [ ] Add properties:
  - `let mode: MapUIMode`
  - `let siteCount: Int`
  - `let isFiltered: Bool`
- [ ] Implement body:
  - Compute text based on mode:
    - Explore: "N sites nearby" or "Filtered"
    - Inspect: site name
    - Filter/Search: hidden
  - Style: caption font, mist color, slight background

#### Step 11.3: Add HUD overlay to NewMapView

- [ ] In `overlayControls` ViewBuilder
- [ ] Add MinimalSearchButton positioned `.topTrailing`
  - Offset for safe area
  - onTap: `uiViewModel.send(.openSearch)`
- [ ] Add ContextLabel positioned `.bottomLeading`
  - Above bottom surface
  - Pass mode, siteCount, isFiltered

**✓ Checkpoint 11:** HUD elements visible and functional.

---

### Step 12: Proximity Prompt Overlay

**Dependencies:** Step 10 complete
**Deliverables:** 1 new file + modifications to NewMapView

#### Step 12.1: Create ProximityPromptCard

**File:** `Modules/FeatureMap/Sources/HUD/ProximityPromptCard.swift`

- [ ] Define `ProximityPromptCard: View`
- [ ] Add properties:
  - `let state: ProximityPromptState`
  - `var onAccept: () -> Void`
  - `var onDismiss: () -> Void`
- [ ] Implement body:
  - Compact card layout
  - Site name
  - "Log your dive?" prompt
  - Two buttons: "Log" (primary) + "Dismiss"
  - Rounded corners, shadow, glass background
- [ ] Add slide-in animation

#### Step 12.2: Add to overlay layer

- [ ] In NewMapView body, after UnifiedBottomSurface
- [ ] Add conditional: `if let prompt = uiViewModel.proximityPrompt, !prompt.isDismissed`
- [ ] Show ProximityPromptCard
- [ ] Position above bottom surface (use offset or alignment)
- [ ] onAccept: `uiViewModel.send(.acceptProximityPrompt)`, present log wizard
- [ ] onDismiss: `uiViewModel.send(.dismissProximityPrompt)`
- [ ] Add appear/disappear animation

**Testing:** Use GeofenceManager debug to simulate arrival

**✓ Checkpoint 12:** Proximity prompt appears and dismisses correctly.

---

### Phase D: Cleanup (Steps 13-15)

**Goal:** Remove old UI, migrate remaining state, polish.

---

### Step 13: Remove Old UI Elements

**Dependencies:** Steps 10-12 verified working
**Deliverables:** Deletions from NewMapView.swift

**Important:** Create git tag before this step for rollback.

#### Step 13.1: Remove control rail

**File:** `NewMapView.swift`

- [ ] Delete `mapControlRail()` function (lines ~870-950)
- [ ] Delete `MapControlButton` struct (lines ~1793-1831)
- [ ] Delete `RailAccessoryButton` struct (lines ~1833-1856)
- [ ] Remove `@State private var controlRailHeight: CGFloat`
- [ ] Remove rail from `overlayControls` ViewBuilder
- [ ] Remove `featureFlags.useRail` checks
- [ ] Remove rail-related debug toggles

#### Step 13.2: Remove filter chips

- [ ] Delete `filterChipsScrollView` ViewBuilder (lines ~1259-1265)
- [ ] Delete `exploreFilterChips` ViewBuilder (lines ~1267-1275)
- [ ] Delete chip computed properties:
  - `allFilterChip`
  - `nearbyFilterChip`
  - `popularFilterChip`
  - `beginnerFilterChip`
  - `staticFilterChips`
  - `shopsFilterChip`
- [ ] Delete `FilterChip` struct (lines ~1901-1930)
- [ ] Remove chips from bottomSheetContent (if still referenced)
- [ ] Remove `featureFlags.showChipsAtPeek`

#### Step 13.3: Remove floating search pill

- [ ] Delete search pill from `overlayControls` (lines ~787-806)
- [ ] Remove `@State private var searchPillVisible`
- [ ] Remove `@State private var searchPillHideTask`
- [ ] Delete `showSearchPrompt()` function (lines ~1614-1623)
- [ ] Delete `hideSearchPrompt()` function (lines ~1625-1629)
- [ ] Remove `searchPillY` from OverlayMetrics

#### Step 13.4: Remove preview card overlay

- [ ] Remove SitePreviewCard overlay from body (lines ~547-565)
- [ ] Remove `@State private var previewSite`
- [ ] File `SitePreviewCard.swift` can be deleted or moved to `_Deprecated/`

#### Step 13.5: Remove old bottom sheet

- [ ] Delete commented-out `bottomSheetOverlay` ViewBuilder
- [ ] Delete `sheetDragGesture()` function
- [ ] Delete old `SheetDetent` enum (in NewMapView)
- [ ] Remove sheet-related @State vars:
  - `sheetDetent`
  - `lastNonPeekDetent`
  - `activeSheetHeight`
  - `sheetDragTranslation` GestureState
- [ ] Remove `OverlayMetrics` struct if no longer needed
- [ ] Remove `overlayMetrics()` function if no longer needed

**✓ Checkpoint 13:** Only new UI elements remain. App still functions.

---

### Step 14: Migrate State from MapViewModel

**Dependencies:** Step 13 complete
**Deliverables:** Modifications to MapViewModel.swift, NewMapView.swift

#### Step 14.1: Move filter state

**File:** `MapViewModel.swift`

- [ ] Remove `@Published var mode: MapMode`
- [ ] Remove `@Published var statusFilter: StatusFilter`
- [ ] Remove `@Published var exploreFilter: ExploreFilter`
- [ ] Remove `MapMode` enum definition
- [ ] Remove `StatusFilter` enum definition
- [ ] Remove `ExploreFilter` enum definition
- [ ] Update any remaining references in MapViewModel methods

**File:** `NewMapView.swift`

- [ ] Update `filteredSites` to use `uiViewModel.exploreFilters`
- [ ] Update any filter-dependent computed properties

#### Step 14.2: Move hierarchy state

**File:** `MapViewModel.swift`

- [ ] Remove `@Published var tier: Tier`
- [ ] Remove `@Published var selectedRegion: Region?`
- [ ] Remove `@Published var selectedArea: Area?`
- [ ] Remove `Tier` enum definition
- [ ] Keep `regions: [Region]` data (not UI state)

**File:** `NewMapView.swift`

- [ ] Update hierarchy-dependent logic to use `uiViewModel.currentHierarchyLevel`
- [ ] Update breadcrumb display logic

#### Step 14.3: Clean up MapViewModel

- [ ] Review remaining properties
- [ ] Keep data-related properties:
  - `sites: [DiveSite]`
  - `visibleSites: [DiveSite]`
  - `shops: [MapDiveShop]`
  - `regions: [Region]`
  - `loading: Bool`
  - `layerSettings: MapLayerSettings`
- [ ] Keep data methods:
  - `refreshVisibleSites(bounds:)`
  - `applyExploreFilters(to:)` — update to use ExploreFilters
  - `applyMyMapFilters(to:)` — update to use FilterLens
- [ ] Remove UI-specific methods
- [ ] Remove filter persistence (now in MapStatePersistence)

**✓ Checkpoint 14:** Single source of truth for UI state.

---

### Step 15: Final Cleanup & Polish

**Dependencies:** Step 14 complete
**Deliverables:** Various cleanup tasks

#### Step 15.1: Remove feature flags

**File:** `NewMapView.swift`

- [ ] Delete `MapFeatureFlags` struct
- [ ] Remove `@State private var featureFlags`
- [ ] Remove all `featureFlags.` conditionals
- [ ] Remove debug toggles from DEBUG builds

#### Step 15.2: Delete deprecated files

- [ ] Create `_Deprecated/` folder (or delete directly)
- [ ] Move/delete `SitePreviewCard.swift`
- [ ] Move/delete `SiteDetailSheet.swift` (content merged into InspectContent)
- [ ] Review and clean up any unused helper files

#### Step 15.3: Update tab bar behavior

**File:** `UmiLogApp.swift`

- [ ] Review `tabBarVisibilityShouldChange` notification handling
- [ ] Simplify logic: hide only when surfaceDetent == .expanded
- [ ] Remove complex mutual exclusion logic
- [ ] Test tab bar visibility across all modes

#### Step 15.4: Accessibility pass

- [ ] Add accessibility labels to all HUD elements
- [ ] Add accessibility labels to surface drag handle
- [ ] Test VoiceOver navigation through:
  - [ ] Explore mode (list, filter button)
  - [ ] Inspect mode (site details, actions)
  - [ ] Filter mode (all controls)
  - [ ] Search mode (field, results)
- [ ] Ensure focus moves correctly on mode transitions
- [ ] Add accessibility hints where appropriate

#### Step 15.5: Animation polish

- [ ] Review spring parameters in UnifiedBottomSurface
- [ ] Tune response/damping for natural feel
- [ ] Add `@Environment(\.accessibilityReduceMotion)` checks
- [ ] Reduce/remove animations when reduce motion enabled
- [ ] Profile with Instruments:
  - [ ] Verify 60fps during drag gestures
  - [ ] Check for unnecessary redraws
  - [ ] Optimize if needed

**✓ Checkpoint 15:** Refactor complete!

---

## Validation & Testing

### Functional Validation Checklist

After completion, manually verify each item:

**Mode Behavior:**
- [ ] App launches in Explore mode at .peek detent
- [ ] User can always identify "what mode am I in"
- [ ] Only one surface feels actionable at a time

**Explore Mode:**
- [ ] Shows site count at peek
- [ ] Swipe up expands to show site list
- [ ] Filter button opens Filter mode
- [ ] Site tap opens Inspect mode
- [ ] Hierarchy breadcrumbs work (world → region → area)
- [ ] Filter lens (My Sites) filters correctly

**Inspect Mode:**
- [ ] Shows site details at medium
- [ ] Swipe up expands to full details
- [ ] Save/Plan/Log actions work
- [ ] Swipe down dismisses to Explore
- [ ] Tap empty map dismisses to Explore
- [ ] **Panning site offscreen dismisses immediately**

**Filter Mode:**
- [ ] Opens at expanded detent
- [ ] All filter controls work
- [ ] Apply saves and returns to Explore
- [ ] Cancel discards and returns to Explore
- [ ] Reset clears all filters

**Search Mode:**
- [ ] Opens from search icon
- [ ] Keyboard appears automatically
- [ ] Results filter as you type
- [ ] Tap result opens Inspect
- [ ] Dismiss returns to Explore

**Persistence:**
- [ ] Filters persist across app restart
- [ ] Filter lens persists across app restart
- [ ] Camera position persists across app restart
- [ ] Hierarchy does NOT persist (resets to world)
- [ ] Selected site does NOT persist

**Proximity Prompt:**
- [ ] Appears when entering geofence
- [ ] Does not block map interaction
- [ ] Accept opens log wizard
- [ ] Dismiss removes overlay
- [ ] Does not persist on tab switch

**Gestures:**
- [ ] No gesture has dual meaning across modes
- [ ] Drag gestures feel smooth (60fps)
- [ ] Reduce Motion is respected

**Edge Cases:**
- [ ] Empty state when no sites match filters
- [ ] 0 sites visible shows appropriate message
- [ ] Cluster tap zooms in (doesn't select)
- [ ] Tab bar visibility is consistent

### Automated Tests

**Unit Tests (MapUIReducerTests):**
- [ ] All 17+ transition tests pass

**UI Tests (if applicable):**
- [ ] Mode transition flows
- [ ] Filter apply/cancel
- [ ] Search selection

---

## Rollback Plan

### Prevention

1. **Parallel Operation:** New UI runs alongside old during development
2. **Feature Flag:** Can add `useNewSurface` toggle if needed
3. **Git Tags:** Tag at each checkpoint for easy revert

### If Issues Arise

**Minor issues:**
- Fix forward in the new code
- Old code is still present (commented) for reference

**Major issues (Step 10-12):**
- Uncomment old bottomSheetOverlay
- Remove UnifiedBottomSurface reference
- Revert to checkpoint 9 tag

**Critical issues (Step 13+):**
- `git revert` to pre-Step 13 tag
- Old UI fully restored

### Checkpoint Tags

Create these tags during implementation:
- `ui-redesign/checkpoint-1` — State types complete
- `ui-redesign/checkpoint-2` — Reducer tested
- `ui-redesign/checkpoint-3` — ViewModel complete
- `ui-redesign/checkpoint-5` — Surface shell working
- `ui-redesign/checkpoint-9` — All content views complete
- `ui-redesign/checkpoint-10` — Integration complete (parallel)
- `ui-redesign/checkpoint-13` — Old UI removed
- `ui-redesign/checkpoint-15` — Refactor complete

---

## Appendix: Current Code Line References

For quick navigation during implementation:

### NewMapView.swift (~2580 lines)

| Feature | Lines | Notes |
|---------|-------|-------|
| State declarations | 37-81 | @State vars to remove/migrate |
| Body structure | 500-600 | Main ZStack |
| Preview card overlay | 547-565 | To remove |
| overlayControls | 780-950 | Rail, pill to remove |
| mapControlRail | 870-950 | To delete |
| bottomSheetOverlay | 1100-1200 | To replace |
| filterChips | 1259-1374 | To delete |
| Sheet detent logic | 1500-1600 | To replace |
| MapControlButton | 1793-1831 | To delete |
| RailAccessoryButton | 1833-1856 | To delete |
| FilterChip | 1901-1930 | To delete |

### MapViewModel.swift

| Feature | Lines | Notes |
|---------|-------|-------|
| Mode enums | 67-81 | To move to MapUIMode |
| Filter enums | 72-80 | To move to ExploreFilters |
| Tier/hierarchy | 82-84 | To move to HierarchyLevel |
| Persistence | 95-102 | To move to MapStatePersistence |

---

*End of Plan Document*
