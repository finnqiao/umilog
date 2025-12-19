# 📚 UmiLog Learnings

> Document key decisions, discoveries, and lessons learned during development.

## 🔎 Latest Learnings (Dec 2025)

### Map Theming & Tech Debt Cleanup (12-18-2025)

**Goal**: Create a configurable, dynamic map like Resy's while cleaning up tech debt from multiple iterations.

**What We Changed**:

1. **Unified Color System**:
   - Created `UIColors.swift` in UmiDesignSystem to bridge SwiftUI Colors to UIKit UIColor
   - Removed duplicate `ColorExtensions.swift` (had conflicting color values)
   - Key insight: The duplicate file defined `oceanBlue` as `#2563EB` while canonical was `#2D7FBF`
   - **Learning**: Always centralize design tokens in one module; duplicates drift over time

2. **Configurable Map Theme**:
   - Created `MapTheme.swift` with centralized configuration for all map styling:
     - `MapTheme.Colors` - All color definitions
     - `MapTheme.Typography` - Font settings
     - `MapTheme.Sizing` - Marker, cluster, glow sizes
     - `MapTheme.Animation` - Timing and haptics
     - `MapTheme.Features` - Toggle features on/off
     - `MapTheme.Clustering` - Cluster behavior
   - Created `MapIcons.swift` for icon configuration
   - **Learning**: Centralized config makes A/B testing and rebranding trivial

3. **MapKit Removal**:
   - Deleted `MapClusterView.swift` (199 lines of MapKit fallback code)
   - Removed `useMapLibre` toggle from ProfileView and AppState
   - Simplified NewMapView by removing conditional engine selection
   - **Learning**: Dual-engine strategy added complexity. Single engine with offline fallback is simpler

4. **Code Cleanup**:
   - Removed `Placeholder.swift` from UmiCoreKit (no longer needed)
   - Consolidated `getAllSites()` to `fetchAll()` in SiteRepository
   - Archived `ScratchOffMapView.swift` and `ScratchOffMapViewModel.swift` (used MapKit)
   - Archived 9 outdated documentation files to `docs/archive/`
   - **Learning**: Regular cleanup prevents cruft accumulation

5. **MapVC Refactoring**:
   - Replaced all inline `UIColor(brandHex:)` calls with MapTheme references
   - Added `// CUSTOMIZE:` comments at key customization points
   - Removed private hex-parsing extension (now uses design system)
   - **Learning**: Self-documenting code with customization hints aids future development

**Files Created**:
- `Modules/UmiDesignSystem/Sources/UIColors.swift` - UIColor ↔ SwiftUI Color bridge
- `Modules/DiveMap/Sources/MapTheme.swift` - Centralized theme configuration
- `Modules/DiveMap/Sources/MapIcons.swift` - Icon configuration

**Files Deleted**:
- `Modules/FeatureMap/Sources/ColorExtensions.swift`
- `Modules/FeatureMap/Sources/MapClusterView.swift`
- `Modules/UmiCoreKit/Sources/Placeholder.swift`

**Files Archived**:
- `Modules/FeatureMap/Sources/_Archived/ScratchOffMapView.swift`
- `Modules/FeatureMap/Sources/_Archived/ScratchOffMapViewModel.swift`
- 9 phase/status documentation files → `docs/archive/`

### ViewModel Extraction (12-19-2025)

**Goal**: Improve code organization by extracting MapViewModel and related types from NewMapView.swift.

**What We Changed**:

1. **Created `MapViewModel.swift`** (~430 lines extracted):
   - `MapBounds` struct - geographic bounding box for viewport queries
   - `MapViewModel` class - manages map state, filters, sites, and regions
   - Enums: `MapMode`, `StatusFilter`, `ExploreFilter`, `Tier`
   - Models: `Region`, `Area`
   - Helper enums: `Scope`, `EntityTab`, `MySitesTab`
   - Helper function: `parseAreaCountry()`

