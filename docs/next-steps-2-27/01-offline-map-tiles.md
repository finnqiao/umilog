# 1. Offline Map Tile Packs

**Priority**: Tier 1 — Critical
**Estimated Complexity**: High
**Module**: `DiveMap` (extend) + new `OfflineTilePackManager`
**Migration**: None (no schema changes)

---

## Problem

UmiLog's database is fully offline (GRDB + seed data), but map tiles require network. Users on liveaboards, remote islands, or areas with poor connectivity see blank maps — the #1 pain point in UX research.

## Current State

- MapLibre 6.10.0 is the map engine (supports `MLNOfflineStorage` API)
- 5 regional tile JSON files already partition sites geographically
- Map styles: `umilog_underwater_vector.json` (primary), `umilog_offline.json` (PMTiles fallback exists but no download UI)
- No user-facing download mechanism

## Implementation Plan

### Step 1: Define Region Bounding Boxes

Extract bounding boxes from existing regional seed data (`Resources/SeedData/`). Each region becomes a downloadable pack.

```swift
// DiveMap/Offline/OfflineRegion.swift
struct OfflineRegion: Identifiable {
    let id: String           // e.g. "red-sea"
    let name: String         // e.g. "Red Sea"
    let bounds: MLNCoordinateBounds
    let minZoom: Double      // 5
    let maxZoom: Double      // 14 (balance detail vs size)
    let estimatedSizeMB: Int
    let siteCount: Int
}
```

Predefined regions (align with existing `regions` table):
- Red Sea (Egypt, Saudi, Jordan)
- Southeast Asia (Thailand, Indonesia, Philippines, Malaysia)
- Caribbean (Mexico, Belize, Honduras, Cayman)
- Pacific (Palau, Fiji, Galápagos, Hawaii)
- Mediterranean & Atlantic (Spain, Croatia, Azores, Canary Is.)

### Step 2: OfflineTilePackManager

```swift
// DiveMap/Offline/OfflineTilePackManager.swift
@Observable
final class OfflineTilePackManager {
    private let storage = MLNOfflineStorage.shared

    // State
    var packs: [OfflinePack] = []          // Downloaded/downloading
    var availableRegions: [OfflineRegion]   // All regions
    var totalStorageUsedMB: Double

    // Actions
    func download(region: OfflineRegion) async throws
    func pause(packId: String)
    func resume(packId: String)
    func delete(packId: String) async throws
    func checkForUpdates() async -> [OfflinePack]

    // Progress
    func progress(for packId: String) -> OfflinePackProgress
}

struct OfflinePack: Identifiable {
    let id: String
    let region: OfflineRegion
    let status: PackStatus      // .downloading, .complete, .paused, .error
    let progress: Double        // 0.0–1.0
    let downloadedAt: Date?
    let sizeMB: Double
    let tileCount: Int
}
```

Use `MLNOfflinePack` under the hood:
1. Create `MLNTilePyramidOfflineRegion` from bounding box + zoom range
2. Call `MLNOfflineStorage.shared.addPack(for:withContext:completionHandler:)`
3. Observe `MLNOfflinePackProgressChangedNotification` for progress
4. Store pack metadata in UserDefaults or a lightweight plist

### Step 3: Download UI

New view in Settings or a dedicated "Offline Maps" section:

```
┌─────────────────────────────┐
│ Offline Maps                │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🗺️ Red Sea          12MB│ │
│ │ 234 sites  ━━━━━━━━ ✅  │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 🗺️ Southeast Asia   28MB│ │
│ │ 412 sites  [Download]   │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 🗺️ Caribbean        15MB│ │
│ │ 189 sites  ━━━━░░░ 67%  │ │
│ └─────────────────────────┘ │
│                             │
│ Storage: 40MB / ~120MB est. │
│ [Download All]              │
└─────────────────────────────┘
```

Files:
- `FeatureSettings/OfflineMaps/OfflineMapsView.swift`
- `FeatureSettings/OfflineMaps/OfflineRegionCard.swift`
- `FeatureSettings/OfflineMaps/OfflineMapsViewModel.swift`

### Step 4: Pack Lifecycle

- **Expiry**: Check tile age on app launch, prompt re-download after 90 days
- **Updates**: Compare server tile version hash vs local, offer incremental update
- **Storage management**: Show per-pack size, total used, device free space
- **Background download**: Use `URLSession` background config for large packs
- **Error recovery**: Resume interrupted downloads, retry on connectivity

### Step 5: Map Integration

- When offline packs exist, `MapVC` should prefer offline tiles automatically (MapLibre handles this)
- Add a subtle "Offline" badge on the map when using cached tiles
- Ensure `umilog_offline.json` style references match offline pack tile sources

## Testing

- [ ] Download a region on Wi-Fi, enable airplane mode, verify map renders
- [ ] Pause/resume download, verify progress persists
- [ ] Delete a pack, verify storage freed
- [ ] Test with map panning across region boundaries (partial coverage)
- [ ] Verify offline tiles + online vector tiles coexist gracefully
- [ ] Test storage pressure scenario (low disk space warning)

## Dependencies

- MapLibre 6.10.0 `MLNOfflineStorage` API
- Tile server must support the zoom levels we request
- Need to determine tile source URL that allows offline caching (check TOS)

## Risks

- **Tile server TOS**: Some tile providers prohibit bulk download. Verify with current provider or self-host
- **Storage size**: High zoom levels balloon storage. Cap at z14 for reasonable pack sizes (~10-30MB/region)
- **Bathymetry tiles**: Ocean raster tiles (Esri) may not support offline. May need separate source
