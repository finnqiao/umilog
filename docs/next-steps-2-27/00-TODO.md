# UmiLog Next Steps — Master TODO

Generated 2026-02-27 from the UX Research Gap Analysis.
Each item links to a detailed implementation plan in this folder.

---

## Tier 1 — Foundation (Critical Gaps)

- [ ] **1. Offline Map Tile Packs** → [01-offline-map-tiles.md](./01-offline-map-tiles.md)
  - [ ] Define region bounding boxes from existing tile JSONs
  - [ ] Implement `OfflineTilePackManager` using MapLibre `MLNOfflineStorage`
  - [ ] Build download UI (region picker, progress, storage info)
  - [ ] Add pack lifecycle management (update, delete, expire)
  - [ ] Test on airplane mode in simulator + device

- [ ] **2. Crowdsourced Conditions Layer** → [02-crowdsourced-conditions.md](./02-crowdsourced-conditions.md)
  - [ ] Create `ConditionReport` model + migration (v10)
  - [ ] Build lightweight "Report Conditions" quick-entry sheet
  - [ ] Aggregate reports per site (local + CloudKit)
  - [ ] Add conditions overlay layer to MapLibre map
  - [ ] Display recency badges on site cards

- [ ] **3. Dive File Import (UDDF/Subsurface XML)** → [03-dive-file-import.md](./03-dive-file-import.md)
  - [ ] Audit & harden existing `UDDFImporter` (depth profiles, gas mixes)
  - [ ] Add Subsurface XML importer
  - [ ] Build unified import flow (file picker → preview → confirm)
  - [ ] Add site-matching heuristics (GPS proximity, name fuzzy match)
  - [ ] Register UTTypes for .uddf, .ssrf, .xml file association

---

## Tier 2 — Engagement (Moderate Gaps, High Value)

- [ ] **4. Digital C-Card Storage** → [04-digital-c-card.md](./04-digital-c-card.md)
  - [ ] Create `Certification` model + migration
  - [ ] Build cert entry form (agency, level, number, date, photo)
  - [ ] Add cert display card in Profile tab
  - [ ] Photo capture/import for card images
  - [ ] CloudKit sync for certs

- [ ] **5. "Open in Maps" Navigation** → [05-open-in-maps.md](./05-open-in-maps.md)
  - [ ] Add "Navigate" button to site detail card
  - [ ] Implement `MKMapItem.openInMaps()` handoff
  - [ ] Support entry-type context (shore vs boat directions)
  - [ ] Add copy-coordinates action as fallback

- [ ] **6. Dive History Heat Map** → [06-dive-history-heatmap.md](./06-dive-history-heatmap.md)
  - [ ] Query user's dive coordinates from DiveLog
  - [ ] Build MapLibre heatmap source + layer
  - [ ] Add toggle in My Map mode (pins vs heat map)
  - [ ] Style heat map with underwater color palette
  - [ ] Handle edge cases (few dives, GPS-only dives)

- [ ] **7. Photo Attachments for Sightings** → [07-sighting-photos.md](./07-sighting-photos.md)
  - [ ] Create `SightingPhoto` model + migration
  - [ ] Implement photo capture/picker in sighting form
  - [ ] Store photos in app documents dir (not DB)
  - [ ] Display photo gallery on sighting detail
  - [ ] CloudKit asset sync for photos

---

## Tier 3 — Differentiation (Blue Ocean)

- [ ] **8. BLE Dive Computer Sync** → [08-ble-dive-computer.md](./08-ble-dive-computer.md)
  - [ ] Research BLE GATT profiles for target brands
  - [ ] Create `UmiBLEKit` module with CoreBluetooth scanning
  - [ ] Implement Shearwater protocol parser (most open)
  - [ ] Build pairing/sync UI flow
  - [ ] Map dive computer data to DiveLog fields
  - [ ] Auto-match synced dives to nearby sites

- [ ] **9. AI Species Identification** → [09-ai-species-id.md](./09-ai-species-id.md)
  - [ ] Phase 1: Camera integration in sighting flow
  - [ ] Phase 2: On-device Vision classifier (CoreML)
  - [ ] Train/source marine life classification model
  - [ ] Map classifier output to WildlifeSpecies catalog
  - [ ] Show confidence + top-3 suggestions UI

- [ ] **10. Gear Inventory & Maintenance** → [10-gear-inventory.md](./10-gear-inventory.md)
  - [ ] Create `GearItem` model + migration
  - [ ] Build gear list view in Profile/Settings
  - [ ] Add gear selection to dive log wizard
  - [ ] Implement service reminders (local notifications)
  - [ ] Track gear usage stats (dive count per item)

- [ ] **11. 3D Bathymetric Briefings** → [11-3d-bathymetry.md](./11-3d-bathymetry.md)
  - [ ] Source bathymetric DEM data (GEBCO, NOAA)
  - [ ] Enable MapLibre terrain/hillshade layers
  - [ ] Build 3D site preview with pitch/bearing controls
  - [ ] Add depth contour overlay option
  - [ ] Optimize tile loading for performance

---

## Tier 4 — Polish

- [ ] **12. Battery Optimization / Boat Mode** → [12-battery-optimization.md](./12-battery-optimization.md)
  - [ ] Audit current GPS polling and map tile fetch behavior
  - [ ] Implement reduced-power "Boat Mode" toggle
  - [ ] Reduce location updates to significant-change only when backgrounded
  - [ ] Add battery-aware tile prefetch logic
  - [ ] Test battery drain with Instruments Energy Log

- [ ] **13. Contextual Permission Flow** → [13-contextual-permissions.md](./13-contextual-permissions.md)
  - [ ] Audit current permission request timing
  - [ ] Defer location permission to first map interaction
  - [ ] Add contextual explanation dialogs before system prompts
  - [ ] Review Info.plist usage description strings
  - [ ] Test permission flows on fresh install

- [ ] **14. Map Control Thumb-Zone Audit** → [14-thumb-zone-audit.md](./14-thumb-zone-audit.md)
  - [ ] Inventory all map overlay control positions
  - [ ] Move zoom/layer/locate buttons to bottom-right cluster
  - [ ] Ensure all controls have 44pt minimum tap targets
  - [ ] Test reachability on iPhone SE → Pro Max range
  - [ ] Validate against one-handed usage heuristics

---

## Working Agreements

- **Branch naming**: `feature/XX-short-name` (e.g. `feature/01-offline-tiles`)
- **Migration numbering**: Continue from v9 (next is v10)
- **Module placement**: New modules in `Modules/`, new features in `Feature*` targets
- **Test coverage**: Each new model gets unit tests in `UmiLogTests`
- **Commit style**: Conventional commits (`feat:`, `fix:`, `chore:`)