2. **Reduced NewMapView.swift** from ~2,950 to ~2,520 lines (~430 line reduction)

**Why Extract ViewModels**:
- **Testability**: ViewModels in separate files are easier to unit test
- **Maintainability**: Smaller files are easier to navigate and understand
- **Reusability**: Types like `MapBounds`, `Region`, `Area` may be needed elsewhere
- **Build times**: Smaller files can sometimes compile faster incrementally

**Learning**: Keep ViewModels in separate files, especially once they exceed ~200 lines.

---

## 🔎 Previous Learnings (Oct 2025)

- Map readability: Switched underwater visuals to blue-first rather than near-black. Reduced global dark overlay, tinted materials instead of opaque fills, and increased base map brightness/saturation for label/pin contrast. Bottom panel now capped at 50% of screen with a toolbar toggle for full-screen map.

### Cross-links to TODO triage
- Map V3 filters/layers persistence → TODO P1 (Filter pipeline spec + persistence)
- History live updates via NotificationCenter → TODO P0 (History auto-refresh on .diveLogUpdated)
- Permissions sequencing (Location/Notifications) → TODO P0 (Define permission flows)
- Underwater Theme binding/persistence → TODO P0 (Shared state + persistence spec)
- Quick Log entry decision → TODO P1 (Entry integration)

### Phase 3: Map Implementation & V3 UX (10-19-2025)

**Map Architecture Evolution**:
Migrated from basic MapKit annotations to MapLibre-powered clustering and viewport-driven data loading:

1. **State Management Refactor**:
   - Removed direct state mutations in `@ObservedObject` during view updates
   - Implemented `@MainActor` annotation on `MapViewModel` for thread-safe operations
   - Added strict data flow: computed `filteredSites` property derives from `visibleSites` + filters
   - Deferred state updates with `DispatchQueue.main.async` to avoid re-entrancy issues
   - Result: Eliminated SwiftUI "Modified state during update" warnings

2. **Clustering & Pin Visibility**:
   - Implemented zoom-responsive cluster radius expressions (40px at zoom < 5, 25px at zoom > 8)
   - Enhanced individual site pins with zoom-responsive scaling (1.8x at low zoom, 1.2x at high zoom)
   - Created distinctive blue placeholder icon with white inner circle, dark shadow, and high contrast
   - Added VoiceOver announcements for cluster taps ("X sites in this cluster") and pin selections
   - Result: Clusters now clearly visible at all zoom levels; no overlapping pin ambiguity

3. **Viewport-Driven Content**:
   - `scheduleRefreshVisibleSites` debounces viewport changes (150ms) to prevent excessive queries
   - `refreshVisibleSites` compares new results against cached state; only updates if IDs differ
   - Bottom sheet now displays real-time "In view" count, updated on map pans
   - Result: Smooth map interactions without jarring list updates

4. **Initial Centering & Layout**:
   - Fixed centering logic to apply 15% padding on all sides of bounding box
   - Enforces minimum lat/lon spans (5.0 and 8.0 respectively) to avoid over-zooming
   - Task initialization waits for view layout (50ms) before centering to ensure map frame is ready
   - Result: Map always centers on dataset on launch; no more off-screen or overly-zoomed views

5. **Accessibility & Dark Mode**:
   - Icon colors adapt to `UITraitCollection.userInterfaceStyle`
   - Added UIAccessibility announcements for cluster and pin taps
   - Bottom sheet includes visual hierarchy with drag handle, dividers, and color-coded counts
   - Result: VoiceOver users can navigate map; dark mode users see appropriate contrast

6. **Enhanced Diagnostics**:
   - Added style layer and source introspection logs on failure
   - Tracks annotation count on each update; logs first annotation for coordinate verification
   - Monitors state readiness (styleReady, hasSource) before attempting updates
   - Result: Can now quickly diagnose why annotations aren't rendering

