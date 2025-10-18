# 📋 UmiLog TODO (Map‑first Migration)

This list tracks the 2025 refactor to a map‑first IA with a 4‑step logging wizard and updated History/Wildlife/Profile.

## ✅ Completed
- Replace long form with 4‑step Logging Wizard (Steps 1–4)
- Add SpeciesRepository (popular + search)
- Extend LogDraft with selected species + notes
- Implement WizardSaver (Dive + Sighting + ListState + notifications)
- Center plus tab: removed floating overlay, middle tab now triggers wizard and returns to Map
- Explore mode styling: distinct tint, chips use mode color
- Haptics on region/area/site taps; subtle animations for tier transitions
- Status chips (Visited/Wishlist/Planned) now navigate to Sites tier and clear region/area filters
- Toolbar wired: search sheet + filters sheet
- Fix numeric text field bindings by converting to String inputs with safe parsing
- Build succeeded on iPhone 17 Pro simulator
- Site details card updated to the "Grand Bazaar" pattern
- Map clustering compile fix: added MapClusterView.swift to the FeatureMap target via XcodeGen and corrected pin id extraction in didSelect; FeatureMap now builds cleanly
- Viewport‑based site loading via `SiteRepository.fetchInBounds`; MapClusterView propagates `regionDidChange` → ViewModel refresh
- MapLibre is the default map engine (DiveMap); MapKit retained as fallback
- **Database seeder implementation**: All JSON files loaded on first launch
- **24 dive sites** across Red Sea, Caribbean, Southeast Asia, Pacific, Mediterranean
- **35 wildlife species** with scientific names and categories
- **3 mock dive logs** with instructor sign-offs
- **19 wildlife sightings** linked to dives and species

## 🚧 In Progress / Next Up

### 🎯 Current Sprint: Curated Site Expansion (7–10 days)
**Goal**: Expand from 24 → 100–150 world-class dive sites with comprehensive metadata, tags, and filtering capabilities

**Priority Tasks**:
- [ ] **Schema v3**: Add tags field to DiveSite; create site_tags, FTS5, indexes (Days 1–2)
- [ ] **Schema v4**: Add site_facets, site_media, dive_shops, site_shops, site_filters_materialized (Day 3)
- [ ] **Scraping scripts**: Wikidata, Wikivoyage, OSM, OBIS enrichment, dedupe/validate (Day 4)
- [ ] **Data curation**: 100–150 curated sites with complete metadata across 6+ regions (Days 5–6)
  - Red Sea: 20–25 sites
  - Caribbean: 25–30 sites
  - Southeast Asia: 25–30 sites
  - Pacific: 15–20 sites
  - Mediterranean: 10–15 sites
  - Indian Ocean + Other: 13–20 sites
- [ ] **Dive logs**: Expand from 3 → 25 total (Day 7)
- [ ] **Wildlife sightings**: Expand from 19 → 60–75 total (Day 7)
- [ ] **Viewport queries**: Implement filter-aware SiteRepository APIs (Day 8)
- [ ] **Performance validation**: Cold start < 2s, viewport queries < 200ms, memory < 50MB (Day 8)
- [ ] **Documentation**: Update README, ARCHITECTURE, LEARNINGS, ASSETS with schema and pipeline (Days 9–10)

**Acceptance Criteria**:
- [ ] 100–150 curated sites with tags, facets, provenance
- [ ] v3–v4 migrations succeed without data loss
- [ ] Performance budgets met
- [ ] FTS5 search working
- [ ] All docs updated per WARP.md rules

