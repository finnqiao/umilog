# NewMapView.swift Refactoring Plan

**Current Size**: 2,107 lines
**Target Size**: ~300-400 lines per file
**Goal**: Reduce to 6-7 focused files

---

## Current Structure Analysis

The file contains these major sections (by MARK comments):

| Section | Lines | Description |
|---------|-------|-------------|
| Properties & Init | 1-80 | State, bindings, repositories |
| Hierarchy Helpers | 103-165 | Drill-down navigation helpers |
| Computed Properties | 166-670 | Bindings, annotations, camera logic |
| View Components | 671-680 | Main mapView composition |
| Proximity Prompt | 682-707 | Geofence arrival card |
| Unified Surface | 709-1003 | Bottom sheet surface |
| HUD Overlay | 1004-1203 | Top controls, context label |
| Action Handlers | 1204-1252 | Event handlers |
| Smart Camera | 1253-1392 | Initial camera logic |
| Environment Helpers | 1393-1416 | SafeArea, parsing |
| Pin View | 1417-1450 | Map pin appearance |
| Breadcrumb & Areas | 1451-1554 | Navigation breadcrumbs |
| Regions List | 1555-1660 | Region grid view |
| Sites List | 1661-1914 | Site cards and list |
| Helper Extensions | 1915-1943 | Utility extensions |
| Sheets | 1944-2107 | Modal sheets |

---

## Proposed File Structure

### 1. `NewMapView.swift` (~350 lines)
**Main coordinator view - KEEP**

Keep:
- Properties & state declarations
- Main `body` composition
- `mapView` computed property
- Core bindings (uiModeBinding, filterLensBinding, etc.)

Remove everything else to extracted files.

```swift
public struct NewMapView: View {
    // Properties
    // Bindings
    // body: ZStack of mapLayer + overlayControls + surface + prompt
}
```

---

### 2. `Map/MapHierarchyHelpers.swift` (~100 lines)
**NEW FILE**

Extract hierarchy navigation logic:
- `currentHierarchy`
- `isDrilledDown`
- `currentRegionId`, `currentAreaId`
- `currentRegion`, `currentTier`
- `areasInCurrentRegion`
- `parseAreaCountry()` helper

```swift
extension NewMapView {
    var currentHierarchy: HierarchyLevel { ... }
    var isDrilledDown: Bool { ... }
    var areasInCurrentRegion: [Area] { ... }
}
```

---

### 3. `Map/MapHUD.swift` (~250 lines)
**NEW FILE**

Extract HUD overlay components:
- `topOverlay` view
- `overlayControls` view
- `ContextLabel` usage
- `MinimalSearchButton` integration
- HUD-related computed properties (`hudSiteCount`, `hudIsFiltered`)

```swift
extension NewMapView {
    var topOverlay: some View { ... }
    var overlayControls: some View { ... }
}
```

---

### 4. `Map/MapSurfaceIntegration.swift` (~200 lines)
**NEW FILE**

Extract UnifiedBottomSurface wiring:
- `unifiedSurfaceOverlay` view
- Surface-related bindings
- `proximityPromptOverlay` view
- Detent-related logic

```swift
extension NewMapView {
    var unifiedSurfaceOverlay: some View { ... }
    var proximityPromptOverlay: some View { ... }
}
```

---

### 5. `Map/MapCameraController.swift` (~200 lines)
**NEW FILE**

Extract camera/viewport logic:
- `onCameraChange()` handler
- Smart initial camera (`fitToSmartRegion`, `getBestFitRegion`)
- Viewport-driven queries
- Region fitting (`fitToRegion`, `fitToSites`)
- `calculateBoundsForSites()`

```swift
extension NewMapView {
    func onCameraChange(_ viewport: DiveMapViewport) { ... }
    func fitToSmartRegion() async { ... }
    func fitToRegion(_ region: Region) { ... }
}
```

---

### 6. `Map/MapActionHandlers.swift` (~150 lines)
**NEW FILE**

Extract user action handlers:
- `handleSiteSelection(_:)`
- `handleDrillDown(to:)`
- `handleBreadcrumbTap(_:)`
- `startLiveLog(at:)`
- Wishlist toggle actions

```swift
extension NewMapView {
    func handleSiteSelection(_ siteId: String) { ... }
    func handleDrillDown(to region: Region) { ... }
    func startLiveLog(at site: DiveSite) { ... }
}
```

---

### 7. `Map/MapAnnotations.swift` (~100 lines)
**NEW FILE**

Extract annotation building:
- `diveMapAnnotations` computed property
- `SitePinView` struct
- Annotation conversion logic