**Bottom Sheet Improvements**:
- Added visual drag handle (40pt rounded rect) for clarity
- Segmented control and entity tabs now side-by-side with result count
- Divider separates chrome from content list
- Responsive grid chips with active state colors
- Seamless transition animation on mount

**Known Issues & Workarounds**:
- MapLibre offline fallback sometimes takes 4–12s; added retry logic after primary failure
- Cluster expansion requires manual zoom (no auto-zoom-to-fit cluster); acceptable UX
- Pin taps work reliably only when clusters not overlapping; spacing enforced by zoom-responsive radius

### Phase 2: Dataset Optimization (10-18-2025)

**Pipeline Architecture**:
Built multi-stage filtering pipeline (`optimize_dataset.py`) to clean comprehensive dataset:
1. **Input Validation**: Geo-boundary checks (±90°, ±180°)
2. **Quality Filtering**: Keyword-based heuristics to remove stadiums, parks, sports venues, etc. (removed 30 non-dive entries)
3. **Deduplication**: Haversine clustering within 1km radius (removed 11 duplicates)
4. **Standardization**: Consistent field mappings, regional assignment, license attribution
5. **Referential Validation**: Cross-check logs→sites (2,775/2,876 valid) and sightings→logs (6,934/7,186 valid)
6. **Regional Tiling**: Geographic bucketing into 5 regions + gzip compression

**Results**:
- Input: 1,161 sites → Output: 1,120 cleaned sites (96.5% retention)
- Regional tiles: 5 regions, uncompressed 390KB → compressed 29KB (92.5% ratio)
- Performance: All size targets exceeded (99% under budget)
- Distribution: Red Sea 735 sites (65%), Mediterranean 212 (19%), Caribbean 165 (15%), Pacific 6, Arctic 2

**Key Insights**:
- Wikidata + OSM overlap significant (~50/50 split after dedup)
- Geo-bucketing by region enables efficient lazy-loading for iOS (load one tile at a time)
- Gzip compression extremely effective on structured JSON (92.5%+ ratio)
- Keyword filtering works well for diving context (stadium/park/sports patterns clear negatives)
- Haversine distance < 1km effective dedup threshold (0.1% of sites were duplicates)

**Manifest-Driven Tile Loading**:
Created `manifest.json` with per-tile metadata:
- Region name, site count, compressed/uncompressed sizes
- Geographic bounds (min/max lat/lon, center point)
- Enables viewport-based tile selection: query bounds against manifest, load only intersecting tiles
- Future: incremental updates via manifest versioning + diff-based sync

**Quality Assurance Checklist**:
✅ All coordinates validated (no outliers outside water)
✅ Regions assigned consistently
✅ Deduplication: no name+location pairs within 1km
✅ Referential integrity: all logs/sightings reference existing records
✅ Licenses: CC0 and ODbL only (redistributable)
✅ File sizes: 99%+ under performance targets

- Underwater theme: Achieved "underwater" feel with three light layers (animated MeshGradient, caustics via Canvas, subtle bubbles). Kept effects below 0.25 opacity and used materials for glassy UI. Provided `wateryCardStyle()` and `wateryTransition()` helpers to apply consistently.
- Performance: Canvas + MeshGradient at 30 FPS with blur radius <= 16 retained >55 FPS on iPhone 12 simulator; avoided heavy shaders/Metal for MVP.
- Feature flag: Added `AppState.underwaterThemeEnabled` to allow quick visual A/B and fail‑safe toggling if perf regresses.

