# 🏗️ UmiLog Architecture (Map‑first Refactor)

## Overview

UmiLog is an offline‑first, privacy‑focused iOS app. The 2025 refactor moves to a map‑first IA with bottom‑sheet site details and a 4‑step logging wizard. The database remains GRDB + SQLCipher with optional CloudKit E2E sync.

## Core Principles

1. Offline‑first, local‑database authoritative
2. Data ownership and E2E encryption for sync
3. Fast paths: sub‑100ms writes, <2s cold start
4. Reliability: crash‑safe transactions, idempotent saves
5. Privacy: on‑device processing, minimal telemetry

## Navigation & IA

Tabs: Map · History · Log (FAB) · Wildlife · Profile

- Map has two modes via segmented control: My Map and Explore
- Tiering: Regions → Areas → Sites (pill tabs)
- Details are bottom sheets with snaps at 24% / 58% / 92%
- My Map surfaces owned pins (Visited/Wishlist/Planned)
- Explore shows all pins; muted for non‑selected filters

## High‑Level System

```
┌─────────────────────────────────────────────────────────┐
│ iOS App (SwiftUI)                                       │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Features                                          │  │
│  │ Map | History | Logging Wizard | Wildlife | Profile│  │
│  └───────────────────────────────────────────────────┘  │
│  Services: UmiLocationKit · UmiSpeechKit · UmiPDFKit     │
│  Data: UmiDB (GRDB + SQLCipher) · UmiSyncKit (CloudKit)  │
└─────────────────────────────────────────────────────────┘
```

## Modules (selected)

- FeatureHome (Map)
  - MapViewModel: state for mode/tier/filters (persisted via UIStateRepository)
  - BottomSheetController: presents Region/Area/Site cards
  - Actions: Log here (My Map), Add to ★ Wishlist (Explore)
- FeatureLiveLog (Wizard)
  - LogDraft: site/time, depth/duration, conditions, selectedSpecies, notes
  - WizardSaver: persists and posts notifications
- FeatureWildlife
  - SpeciesSearchView + SpeciesRepository
- FeatureHistory
  - KPIs, grouped cards, quick actions
- FeatureProfile
  - Stats tiles, achievements, Cloud backup toggle, data controls

## Data Layer

Tables (minimum to ship):
- Region(id, name, bounds)
- Area(id, region_id, name, bounds)
- Site(id, area_id, name, lat, lon, tags, typicals)
- Dive(id, site_id, date, start_time, max_depth, bottom_time, pressures, conditions, notes, status)
- ListState(site_id, state: visited|wishlist|planned)
- Species(id, names, rarity, regions)
- Sighting(dive_id, species_id, count)
- UIState(mode, tier, filters, lastVisitedIDs)

Repositories:
- DiveRepository, SiteRepository, SpeciesRepository, SightingRepository, ListStateRepository, UIStateRepository

SiteRepository additions:
- fetchInBounds(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) → [DiveSite] for viewport‑bounded map queries

### SpeciesRepository

- search(query: String) → [Species]
- popular(limit: Int, region?: Region) → [Species] based on `COUNT(sightings)`

### WizardSaver

1. Begin transaction
2. Insert Dive row
3. Insert Sighting rows for selected species (with counts)
4. Upsert ListState for site (visited and/or wishlist toggle)
5. Commit; post notifications: `DiveListDidChange`, `MapStatsDidChange`, `WildlifeCountsDidChange`

All operations are idempotent and crash‑safe; partial failures roll back.

## UI Patterns

### Underwater Theme (Design System)
- Implemented in `UmiDesignSystem/Underwater/UnderwaterTheme.swift`
- Layers: MeshGradient ocean backdrop, Canvas caustics overlay, subtle bubble particles
- Helpers: `wateryCardStyle()` and `wateryTransition()` for glassy UI and smooth transitions
- Feature flag: `AppState.underwaterThemeEnabled` (default true)
- Logging: os.Logger hooks for theme start and seeding completion

### Site Details Card (Grand‑Bazaar style)

- Hero image header with overlay title
- Quick‑facts chips: Max depth · Avg temp · Visibility · Type
- Description and difficulty strip
- Primary CTA: Log here (My Map) or Add to Wishlist (Explore)
- Secondary CTA reversed depending on mode

### Logging Wizard

- Step 1: Site & Time
- Step 2: Depth & Duration (fast‑path save unlocked here)
- Step 3: Air & Conditions
- Step 4: Wildlife & Notes
- Review bar: “12m · 46m · 200→60” style summary + Save
- Validation gating between steps; numeric conversions performed in view‑models to avoid SwiftUI optional‑binding crashes

## Sync & Security

- Local‑first writes; background CloudKit sync when enabled
- SQLCipher encryption with Keychain‑stored keys
- Notes and other sensitive fields additionally encrypted client‑side before CloudKit

## Performance

- WAL mode, prepared statements, and batch inserts
- FTS5 indexes for site/species search
### Map: viewport‑bounded queries (SiteRepository.fetchInBounds), pin clustering, and lazy sheet content

- MapKit path (current default):
  - Stable clustering via MKMapView with clusteringIdentifier; cluster tap zooms into members; annotation updates are diffed to prevent jitter.
- MapLibre path (optional):
  - New DiveMap module using MapLibre Native. Minimal v8 style (dive_light.json) + runtime GeoJSON sources (sites, shops) with clustering layers and counts. Selection halo prepared; custom Metal water layer planned.

## Telemetry (privacy‑preserving)

Events: mode/tier/filter selections, pin→sheet opens, Log CTA CTR, wizard step drop‑offs, backfill timings, wildlife add events. All aggregated; no user identifiers.

## Testing

- Unit: migrations, repositories, WizardSaver, species search
- UI: map → sheet → wizard happy paths, offline scenarios
- Performance: write latency, search response, cold start

---

Last Updated: October 2025
