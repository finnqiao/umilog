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

### Schema v2 (Current) ✅
Tables:
- **sites**: id, name, location, lat, lon, region, avg_depth, max_depth, avg_temp, avg_visibility, difficulty, type, description, wishlist, visitedCount, createdAt
- **dives**: id, site_id, date, start_time, end_time, max_depth, avg_depth, bottom_time, start_pressure, end_pressure, temperature, visibility, current, conditions, notes, instructor_name, instructor_number, signed, createdAt, updatedAt
- **list_state**: site_id, state (visited|wishlist|planned)
- **species**: id, name, scientific_name, category, rarity, regions (JSON array), imageUrl
- **sightings**: id, dive_id, species_id, count, notes, createdAt
- **ui_state**: mode, tier, filters, lastVisitedIDs

### Schema v3 (Sprint) 🎯 Tags + Search
New/modified tables:
- **sites**: + tags TEXT (JSON array)
- **site_tags**: site_id, tag (normalized for filtering)
  - PRIMARY KEY (site_id, tag)
  - INDEX on tag
- **site_fts**: FTS5 virtual table (name, region, area, country, tags, description)
  - Triggers maintain sync with sites table

Indexes added:
- idx_sites_region ON sites(region)
- idx_sites_difficulty ON sites(difficulty)
- idx_sites_type ON sites(type)
- idx_sites_lat_lon ON sites(latitude, longitude)
- idx_site_tags_tag ON site_tags(tag)

### Schema v4 (Sprint) 🎯 Facets + Media
New tables:
- **site_facets**: site_id (PK), difficulty, entry_modes (JSON), notable_features (JSON), visibility_mean, temp_mean, seasonality_json, shop_count, image_asset_ids (JSON), has_current, min_depth, max_depth, is_beginner, is_advanced, updated_at
- **site_media**: id, site_id, kind (photo|video), url, width, height, license, attribution, source_url, sha256, is_redistributable
- **dive_shops**: id, name, country, region, area, lat, lon, website, phone, email, services (JSON), license, source_url
- **site_shops**: site_id, shop_id, distance_km (junction table)
- **site_filters_materialized**: region, area, facet, value, count
  - PRIMARY KEY (region, area, facet, value)
  - Precomputed for instant filter chips

### Repositories
- **DiveRepository**: CRUD + getAllDives, getDivesForSite
- **SiteRepository**: 
  - fetchInBounds(bounds, filters, limit) → [DiveSiteLite]
  - fetchDetails(siteId) → SiteDetail (with facets, media, tags)
  - fetchByTag(tag) → [DiveSiteLite]
  - searchSites(query, limit) → [DiveSiteLite] (FTS5)
  - facetCounts(region?, area?) → [MaterializedFilter]
- **SpeciesRepository**: search, popular, fetchAll
- **SightingRepository**: CRUD + fetchForDive
- **ListStateRepository**: CRUD + toggleWishlist
- **UIStateRepository**: persist/restore map state

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

### Database Optimization
- **WAL mode**: Write-ahead logging for concurrent reads
- **Prepared statements**: All queries use GRDB's type-safe query builders
- **Batch inserts**: Seed data loaded in single transaction
- **Indexes**: Spatial (lat/lon), categorical (region, difficulty, type), text (FTS5)
- **Deferred FTS**: Temporarily disable triggers during bulk load, rebuild with `INSERT INTO site_fts(site_fts) VALUES('rebuild')`

### Query Strategy
- **Viewport-first**: Always constrain by lat/lon bounding box before other filters
- **Lightweight payloads**: Map uses SiteLite (id, name, lat, lon, difficulty, type); full SiteDetail fetched on selection
- **Tag filtering**: Use site_tags EXISTS subquery (fast with index) instead of JSON LIKE
- **Facet counts**: Read from site_filters_materialized (precomputed nightly or on seed)
- **Search**: FTS5 across name/region/area/country/tags/description with relevance ranking

### Performance Budgets
- Cold start with 150 sites: **< 2s**
- Viewport query (≤50 sites): **< 200ms**
- Full site detail load: **< 100ms**
- Memory baseline: **< 50MB**
- FTS5 search: **< 100ms**

### Map Rendering
- **MapLibre** (default):
  - DiveMap module renders `umilog_min.json` style (vector tiles)
  - Runtime GeoJSON sources for sites with clustering
  - Pins react to filter state
  - Clusters zoom on tap
  - Offline fallback if tiles fail
- **MapKit** (fallback):
  - Legacy `NewMapView` wrapper for regression testing

## Telemetry (privacy‑preserving)

Events: mode/tier/filter selections, pin→sheet opens, Log CTA CTR, wizard step drop‑offs, backfill timings, wildlife add events. All aggregated; no user identifiers.

## Testing

- Unit: migrations, repositories, WizardSaver, species search
- UI: map → sheet → wizard happy paths, offline scenarios
- Performance: write latency, search response, cold start

## Site Data Pipeline (Future: World-Scale)

### Phase 2: 10,000+ Sites (6–12 months)

**Infrastructure**:
- Backend: FastAPI or Cloudflare Workers
- Database: PostgreSQL 15+ with PostGIS extension
- Jobs: GitHub Actions (weekly scrapes) or Prefect Cloud
- Storage: S3/GCS for artifacts, CDN for JSON tiles

**Automated Pipeline**:
1. **Data acquisition** (weekly):
   - Wikidata SPARQL queries (dive sites, coordinates, depth)
   - OpenStreetMap Overpass API (sport=diving nodes)
   - Wikivoyage scraper (regional dive articles)
   - OBIS API (species diversity aggregates per site buffer)
   - Government/NGO open data portals (when available)

2. **Deduplication**:
   - H3 spatial bucketing (resolution 9–10, ~250m)
   - ST_ClusterDBSCAN within buckets (250m threshold)
   - Jaro–Winkler name similarity ≥ 0.92
   - Prefer open-licensed sources; store lineage

3. **Quality assurance**:
   - Validate coordinates in water (not on land)
   - Sanity checks: depth 5–130m, visibility 3–60m, temp 0–35°C
   - Flag outliers for manual review
   - License compliance per source

4. **Materialization** (nightly):
   - Rebuild site_filters_materialized
   - Regenerate FTS indexes
   - Export regional JSON tiles
   - Generate ULID-based diffs for incremental sync

**App Integration**:
- Bundle "Open Core" with 150–500 curated sites (always offline-capable)
- Optional monthly background sync for tile updates
- User control: opt-in for large datasets
- Maintain performance budgets: cold start < 2s, queries < 200ms

**Scaling Targets**:
- 10,000+ dive sites across 100+ countries
- 500+ species with regional checklists
- 2,000+ dive centers/shops
- 10,000+ CC-licensed images from Wikimedia Commons

**Licensing**:
- Open Core: CC0/CC-BY/ODbL sources only (redistributable)
- Enriched services: Non-redistributable overlays (MPAs, reefs) via API
- Auto-generate attribution files per source

---

Last Updated: October 2025 – v3–v4 schema sprint active