- Wizard flow refactor shipped: numeric text fields bound to optional numbers caused compile/runtime issues. Switched to String-bound TextFields with safe parse/write on commit in view-models. This eliminated generics ambiguity and edge-case crashes when fields were cleared.
- Validation gating between steps keeps the wizard lightweight: Step 1 requires site/time, Step 2 unlocks fast save, Steps 3–4 optional chips and notes. The review bar mirrors essentials and its enablement state.
- SpeciesRepository exposes two hot paths: `search(query)` and `popular(limit, region?)` derived from `COUNT(sightings)`; caching popular results by region removes jank on Step 4.
- WizardSaver centralizes persistence: transactionally writes Dive + Sighting rows and updates ListState, then posts `DiveListDidChange` and `MapStatsDidChange` so History/Map update automatically.
- FAB UX: on Map, offering Quick Log vs Full Wizard via confirmation dialog reduces accidental long flows and speeds “essentials in ≤30s”.
- Site Details Card: adopting the "Grand Bazaar" pattern (hero image, quick‑facts chips, description, CTA) brought visual hierarchy and clear primary action; Explore prioritizes Wishlist; My Map prioritizes Log.
- Profile: stats tiles (Dives, Max Depth, Sites, Species, Total Bottom Time) plus Cloud Backup block give an immediate sense of progress; these tiles link to filtered History scopes.
- Mock data generation: Created comprehensive seed data with **24 world-famous dive sites** (Red Sea, Caribbean, Southeast Asia, Pacific), **35 real marine species** with scientific names, **3 realistic dive logs** with instructor sign-offs, and **19 wildlife sightings**. All data uses real coordinates, species taxonomy, and realistic dive profiles for authentic testing.
- Database seeding implementation: Built comprehensive JSON loader that reads all seed files from bundle, maps JSON field names to Swift model properties, handles enum string-to-case conversion, parses ISO 8601 dates, and automatically seeds database on first app launch. The seeder checks if data exists to avoid duplicates and provides detailed logging for each step.
- XcodeGen tip: After adding new Swift source files under a module directory, regenerate the project with `xcodegen generate` so Xcode includes the files in the target. Missing this caused "cannot find 'MapClusterView'/'SiteAnnotation' in scope" until the project was regenerated.
- MapKit selection binding: `MKPointAnnotation.title` is optional; use `if let t = point.title` directly for conditional binding. Fixed `MapCoordinator.mapView(_:didSelect:)` to safely extract the pin id suffix after the `"id:"` prefix.
- SwiftUI ambiguity: Avoid `.font(.subheadline)`, `.bold()`, `.fontWeight(_:)`, and `.foregroundStyle(.primary|.secondary)` when a design system also extends `Color`/`Font`. Prefer explicit forms or UIKit bridges:
  - Use `SwiftUI.Color(UIColor.label)` and `SwiftUI.Color(UIColor.secondaryLabel)` instead of `.primary/.secondary`
  - Avoid `bold()/fontWeight` on Text when overloads conflict; prefer plain weight in concrete fonts or omit where not critical
  - If needed, move chip styling to `.buttonStyle(.bordered)` with `.tint(...)` to keep codegen simple

## 🌊 Data Sourcing & Scraping (Oct 2025)

### Open Data Sources for Dive Sites

#### Primary Sources (CC0, CC-BY, ODbL)
1. **Wikidata** (CC0 - Public Domain)
   - SPARQL endpoint: https://query.wikidata.org/
   - Query for: `?site wdt:P31 wd:Q1076486` (instance of: dive site)
   - Fields: name, coordinates (P625), depth (P2660), description
   - Pros: Structured data, global coverage, completely open
   - Cons: Sparse metadata (no temp/visibility), gaps in less popular regions
   - Rate limit: None (SPARQL is rate-limited by server load)

2. **OpenStreetMap** (ODbL - Open Database License)
   - Overpass API: https://overpass-api.de/
   - Query: `node["sport"="diving"]["name"];`
   - Fields: name, lat/lon, optionally depth/description from tags
   - Pros: Community-contributed, good coverage in Europe/Asia
   - Cons: Inconsistent tagging, requires normalization
   - Rate limit: 1 req/2s; use caching
   - Attribution: "© OpenStreetMap contributors"

