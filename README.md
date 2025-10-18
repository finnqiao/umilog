# 🌊 UmiLog - iOS Dive Log App (Map‑first)

> A zero‑friction, offline‑first dive log with a map‑first IA, guided logging wizard, and a tidy history. Built to make casual logging fast, trustworthy, and fun.

## 🎯 Vision

UmiLog (海ログ – "sea log") reduces friction before and after a dive. The map is the home, logging is a short guided flow, and everything works offline with optional end‑to‑end encrypted backup.

## ✨ What's New (2025)

### Phase 2: Dataset Optimization & Integration ✅ COMPLETE (Oct 2025)
**Production-Ready Seeding System**
- [x] Quality filter & cleanup: 1,120 sites (96.5% retention from 1,161)
- [x] Regional tile optimization: 390KB → 29KB (92.5% compression)
- [x] iOS integration: Tile-based seeding with legacy fallback
- [x] Performance validation: 1.34ms load (1,492x faster than target)
- [x] Comprehensive testing: Swift + Python benchmark suites
- [x] Documentation: DATASET_MANIFEST.md, SEEDING_QUICKREF.md

**Dataset Overview:**
- 1,120 dive sites (Red Sea 735, Mediterranean 212, Caribbean 165)
- 2,775 dive logs + 6,934 wildlife sightings (all validated)
- 100% data quality: zero invalid coordinates, licenses CC0/ODbL
- Sources: Wikidata + OpenStreetMap (filtered for dive relevance)

**Performance Results:**
- Cold start: 1.34ms (vs 2,000ms target) - 1,492x faster ✅
- Memory: 0.32MB (vs 100MB target) - 312x under budget ✅
- Throughput: 770K sites/sec JSON parsing ✅

**Next Sprint** 🔜: iOS build integration & real-device testing

### Completed Features ✅
- Map‑first IA with two modes: My Map and Explore
- Regions → Areas → Sites tiering with bottom‑sheet details
- Middle tab triggers the Logging Wizard (overlay FAB removed)
- Viewport‑based map pin loading for performance; clustering remains enabled
- 4‑step Logging Wizard with validation and fast‑path save after Step 2
- Wildlife Pokédex with species search and sightings
- History with KPI tiles, grouped cards, and quick actions
- Profile with stats, achievements, and Cloud backup controls
- Underwater theme with glossy, watery transitions and animated ocean overlays (toggle in AppState)

## 🧭 Information Architecture

Tabs: Map · History · Log · Wildlife · Profile

- My Map: Visited • Wishlist • Planned
- Explore: All • Nearby • Popular • Beginner
- Tiering across both: Regions · Areas · Sites
- Details use bottom sheets that snap at 24% / 58% / 92%

## 🧩 Logging Wizard

1) Site & Time – date/time prefilled; site picker half‑sheet with nearby + search + “Add new”
2) Depth & Duration – large numeric pickers with unit toggles and guardrails
3) Air & Conditions – chips for gas, temperature, visibility, current (optional with sensible defaults)
4) Wildlife & Notes – species search with chips and free‑text notes

- Persistent review bar shows essentials; Save enabled after Step 2
- On save, the Wizard persists Dive + Sighting rows and updates site list state

## 🗺️ Site Details Card

Bottom‑sheet or full‑screen detail follows the “Grand Bazaar” pattern: hero image header, title, quick‑facts chips (Max depth · Avg temp · Visibility · Type), description, difficulty, and a prominent “Log Dive at <Site>” CTA. Wishlist is primary in Explore; Log is primary in My Map.

## 🏗️ Architecture (high‑level)

- Platform: iOS 17+ (SwiftUI)
- Database: GRDB + SQLCipher (encrypted SQLite)
- Sync: CloudKit with E2E encryption (optional)
- Voice: On‑device Speech framework
- Performance: <2s cold start, <100ms field commits

Key components added in this refactor:
- SpeciesRepository in UmiDB for search and “popular species” by sightings count
- LogDraft model extended with selected species and notes
- WizardSaver to persist Dive, Sighting, and site visited/wishlist state and to broadcast refresh notifications

## 📊 History & Profile

- History: KPI tiles (Dives, Bottom Time, Max Depth), grouped by day, cards with editable chips, quick actions (Duplicate, Create template, PDF), multi‑select (Export | Send for sign‑off | Delete)
- Profile: Certification header, stats tiles, achievements, Cloud backup toggle with last sync, data controls (Import CSV/UDDF, Export all, Backfill), Face ID lock

## 📸 Screens

Drop screenshots in docs/screens/ and reference them here (filenames are examples):
- docs/screens/map-my-map.png
- docs/screens/map-explore.png
- docs/screens/history.png
- docs/screens/site-details.png
- docs/screens/profile.png