```swift
extension NewMapView {
    var diveMapAnnotations: [DiveMapAnnotation] { ... }
}

struct SitePinView: View { ... }
```

---

### 8. `Map/MapSheets.swift` (~150 lines)
**NEW FILE**

Extract sheet modifiers:
- `.sheet(isPresented: $showFilters)`
- `.sheet(item: $sheetSite)` for site details
- `.fullScreenCover` for logging
- All sheet-related state and presentation

```swift
extension NewMapView {
    var sheetModifiers: some ViewModifier { ... }
}
```

---

### 9. `Lists/RegionsListView.swift` (~150 lines)
**NEW FILE - Standalone View**

Extract regions list as standalone view:
- `RegionCard` view
- Region grid layout
- Tap handling

```swift
struct RegionsListView: View {
    let regions: [Region]
    let onSelect: (Region) -> Void

    var body: some View { ... }
}

struct RegionCard: View { ... }
```

---

### 10. `Lists/SitesListView.swift` (~250 lines)
**NEW FILE - Standalone View**

Extract sites list as standalone view:
- `SiteCard` view
- List layout with scroll syncing
- Empty state handling

```swift
struct SitesListView: View {
    let sites: [DiveSite]
    let selectedId: String?
    let onSelect: (DiveSite) -> Void

    var body: some View { ... }
}

struct SiteCard: View { ... }
```

---

### 11. `Lists/BreadcrumbHeader.swift` (~100 lines)
**NEW FILE - Standalone View**

Extract breadcrumb navigation:
- `BreadcrumbRow` view
- Hierarchy display
- Back navigation

```swift
struct BreadcrumbHeader: View {
    let hierarchy: HierarchyLevel
    let onTap: (HierarchyLevel) -> Void

    var body: some View { ... }
}
```

---

## Implementation Order

### Phase 1: Extract Standalone Views (Low Risk)
1. `RegionsListView.swift` - No dependencies on NewMapView
2. `SitesListView.swift` - No dependencies on NewMapView
3. `BreadcrumbHeader.swift` - No dependencies on NewMapView

### Phase 2: Extract Extensions (Medium Risk)
4. `MapHierarchyHelpers.swift` - Pure computed properties
5. `MapAnnotations.swift` - Pure computed property
6. `MapActionHandlers.swift` - Methods only

### Phase 3: Extract View Components (Higher Risk)
7. `MapHUD.swift` - View composition
8. `MapSurfaceIntegration.swift` - View composition
9. `MapCameraController.swift` - Camera logic
10. `MapSheets.swift` - Modifiers

### Phase 4: Cleanup
11. Update imports in NewMapView.swift
12. Verify all extensions are visible
13. Test compile and runtime behavior

---

## File Size Estimates

| File | Est. Lines | Purpose |
|------|-----------|---------|
| NewMapView.swift | ~350 | Main view coordinator |
| MapHierarchyHelpers.swift | ~100 | Navigation helpers |
| MapHUD.swift | ~250 | Top overlay controls |
| MapSurfaceIntegration.swift | ~200 | Bottom surface wiring |
| MapCameraController.swift | ~200 | Camera/viewport logic |
| MapActionHandlers.swift | ~150 | User actions |
| MapAnnotations.swift | ~100 | Pin building |
| MapSheets.swift | ~150 | Modal sheets |
| RegionsListView.swift | ~150 | Regions grid |
| SitesListView.swift | ~250 | Sites list |
| BreadcrumbHeader.swift | ~100 | Nav breadcrumbs |
| **Total** | **~2000** | Same functionality |

---

## Benefits

1. **Maintainability**: Each file has a single responsibility
2. **Compile times**: Smaller files compile faster
3. **Navigation**: Easier to find code by purpose
4. **Testing**: Standalone views can be unit tested
5. **Reusability**: Lists can be reused in other contexts

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking state bindings | Keep all @State in main file |
| Extension visibility | Use `internal` access, same module |
| Circular dependencies | Extract standalone views first |
| Lost context | Add file headers with purpose |

---

## Prerequisites

Before starting:
- [ ] Ensure all tests pass
- [ ] Create git branch: `refactor/split-newmapview`
- [ ] Verify no pending changes to NewMapView.swift

---

## Success Criteria

- [ ] NewMapView.swift < 400 lines
- [ ] No new compiler warnings
- [ ] All existing functionality works
- [ ] Map renders correctly
- [ ] Bottom surface works
- [ ] Navigation drill-down works
- [ ] Site selection works
- [ ] Logging flow works