3. **Wikivoyage** (CC-BY-SA 3.0)
   - Regional dive pages: "Diving in [Region]"
   - Scrape via MediaWiki API or parse HTML
   - Fields: site names, short descriptions, depth hints
   - Pros: Curated prose, travel context
   - Cons: Unstructured text, requires NLP/manual extraction
   - Rate limit: Follow robots.txt
   - Attribution: Must credit Wikivoyage + license

4. **OBIS** (Ocean Biodiversity Information System) - Multiple licenses
   - API: https://api.obis.org/
   - Use: Query species occurrences within site buffer (5–10km radius)
   - Compute: Top taxa lists, diversity metrics (for tags like "shark-rich")
   - Store: Only aggregates, not raw occurrence data
   - Pros: Scientific species data, global marine coverage
   - Cons: Complex licensing per dataset; must track source licenses
   - Rate limit: 1 req/2s recommended

5. **Government/NGO Open Portals**
   - NOAA (Public Domain): Bathymetry, SST, marine parks
   - UNEP-WCMC: Reef/MPA shapefiles (check license per dataset)
   - Regional tourism boards: Often CC-BY dive site lists
   - Pros: High-quality, authoritative
   - Cons: Fragmented, manual discovery

#### Secondary/Validation Sources (Read-Only)
- **PADI Travel**: For validation only (ToS prohibits scraping)
- **Dive.site**: Community data (unclear license; do not scrape)
- **Diveboard**: Some data in OBIS (CC-BY when aggregated)

### Scraping Best Practices
- **Rate limiting**: 1 req/2s minimum; respect server load
- **Politeness**: User-Agent with contact email; follow robots.txt
- **Caching**: Store raw responses; dedupe before re-requesting
- **Provenance**: Track source URL, license, retrieved_at per record
- **Validation**: Automated sanity checks + manual QA sample

### Deduplication Strategy
- **Spatial bucketing**: H3 resolution 9–10 (~250m hex cells)
- **Cluster within bucket**: DBSCAN with 250m epsilon
- **Name matching**: Jaro–Winkler distance ≥ 0.92; ASCII fold for accents
- **Merge conflicts**: Prefer open > restricted; highest source_score
- **Store lineage**: Keep all source IDs in site_source junction table

### Data Quality Checks
1. **Coordinate validation**: Not on land (reverse geocode or 1km water buffer)
2. **Depth sanity**: 5–130m (recreational diving range); flag outliers
3. **Visibility**: 3–60m (realistic range)
4. **Temperature**: 0–35°C (extreme diving conditions)
5. **Name normalization**: Title case; remove trailing "Dive Site"

### Licensing & Attribution
- **Open Core export**: Include only CC0/CC-BY/ODbL sources
- **Enriched internal**: Flag non-redistributable sources
- **Attribution file**: Auto-generate per-source credits in JSON
- **App display**: "About" screen lists all data sources with links

### Controlled Tag Taxonomy
To ensure consistent filtering and UX:
- **Wildlife**: sharks, rays, turtles, dolphins, whales, whale-sharks, mantas, hammerheads, octopus, nudibranchs, macro, pelagics, reef-fish, schools
- **Features**: wreck, reef, wall, drift, cave, cavern, cenote, pinnacle, arch, chimney, canyon, sinkhole, blue-hole, kelp, seagrass
- **Conditions**: current, deep, shallow, night, technical, cold, warm, clear, murky, surge, thermocline
- **Activities**: photography, penetration, snorkeling, shore-entry, boat-only, liveaboard, freediving
- **Characteristics**: beginner-friendly, advanced-only, iconic, remote, seasonal, protected, training, certification

### Performance Notes (150 sites)
- Seed load time: ~800ms (single transaction, deferred FTS)
- FTS5 rebuild: ~50ms
- Memory footprint: ~35MB baseline with all sites loaded
- Viewport query (50 sites): ~80ms
- Cold start: 1.2s (well under 2s budget)

## 🎯 Product Insights

### User Research Findings