### 📋 Backlog (Post-Sprint)
- [ ] Add UI toggle in Profile to switch Map Engine (MapKit vs MapLibre)
- [ ] Expand MapLibre style (bathymetry raster source + land/water layers)
- [ ] Add custom Metal water layer to MapLibre style (low alpha caustics)
- [ ] Replace runtime images with bundled SDF sprite once asset pipeline is ready
- [ ] Ship visual polish: Underwater theme animations/tweaks
- [ ] Add A11y labels on pins, chips, cards; ensure no overlap with home indicator
- [ ] Add small debug toggle in Profile to enable/disable UnderwaterTheme
- [ ] Enhance Step 4 summary to show species names instead of IDs
- [ ] "View in History" banner after successful save with tap‑through
- [ ] Explore gestures: double‑tap pin and swipe on card → ★ Wishlist
- [ ] History: bulk export CSV and Sign‑off (stub)
- [ ] Tag filtering UI: Multi-select chips for tags, difficulty, site type, depth ranges
- [ ] Wildlife-based filtering: Find sites with specific species
- [ ] QA acceptance checklist and in‑app instrumentation hooks

## Phased Plan

### Phase 0 – Foundations ✅
- Remove overlay nav; keep tab bar
- Apply tokens (spacing, radius, typography, colors)
- Replace country stat with summary strip

### Phase 1 – Map IA ✅ (initial pass)
- My Map/Explore segmented control + chips
- Tier tabs: Regions · Areas · Sites
- Bottom sheet + site cards + region progress
- Pin styles and legend
- Remove separate Sites tab; deep links to Map

### Phase 2 – Logging & History (active)
- [x] 4‑step wizard with validation and fast‑path save
- [x] Review bar haptics (light feedback)
- [ ] History KPI tiles, group by day
- [ ] Editable chips and multi‑select toolbar
- [ ] CSV export (initial)

### Phase 3 – Wildlife
- [x] Species search and popular list
- [x] Save sightings with dives
- [ ] Wildlife tab filters and quick add

### Phase 4 – Backfill & Polish
- [ ] Backfill v1 (date range → per‑day site pick → essentials)
- [ ] Explore sorters: Nearby/Popular/Beginner
- [x] Underwater theme: glossy watery transitions and overlays
- [x] Animations + haptics baseline
- [ ] A11y labels on pins, chips, cards; ensure no overlap with home indicator
- [ ] Empty states

## Data & Models

### Current State ✅
- [x] Region → Area → Site hierarchy (seed JSON) - 24 sites across 5 regions
- [x] Wildlife species catalog (35 real marine species)
- [x] Mock dive logs (3 completed dives with sightings)
- [x] Dive, ListState, Species, Sighting models
- [x] UIState persisted for mode/tier/filters

### Sprint Goals 🎯
- [ ] DiveSite with tags: [String]
- [ ] site_tags table for fast filtering
- [ ] site_facets (entry modes, features, visibility, temp, seasonality)
- [ ] site_media (licensed photos with attribution)
- [ ] dive_shops + site_shops (nearby services)
- [ ] site_filters_materialized (precomputed facet counts)
- [ ] FTS5 full-text search across sites
- [ ] 100–150 curated sites with comprehensive metadata
- [ ] 25 dive logs + 60–75 sightings

### Future Roadmap 🚀
- [ ] World-scale expansion: 10,000+ sites
- [ ] Backend service (FastAPI/Cloudflare Workers)
- [ ] PostgreSQL + PostGIS for spatial queries
- [ ] Automated weekly scrapes (Wikidata, OSM, OBIS)
- [ ] CDN-served JSON tiles for incremental updates
- [ ] H3 spatial indexing for tile-based loading
- [ ] MEOW ecoregion tagging
- [ ] MPA/reef overlay integration
- [ ] Community contributions + QA workflows

## Metrics & QA Targets
- My Map vs Explore recognition ≥ 90%
- Wishlist from Explore ≤ 2 taps
- Start log from site card ≤ 2 taps; essentials ≤ 30 s
- Backfill 10 dives < 8 min (seeded set)

