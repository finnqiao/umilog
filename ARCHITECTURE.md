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

### Current Navigation & Modules (2025-10)

- App shell and tabs: `UmiLog/UmiLogApp.swift` (UnderwaterThemeView wrapper; center tab presents LiveLogWizardView)
- Map & sheets: `Modules/FeatureMap/Sources/NewMapView.swift`, `Modules/FeatureMap/Sources/SiteDetailSheet.swift`, `Modules/FeatureMap/Sources/SearchSheet.swift`, `Modules/FeatureMap/Sources/FilterSheet.swift`
- Map engine: MapLibre wrapper `Modules/DiveMap/Sources/*` (MapKit fallback removed Dec 2025)
- Map theming: `Modules/DiveMap/Sources/MapTheme.swift`, `Modules/DiveMap/Sources/MapIcons.swift`
- History: `Modules/FeatureHistory/Sources/*`
- Logging: `Modules/FeatureLiveLog/Sources/LiveLogWizardView.swift`, `Modules/FeatureLiveLog/Sources/QuickLogView.swift`
- Wildlife: `Modules/FeatureMap/Sources/WildlifeView.swift`
- Profile: `Modules/FeatureMap/Sources/ProfileView.swift`
- Location/Geofencing: `Modules/UmiLocationKit/Sources/LocationService.swift`, `Modules/UmiLocationKit/Sources/GeofenceManager.swift`
- Data layer: `Modules/UmiDB/Sources/*` (migrations, repositories, seeder)

### Map Styles & Seed Assets

- Map styles: `Resources/Maps/umilog_underwater.json`, `Resources/Maps/dive_offline.json`, `Resources/Maps/umilog_min.json`
- Seed tiles (preferred): `Resources/SeedData/optimized/tiles/manifest.json` and regional tiles (`*.json`)
- Legacy seeds (fallback): `Resources/SeedData/sites_seed.json`, `Resources/SeedData/sites_extended.json`, etc.

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

### Seed Data Pipeline (v1.0) ✅ PRODUCTION READY

**Dataset Overview:**
- **Sites:** 1,120 (cleaned from 1,161 sources)
- **Dive Logs:** 2,775 (validated)
- **Wildlife Sightings:** 6,934 (validated)
- **Total Entities:** 10,829
- **Data Quality:** 100% (zero invalid coordinates, all licenses redistributable)

**Regional Distribution:**
- Red Sea & Indian Ocean: 735 sites (65.6%)
- Mediterranean: 212 sites (18.9%)
- Caribbean & Atlantic: 165 sites (14.7%)
- Australia & Pacific Islands: 6 sites (0.5%)
- North Atlantic & Arctic: 2 sites (0.2%)

**Sources:**
- Wikidata SPARQL API (50%, CC0 license)
- OpenStreetMap Overpass API (50%, ODbL license)
- All data filtered for dive relevance (removed 41 non-dive locations)
- All referential integrity validated

**Optimization:**
- Regional tile-based architecture: 5 JSON tiles + manifest
- Compression: 390 KB → 29 KB (92.5% ratio with gzip)
- Load time: 1.34ms (1,492x faster than 2s cold-start target)
- Memory: 0.32MB (312x under 100MB budget)
- Throughput: 770K sites/sec JSON parsing

**Location:** `Resources/SeedData/optimized/tiles/`
- `manifest.json` - Tile index with geographic bounds
- Regional tiles: australia-pacific-islands.json, caribbean-atlantic.json, mediterranean.json, north-atlantic-arctic.json, red-sea-indian-ocean.json
- Legacy fallback: sites_seed.json, sites_extended.json (for backward compatibility)

**Seeding Strategy:**
1. iOS app startup calls `DatabaseSeeder.seedIfNeeded()`
2. Attempts to load optimized regional tiles (Priority 1)
3. Fallback to legacy multi-file loading if tiles unavailable (Priority 2)
4. Single transaction for all inserts (crash-safe)
5. Idempotent: safe to re-run if already seeded

**Documentation:**
- DATASET_MANIFEST.md - Comprehensive dataset spec
- SEEDING_QUICKREF.md - Quick reference for developers
- PHASE_2_SUMMARY.md - Phase 2 completion details

---

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

### FTS5 Search Strategy

**Virtual Table**: `sites_fts` (FTS5)
- Indexed columns: name, region, location, tags, description
- Synchronization: Manual rebuild during seeding via `INSERT INTO sites_fts(sites_fts) VALUES('rebuild')`
- Triggers deferred during bulk import for performance

**Query Optimization**:
1. **Weighted Ranking**: BM25-based scoring with column weights
   - name:3 (exact matches prioritized)
   - region:2
   - tags:2 (user-facing facets)
   - location:1 (geographic context)
   - description:1 (full-text fallback)
2. **Prefix Matching**: Support `query*` syntax for autocomplete (e.g., "wreck*" matches "wreck" and "wreckage")
3. **Result Ranking**: `ORDER BY rank` (FTS5 BM25 rank) then by name (alphabetical tie-breaking)

**Query Methods in SiteRepository**:
- `searchFTS(query, limit)` → [SiteLite]: Full FTS5 search with ranking
- `searchPrefix(prefix, limit)` → [SiteLite]: Autocomplete using prefix:* syntax (future optimization)

**Performance**:
- FTS5 search: < 100ms for 500+ sites
- Prefix queries: < 50ms (subset of FTS5)
- Index size: ~15% of database size (acceptable trade-off)

### Performance Budgets
- Cold start with 150 sites: **< 2s**
- Viewport query (≤50 sites): **< 200ms**
- Full site detail load: **< 100ms**
- Memory baseline: **< 50MB**
- FTS5 search: **< 100ms**

### Map Rendering
- **MapLibre** (default):
  - DiveMap module renders `umilog_underwater.json` style (raster base + overlays)
  - Blue-forward palette for water/land with higher brightness and saturation for text/pin contrast
  - Runtime GeoJSON sources for sites with clustering
  - Pins react to filter state
  - Clusters zoom on tap
  - Offline fallback if tiles fail
- **MapKit** (fallback):
  - Legacy `NewMapView` wrapper for regression testing

### Map Chrome
- Top pill: Search + Filters + Layers
- Bottom panel: capped at max 50% of viewport; rounded, tinted material background for contrast over imagery
- Full-screen toggle in toolbar to hide the bottom panel for exploration

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