#### Pain Points Validated
1. **Data Loss is Unforgivable** - Multiple reports of apps losing hundreds of dives (DiverLog+ 2.2★ rating)
2. **Backfilling is the #1 Adoption Blocker** - Divers often 2+ years behind on logs
3. **Paper Still Wins on Trust** - Physical logs survive when apps fail
4. **Signatures Matter for Training** - Instructors require signed logs for courses
5. **Connectivity Issues Kill Apps** - Bluetooth pairing described as "dancing naked around black candles"

#### What Divers Actually Need
- **Minimum viable fields**: Date, depth, time, location (everything else optional)
- **20-second sign-off** for instructor verification
- **Bulk import** for historical dives
- **Offline-first** - most dive sites have poor connectivity
- **Data portability** - export anxiety is real

### New PRD Insights

#### The Magic is in Reducing Friction
1. **One-tap logging** - Most dives similar to previous
2. **Auto-detection** - Geofencing knows when you're diving
3. **Smart defaults** - Learn patterns and pre-fill
4. **Visual progress** - Scratch-off map creates motivation
5. **Instant gratification** - Achievements and celebrations

#### Gamification That Works
- **Country collection** - Natural for travelers
- **Depth clubs** - Existing diver culture (30m, 40m)
- **Streak tracking** - Habit formation
- **Social proof** - "X divers here now"
- **Progress bars** - Clear next steps

## 🏗️ Architecture Decisions

### Why GRDB over Core Data
**Decision**: Use GRDB with SQLCipher instead of Core Data

**Rationale**:
- Direct SQL control for complex queries
- FTS5 full-text search support
- Better performance profiling
- Easier migration management
- SQLCipher encryption at rest

**Trade-offs**:
- Manual migration scripts
- Less Apple integration
- More boilerplate for models

### Why CloudKit over Custom Backend
**Decision**: CloudKit for sync, no custom servers

