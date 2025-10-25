# 🌊 UmiLog — iOS Dive Log App (Explore → Plan → Dive → Relive)

> An image-first dive app that transforms how divers explore, plan trips, log dives offline, and relive underwater memories. Built on area-first navigation, contextual logging, and the underwater theme.

## 🎯 North Star & Jobs to be Done

**North Star**: Explore → Plan → Dive → Relive

Divers need to:
1. **Explore**: Visually scan and discover dive areas and sites by season/conditions
2. **Plan**: Safely pick suitable sites, save favorites, and download for offline access
3. **Dive**: Start logging instantly when near a known site, offline
4. **Relive**: Browse a beautiful timeline of logged dives with imagery and wildlife memories

UmiLog (海ログ – "sea log") serves all four by being area-first, image-forward, offline-first, and contextually aware.

## ✨ 2025 Refactor Status

### Completed Infrastructure ✅
- [x] Optimized dataset seeding (1,120 sites, 1.34ms load, 100% data quality)
- [x] Viewport-driven queries; debounce and bottom-sheet "in view" counts
- [x] Underwater Theme baseline (glassy cards, watery transitions, subtle overlays)
- [x] 4-step Logging Wizard (fast-path save after Step 2)
- [x] Species catalog + sightings; WizardSaver transactionally persists data
- [x] MapLibre as default map engine (MapKit fallback for compatibility)

### Current Phase: Design Refactor (In Progress)
Replacing map-first + My Map/Explore with **area-first + Discover/In-Area + My Dive Sites**.
See [TODO.md](TODO.md) for detailed Phases 1–8 breakdown.

## 🧭 Information Architecture

**Tabs**: Map · History · Log · Wildlife · Profile

**Scopes & Tiers**:
- **Discover** (default in Map tab): Shows **Areas in view**; narrow by chips (Near me, Beginner, Wrecks, Big animals, Season, Entry, Depth, Current, Viz)
- **In-Area**: Tapping an Area shows **Sites in view**; Back to Areas pill to return
- **My Dive Sites** (scope in Map tab): Timeline | Saved | Planned (image-first, no separate History tab)
- Tiering: **Regions → Areas → Sites** (with bottom sheets snapping at 24% / 58% / 92%)

**Top Overlays** (Map tab):
- One **Search pill** (query areas and sites)
- One **Filters & Layers icon** (opens modal with two tabs: Filters and Dive Lens)
- **Chips row** visible only in Discover scope

**Sheet Headers**:
- Areas: "Discover · Areas in view: N · Sort ▾ [Follow map ⌖]"
- In-Area: "AreaName · Sites in view: M · Sort ▾ [Follow map ⌖]"
- Counts are tappable (zoom-to-fit); Follow-map toggles list↔viewport sync

## 🇦 Cards & Contextual Logging

**Area Card** (16:9 image):
- Full-width hero image with title overlay
- Subline: country, site count, status pill (Logged/Saved/Planned)
- Secondary: best months · visibility · temperature
- Utility bar (bottom-right): Save · Download · Plan
- Tap card → **Enter Area** (zoom-to-bounds, show sites, hide area pins)

**Site Card** (3:2 image):
- Image + title, locality, difficulty · depth · viz/temp tags, species dots
- Tap card → **Open Site** (show detail, Start a dive CTA)
- Swipe right → **Quick Log** (fast-path to Wizard)
- Trailing overflow → Save · Directions

**Contextual Logging**:
- **Start a dive** button appears when within ~150m of a known site in the active area
- Remove per-card Log buttons; promote via Start a dive CTA on site detail
- **Quick Log** via site-card swipe (start Wizard mid-card)
- **4-step Wizard**: Site & Time → Depth & Duration (fast-path save) → Air & Conditions → Wildlife & Notes

## 🌋 State Signposting & Underwater Theme

**In-Area State**:
- "Back to Areas" pill appears under overlays when in an area
- Area pins hidden; only sites for the active area render
- Back tap or pill restores previous camera and area pins

**Underwater Theme**:
- **Dark-first**: Deep blue water, muted land, subdued labels
- **Action blues**: Primary actions (buttons, active chips) in bright ocean blue
- **Status colors**: Teal for "Logged"; Amber for "Planned"
- **AA contrast**: Scrims over imagery; ensure all text readable
- **MapLibre style alignment**: Water/land/labels/pins rendered in underwater palette
- **Glassy UI**: `.wateryCardStyle()` ultraThinMaterial with subtle highlight stroke
- **Smooth transitions**: `.wateryTransition()` for push/pop animations

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

## 🞠 Pins & Map Rendering

**Area Pins**:
- Capsule rings with label "Name · count"
- Color by status: Logged (teal), Saved (blue), Planned (amber)
- Subtle glow and pulse on select; grow when zoomed

**Site Pins**:
- Small circles colored by difficulty (blue beginner, orange intermediate, red advanced)
- Tiny entry glyph overlay (shore, boat, liveaboard)
- Render only inside an active area (hidden in Discover scope)

**Map Engine**:
- MapLibre Native (DiveMap) with GeoJSON runtime sources and clustering
- Fallback: MapKit (NewMapView) for compatibility
- Style: `Resources/Maps/umilog_underwater.json` (v8 minimal, underwater palette)

## 📊 History & Profile (My Dive Sites)

**Timeline** (was History):
- Image-forward log cards; tap → open full log
- Share and quick actions (Duplicate, PDF, Sign-off)
- Multi-select toolbar for bulk export/send

**Saved & Planned**:
- Same image-first cards as Discover/In-Area
- Tap → enter area or open site
- Quick manage status

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

## 🗣️ Roadmap

**Current Sprint**: Design Refactor (Phases 1–8)
- Phase 1: Explore (Discover scope, chips, Search pill, Filters & Layers modal)
- Phase 2: Dive (Contextual Start a dive, Quick Log via swipe)
- Phase 3: Plan (Card utilities, offline packs, date assignment)
- Phase 4: Relive (My Dive Sites scope with Timeline, Saved, Planned)
- Phase 5: Search & Dive Lens (Grouped results, wildlife filtering)
- Phase 6: Underwater Theme & Pins (Palette alignment, pin styles)
- Phase 7: Performance & Accessibility (BlurHash, Reduce Motion, VoiceOver)
- Phase 8: Guidance & States (Coach marks, empty states)

See [TODO.md](TODO.md) and [ARCHITECTURE.md](ARCHITECTURE.md) for detailed breakdown.

**Future Sprints**:
- World-scale expansion (10,000+ sites)
- Backend service (FastAPI/Cloudflare Workers)
- Automated data pipeline (Wikidata + OSM weekly scrapes)
- Community contributions + QA workflows

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## 📄 License

MIT License – see [LICENSE](LICENSE).

## 🙏 Acknowledgments

OpenDiveSites, FishBase, SeaLifeBase, SF Symbols.

---

UmiLog — log dives before the rinse bucket drains 🤿