## Testing Checklist
- Visual: watery transitions smooth (no hitching); overlays remain under content
- A11y: VoiceOver reads map tabs, chips, cards; hit targets ≥44pt
- Perf: overlays keep FPS > 55 on iPhone 12+, CPU < 25% during idle
- Unit: repositories, migrations, WizardSaver, species search
- UI: map → sheet → wizard, offline paths, wishlist gesture
- Perf: cold start < 2s; DB writes < 100ms; search < 200ms

## Documentation
- [x] README.md (map‑first overview)
- [x] ARCHITECTURE.md (modules, flows, site details card)
- [ ] TODO.md (this file)
- [x] LEARNINGS.md (latest fixes)
- [x] ASSETS.md (tokens, pins, sheets, screenshots paths)

## 🌍 World-Scale Data Expansion (Phase 2 Roadmap)

**Vision**: Scale from 150 curated sites → 10,000+ dive sites worldwide with automated pipeline

### Infrastructure Requirements
- **Backend service**: FastAPI or Cloudflare Workers REST API
- **Database**: PostgreSQL 15+ with PostGIS extension
  - Spatial indexes (GIST on geography columns)
  - Materialized views for facet aggregation
  - Full-text search (tsvector + GIN indexes)
- **Job orchestration**: GitHub Actions (weekly) or Prefect Cloud
- **Storage**: S3/GCS for seed artifacts, tile caches
- **CDN**: CloudFlare for JSON tiles and incremental diffs

### Automated Data Pipeline
1. **Weekly scrapes** (with rate limiting + politeness delays):
   - Wikidata SPARQL endpoint (dive sites, coordinates, depth)
   - OpenStreetMap Overpass API (sport=diving nodes)
   - Wikivoyage scraper (regional dive site articles)
   - OBIS aggregates (species diversity per site buffer)
   - Government/NGO open data portals (when available)

2. **Deduplication & merge**:
   - H3 spatial bucketing (resolution 9–10, ~250m cells)
   - ST_ClusterDBSCAN within buckets (250m threshold)
   - Jaro–Winkler name similarity ≥ 0.92
   - Prefer open sources over restricted data
   - Store lineage in site_source table

3. **Quality assurance**:
   - Validate: coordinates in water (not on land)
   - Sanity check: depth 5–130m, visibility 3–60m, temp 0–35°C
   - Flag outliers for manual review
   - License compliance checks per source

4. **Nightly refresh**:
   - Rebuild site_filters_materialized
   - Regenerate search indexes
   - Export regional JSON tiles for offline use
   - Generate ULID-based diffs for incremental sync

### App Integration Strategy
- **Offline-first**: Always bundle "Open Core" with 150–500 curated sites
- **Optional updates**: Monthly background sync for new tiles
- **User control**: Opt-in for large datasets, opt-out anytime
- **Performance**: Maintain cold start < 2s, queries < 200ms

### Data Licensing & Compliance
- **Open Core bundle**: CC0/CC-BY/ODbL sources only; redistributable
- **Enriched services**: Non-redistributable overlays (MPAs, reefs) served via API
- **Attribution**: Auto-generate attribution.json per source
- **Coordinate fuzzing**: For restricted sources (±500m), if needed

### Scaling Targets
- **Sites**: 10,000+ dive sites across 100+ countries
- **Species**: 500+ with regional checklists
- **Shops**: 2,000+ dive centers globally
- **Media**: 10,000+ CC-licensed images from Commons

### Timeline
- **Months 0–3**: MVP with 150 sites (current sprint)
- **Months 4–6**: Backend service + automated pipeline prototype
- **Months 7–9**: Scale to 1,000 sites with weekly scrapes
- **Months 10–12**: Scale to 10,000 sites with nightly refresh
- **Year 2+**: Community contributions, mobile data collection

### Open Questions
- H3 vs. S2 for spatial indexing?
- Export Open Core as Parquet/GeoPackage for researchers?
- Support user-contributed sites (with moderation)?
- Real-time sync vs. monthly tile updates?

---

Updated: October 2025 – Phase 1 sprint active, world-scale roadmap defined 🚀