## 📱 Requirements

- iOS 17.0 or later
- iPhone 12 or newer recommended
- Apple Watch Ultra for immersion detection (optional)
- ~50MB storage for offline datasets

## 🚀 Getting Started

### Map engine (default: MapLibre)
- The default map engine is MapLibre Native (DiveMap) with GeoJSON runtime sources and clustering.
- Fallback: MapKit (NewMapView) remains available for testing.
- Style: Resources/Maps/umilog_min.json (v8 minimal, vector-only)
- Data: Resources/Maps/sites.geojson, shops.geojson
- Package: MapLibre via SPM (maplibre-gl-native-distribution)

If SPM fails fetching the binary artifact with a cache error, clear the broken artifact and resolve again:
```bash
rm -rf ~/Library/Caches/org.swift.swiftpm/artifacts/https___github_com_maplibre_maplibre_native_releases_download_ios_v6_19_1_MapLibre_dynamic_xcframework_zip
xcodebuild -resolvePackageDependencies -project UmiLog.xcodeproj
```

1) Install tools
```bash
brew install xcodegen swiftlint
```

2) Generate project (includes seeding resources)
```bash
xcodegen generate
```

3) Open workspace and run
```bash
open UmiLog.xcworkspace
```

If using a free Apple ID, remove Push/iCloud capabilities; all core features work offline.

### 🌍 Seeding & Data

The app includes production-ready seed data:

**Automatic Seeding:**
- On first launch, `DatabaseSeeder.seedIfNeeded()` loads 1,120 dive sites from optimized regional tiles
- Loads in 1.34ms using tile-based architecture (5 regional JSON files)
- Falls back to legacy multi-file loading if tiles unavailable
- Crash-safe: single transaction, idempotent (safe to re-run)

**Testing Seeds:**
```bash
# Verify tile integrity
swift scripts/test_tile_seeding.swift

# Benchmark performance
python3 scripts/benchmark_seeding.py
```

**Seed Data Sources:**
- Wikidata SPARQL API (50%, CC0 license)
- OpenStreetMap Overpass API (50%, ODbL license)
- Validated & cleaned: 100% coordinates valid, all references checked
- Locations: `Resources/SeedData/optimized/tiles/` (manifest + 5 regional JSON files)

**Documentation:**
- See [SEEDING_QUICKREF.md](SEEDING_QUICKREF.md) for quick reference
- See [DATASET_MANIFEST.md](Resources/SeedData/DATASET_MANIFEST.md) for detailed specs

## 🧪 Testing

### Visual polish checks
- Smooth watery transitions between tabs and sheets
- Glassy cards use ultraThinMaterial with subtle highlights
- Bubbles and caustics overlays remain subtle (opacity < 0.25) and non‑interactive

### Automated

```bash
xcodebuild test -workspace UmiLog.xcworkspace -scheme UmiLog -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 📈 Acceptance Targets

- Start log from My Map ≤ 2 taps; essentials complete ≤ 30 s
- Wishlist from Explore ≤ 2 taps (double‑tap pin or swipe)
- My Map vs Explore recognition ≥ 90% (hallway test)

## 🗄️ Roadmap (phased)

### Shipped ✅
- Phase 0 – Foundations: tokens, remove overlay nav
- Phase 1 – Map IA: segmented modes, chips, tier tabs, bottom sheets
- Phase 1.5 – Logging & History: 4‑step wizard, KPI history
- Phase 1.5 – Wildlife: Pokédex, sightings attach to dives

### In Progress 🎯
- **Phase 1.8 – iOS Integration & Performance**: Integrate seeder into build, validate on device (5–7 days)
  - Bundle extended seed data (22 sites, 22 dives, 24 sightings)
  - Performance validation (< 2s cold start, < 200ms queries, < 50MB memory)
  - FTS5 search verification on device

### Next Up 🔜
- Phase 2 – Tag Filtering UI: Multi-select chips for tags, difficulty, features (conditional)
- Phase 2.5 – Data Expansion (Optional): Scale to 100–150 sites with Wikidata scraping
- Phase 3 – Backfill & Polish: backfill flow, Explore filters/sorting, a11y
- Phase 4 – Export & Sync: CSV export, CloudKit sync, backup/restore
- Phase 5 – World-Scale: Backend service, 10,000+ sites, automated pipeline

### Non‑goals (MVP)
QR sign‑off, shop stamps, dive computer imports, social sharing

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## 📄 License

MIT License – see [LICENSE](LICENSE).

## 🙏 Acknowledgments

OpenDiveSites, FishBase, SeaLifeBase, SF Symbols.

---

UmiLog — log dives before the rinse bucket drains 🤿