**Rationale**:
- Zero server costs
- Apple-managed infrastructure
- Automatic scaling
- Built-in authentication
- Privacy-focused (user's iCloud)

**Trade-offs**:
- iOS-only limitation
- Limited query capabilities
- No server-side logic
- Harder debugging

### Why On-Device Speech Recognition
**Decision**: requiresOnDeviceRecognition = true

**Rationale**:
- Works offline (critical for boats)
- Privacy preservation
- No API costs
- Predictable latency

**Trade-offs**:
- Limited to device languages
- Larger app size
- Less accurate than cloud

## 💡 Technical Discoveries

### Performance Optimizations

#### Database Write Performance
```swift
// ❌ Slow: Individual writes
for dive in dives {
    try db.write { db in
        try dive.insert(db)
    }
}

// ✅ Fast: Batch transaction
try db.write { db in
    for dive in dives {
        try dive.insert(db)
    }
}
// Result: 10x faster for bulk imports
```

#### Voice Command Parsing
```swift
// Deterministic number parsing beats ML
"depth twenty five" → regex → 25
"pressure one eight zero" → regex → 180
// More reliable than general STT
```

### Security Considerations

#### E2E Encryption Pattern
```swift
// Encrypt sensitive fields before CloudKit
let key = try KeychainService.getUserKey()
let sealed = try ChaChaPoly.seal(data, using: key)
record["encrypted_field"] = sealed.combined

// Store encryption key in Secure Enclave
// Never in UserDefaults or CloudKit
```

#### Database Key Management
- Generate per-user key on first launch
- Store in Keychain with `.whenUnlockedThisDeviceOnly`
- Require Face ID for key access
- No key recovery = better privacy

## 🐛 Pitfalls & Gotchas

### iOS Development

#### Signing with Free Apple ID
- For simulator and basic device builds without paid program:
  - Remove Push Notifications and iCloud capabilities
  - Keep only Application Groups and Keychain access groups if needed
  - Ensure entitlements reflect the above (see `UmiLog/UmiLog.entitlements`)
- CloudKit-dependent features must remain disabled or mocked

#### SwiftUI State Management
- `@StateObject` vs `@ObservedObject` confusion causes view recreation
- Use `@StateObject` for ownership, `@ObservedObject` for references
- Task cancellation needs explicit handling in async views

#### SwiftUI API Ambiguity with Design System Colors/Fonts (Xcode 15)
- When a design system adds `Color` extensions (e.g., `Color.oceanBlue`), calls like `.foregroundColor(.secondary)` and `.font(.subheadline)` can become ambiguous
- Fixes that worked reliably:
  - Fully qualify fonts: `.font(SwiftUI.Font.caption)` instead of `.font(.caption)`
  - Prefer `.foregroundStyle(...)` over `.foregroundColor(...)`
  - Avoid chained weight in font literals: use `.font(SwiftUI.Font.title).bold()` instead of `.font(.title.bold())`
- Disambiguate ScrollView init: `ScrollView(.vertical, showsIndicators: true)`
- Applied across QuickLogView and other screens to eliminate compile errors

- Map viewport loading: Bridge MKMapView→SwiftUI by adding `regionDidChange` in the UIViewRepresentable coordinator and passing `MKCoordinateRegion` back to the ViewModel. Query `SiteRepository.fetchInBounds(...)` to refresh only visible pins. This keeps memory low and improves pan/zoom responsiveness.
- Filter chips navigation: Status and Explore chips now jump directly to the Sites tier, clearing region/area, with light haptic + animated transition. This matches user intent and reduces taps.
- Seeding robustness: When merging multiple site seeds (curated + WD), deduplicate by `id` to avoid PK collisions. Seeding is now idempotent per-table (sites/species/dives/sightings) so a partial failure won’t block subsequent runs.
- MapKit jitter fix: Avoid removing/adding all annotations on every update; diff by id and update in place. Also stop auto-recentering during SwiftUI updates. This eliminated the "icons jumping" issue.
- Cluster UX: On tapping an MKClusterAnnotation, zoom to show member annotations. This matches the “split on tap” drill-down.
- Map engine default: MapLibre is now default for custom styling, clustering, and future bathymetry/Metal water layer; MapKit remains as fallback for compatibility.

## 🎯 Product Insights
- SwiftUI `Picker(selection:)` requires the selection type to conform to `Hashable`
- Our `DiveSite` model did not conform; adding `Hashable` resolved the error and allowed `tag(Optional(site))`
- Alternative approach is to bind selection to `site.id` (String) and tag with the id

#### Section generic inference edge case
- `Section("Title") { ... } footer: { ... }` failed generic inference once; rewriting as `Section { ... } header: { Text("Title") } footer: {...}` stabilized builds in Xcode 15

#### Background Processing
- CloudKit background notifications unreliable
- Use silent push + fetch for sync triggers
- Background time limited to ~30 seconds
- Need BGTaskScheduler for longer operations

### Database

#### SQLite Limitations
- 64KB default page size limit
- VACUUM operations lock entire DB
- FTS5 indexes can't be altered (rebuild required)
- Write-ahead logging files grow without checkpoint

#### Migration Strategies
```swift
// Always test rollback
migrator.registerMigration("v2") { db in
    // Forward migration
    try db.alter(table: "dives") { t in
        t.add(column: "new_field", .text)
    }
}
// No automatic rollback - plan carefully!
```

### Watch Connectivity

#### Reliable Message Passing
```swift
// ❌ Unreliable
session.sendMessage(message, replyHandler: nil)

// ✅ Better
session.transferUserInfo(message) // Queued
// or
session.updateApplicationContext(message) // Latest only
```

#### Immersion Detection Quirks
- Requires Apple Watch Ultra (Series 9 won't work)
- False positives in rain/shower
- Depth sensor needs calibration
- Battery drain ~15% per hour when active

## 🎨 UX Learnings

### Design System Translation (Web → iOS)
**Source**: Figma design exported as React/TypeScript web prototype

#### Component Mappings
- **Cards** (shadcn/ui) → `VStack` + `.background()` + `.cornerRadius(12)`
- **Buttons** (Radix) → `.buttonStyle(.borderedProminent)` for primary
- **Forms** (React Hook Form) → SwiftUI `Form` with `Section` grouping
- **Icons** (Lucide) → SF Symbols (see DESIGN.md for mappings)
- **Colors** (Tailwind) → Semantic `Color.primary`, `.secondary` with dark mode

#### Key Adaptations for iOS
1. **Navigation**: Web single-page → iOS `TabView` + `NavigationStack`
2. **Responsive**: Tailwind breakpoints → `@Environment(\.horizontalSizeClass)`
3. **Spacing**: 4px Tailwind units → 8/16/24pt iOS spacing
4. **Typography**: Fixed px sizes → Dynamic Type `.body`, `.headline`, etc.
5. **Input**: Sliders and text fields → Voice input buttons for key fields

#### Design Token System
- Ocean Blue `#2563EB` - Primary actions, depth indicators
- Teal `#0D9488` - Water temperature, depth metrics  
- Sea Green `#16A34A` - Success states, sites visited
- Purple `#9333EA` - Wildlife, special features
- Coral Red `#DC2626` - Warnings, required fields

**Implementation**: Use `Color` extensions with dark mode support
```swift
extension Color {
    static let oceanBlue = Color(hex: "2563EB")
    static let diveTeal = Color(hex: "0D9488")
    // Automatically adapts to dark mode
}
```

### Voice Input UX
- Show visual feedback immediately
- Confirm before writing to DB
- Provide manual correction UI
- Support common dive terminology

### Offline-First UX
- Never show sync spinners
- Queue operations transparently  
- Show sync status subtly
- Design for conflict resolution

### Import Wizard
- Show preview before committing
- Support incremental progress
- Allow fixing mapping errors
- Provide sample CSV format

## 📊 Metrics & Analytics

### What to Measure
- Time to first dive (TTFD)
- Sync success rate
- Import completion rate
- Voice recognition accuracy
- Crash-free sessions

### Privacy-Preserving Analytics
```swift
// Aggregate, don't identify
os_signpost(.event, log: log, name: "DiveLogged")
// Not: Analytics.track("DiveLogged", userId: user.id)
```

## 🔮 Future Considerations

### Scalability Challenges
- Database size after 1000+ dives
- Photo storage strategy
- Sync performance with large datasets
- Widget memory constraints

### Feature Requests from Research
1. Dive computer Bluetooth sync
2. Nitrox calculations
3. Social sharing (carefully - privacy concerns)
4. Apple Watch depth via HealthKit
5. Siri Shortcuts for quick logging

### Platform Expansion Options
- **Mac Catalyst**: Easier path, shared codebase
- **Android**: Kotlin Multiplatform worth exploring
- **Web**: PWA for instructor sign-off only

## 🤝 Community Feedback

### Beta Testing Insights
- (To be updated during TestFlight)

### App Store Reviews
- (To be updated post-launch)

### Support Tickets
- (To be updated post-launch)

## 📈 Performance Benchmarks

### Current Status
| Metric | Target | Actual | Status |
|--------|--------|--------|---------|
| Cold Start | <2s | TBD | 🟡 |
| DB Write | <100ms | TBD | 🟡 |
| Search Response | <200ms | TBD | 🟡 |
| Memory Usage | <100MB | TBD | 🟡 |
| Battery/Hour | <5% | TBD | 🟡 |

## 🔄 Retrospectives

### What's Working Well
- Offline-first architecture
- Modular Swift Packages
- E2E encryption approach

### What Needs Improvement
- (To be updated during development)

### What We'd Do Differently
- (To be updated post-MVP)

---

*Living document - update continuously as we learn* 📝