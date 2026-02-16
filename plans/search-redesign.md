# Search Experience Redesign for UmiLog

## Overview

Redesign the search functionality from an empty placeholder to a rich, browseable discovery interface inspired by Resy. The new search will show collections, categories, recently viewed sites, and popular regions when the query is empty.

## Current State

- **SearchContent.swift** shows a static placeholder when query is empty
- Filter pills exist but are limited to site types (All, Wrecks, Reefs, Caves, Night)
- No location context, collections, or recently viewed tracking
- Hierarchical search results work but lack visual richness

## Design Goals

1. Replace empty state with browseable content
2. Show four collections: Saved, Logged, Planned, Near Me
3. Category grid for site types and difficulty levels
4. Recently viewed sites with rich cards (track in UserDefaults)
5. Category tap applies filter and shows results inline
6. Popular regions section for discovery

---

## Implementation Plan

### Phase 1: Data Layer

**1.1 Create RecentlyViewedSite model**
- File: `Modules/UmiDB/Sources/Models/RecentlyViewedSite.swift` (NEW)
- Lightweight Codable struct: id, name, location, region, type, difficulty, maxDepth, viewedAt
- Initialize from DiveSite

**1.2 Extend MapStatePersistence for recently viewed sites**
- File: `Modules/FeatureMap/Sources/State/MapStatePersistence.swift`
- Add `addRecentSite(_:)`, `loadRecentSites()`, `clearRecentSites()`
- Store in UserDefaults, max 20 sites, most recent first
- Add key: `map.recentSites`

**1.3 Add SiteRepository query methods**
- File: `Modules/UmiDB/Sources/Repositories/SiteRepository.swift`
- Add `fetchByType(_ type: SiteType, limit: Int) -> [SiteLite]`
- Add `fetchByDifficulty(_ difficulty: Difficulty, limit: Int) -> [SiteLite]`

### Phase 2: New UI Components

**2.1 SearchCategory enum**
- File: `Modules/FeatureMap/Sources/State/SearchCategory.swift` (NEW)
- Cases: wrecks, reefs, caves, walls, shore, drift, beginner, advanced, nightDiving, highBiodiversity
- Properties: displayName, icon (SF Symbol), color

**2.2 LocationContextChip**
- File: `Modules/FeatureMap/Sources/Surface/Components/LocationContextChip.swift` (NEW)
- Shows current region with location icon
- Optional remove button (x icon)
- Capsule shape with trench background

**2.3 CollectionCard**
- File: `Modules/FeatureMap/Sources/Surface/Components/CollectionCard.swift` (NEW)
- Circle icon with label and count
- 4 cards: Saved (heart), Logged (checkmark), Planned (calendar), Near Me (location)
- Horizontal scroll layout

**2.4 CategoryGridCell**
- File: `Modules/FeatureMap/Sources/Surface/Components/CategoryGridCell.swift` (NEW)
- Row with icon, label, chevron
- 2-column grid layout
- Tap applies filter inline

**2.5 RecentlyViewedSiteCard**
- File: `Modules/FeatureMap/Sources/Surface/Components/RecentlyViewedSiteCard.swift` (NEW)
- Image at top (reuse SiteImage component)
- Name, type, depth, location
- Horizontal scroll layout

**2.6 SearchBrowseContent container**
- File: `Modules/FeatureMap/Sources/Surface/Content/SearchBrowseContent.swift` (NEW)
- Composes all browse sections in ScrollView
- Sections: Location context, Collections, Categories, Recently Viewed, Popular Regions
- Callbacks for all tap handlers

### Phase 3: Integration

**3.1 Refactor SearchContent.swift**
- File: `Modules/FeatureMap/Sources/Surface/Content/SearchContent.swift`
- Replace `placeholderView` with `SearchBrowseContent`
- Add state for browse data: savedSites, loggedSites, plannedSites, nearbySites, popularRegions
- Add `loadBrowseData()` async method using existing repository methods
- Add `trackSiteView(_:)` to record recently viewed
- Add `handleCategoryTap(_:)` to apply filter and show inline results

**3.2 Category filtering behavior**
- When category tapped: set `selectedSiteTypes` or `selectedDifficulty`
- Show filtered results in existing hierarchical list
- Clear filter returns to browse view

**3.3 Update empty results state**
- Add "Clear All" button to reset query and filters
- Better messaging: "No sites match your search"

**3.4 Enhance SiteTypeFilterRow**
- File: `Modules/FeatureMap/Sources/Surface/Components/SiteTypeFilterRow.swift`
- Add missing types: Wall, Shore, Drift
- Consider adding difficulty pills or keeping in category grid only

---

## Files Summary

### New Files (7)
| File | Purpose |
|------|---------|
| `UmiDB/Sources/Models/RecentlyViewedSite.swift` | Recently viewed site model |
| `FeatureMap/Sources/State/SearchCategory.swift` | Category enum |
| `FeatureMap/Sources/Surface/Content/SearchBrowseContent.swift` | Browse container view |
| `FeatureMap/Sources/Surface/Components/LocationContextChip.swift` | Location chip |
| `FeatureMap/Sources/Surface/Components/CollectionCard.swift` | Collection icon card |
| `FeatureMap/Sources/Surface/Components/CategoryGridCell.swift` | Category grid cell |
| `FeatureMap/Sources/Surface/Components/RecentlyViewedSiteCard.swift` | Recent site card |

### Modified Files (4)
| File | Changes |
|------|---------|
| `FeatureMap/Sources/State/MapStatePersistence.swift` | Add recent sites tracking |
| `UmiDB/Sources/Repositories/SiteRepository.swift` | Add fetchByType/fetchByDifficulty |
| `FeatureMap/Sources/Surface/Content/SearchContent.swift` | Replace placeholder, add browse integration |
| `FeatureMap/Sources/Surface/Components/SiteTypeFilterRow.swift` | Add Wall, Shore, Drift types |

---

## Verification

1. **Build**: `xcodegen generate && xcodebuild -scheme UmiLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
2. **Test browse view**: Open search with empty query, verify all sections appear
3. **Test collections**: Tap each collection (Saved, Logged, Planned, Near Me), verify navigation
4. **Test categories**: Tap a category, verify filter applies and results show
5. **Test recently viewed**: View a site, return to search, verify it appears in Recently Viewed
6. **Test location**: With location permission, verify Near Me shows nearby sites
7. **Test empty state**: Search for nonsense, verify "Clear All" works

---

## Reference Files

- `FeatureMap/Sources/Surface/Content/FallbackShelfContent.swift` - Pattern for browse sections
- `FeatureMap/Sources/Components/SiteImage.swift` - Image component for cards
- `UmiDB/Sources/Models/DiveSite.swift` - Site model with type/difficulty enums
- `FeatureMap/Sources/State/MapStatePersistence.swift` - Existing pattern for UserDefaults persistence
