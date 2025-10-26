# 🎨 UmiLog Assets & Attributions

> Track all external assets, licenses, and attributions for legal compliance.

## 📱 App Icons & Design

### Map & Data Assets — references
- Map styles bundled:
  - `Resources/Maps/umilog_underwater.json`
  - `Resources/Maps/dive_offline.json`
  - `Resources/Maps/umilog_min.json`
- Seed tiles (preferred): `Resources/SeedData/optimized/tiles/manifest.json` and regional tiles under `Resources/SeedData/optimized/tiles/*.json`
- Legacy seed files (fallbacks used by DatabaseSeeder):
  - `Resources/SeedData/sites_seed.json`
  - `Resources/SeedData/sites_extended.json`
  - `Resources/SeedData/species_catalog.json`, `Resources/SeedData/dive_logs_mock.json`, `Resources/SeedData/sightings_mock.json`

### Design Tokens & UI Patterns (Map‑first)
- Grid: 8pt; Insets: 16pt; Min tap: 44pt
- Corner radius: 16–20
- Typography: LargeTitle 22/28, Headline 17/22, Body 15/20, Caption 13/16
- Accents: Blue = My Map; Teal = Ocean; Sand/Orange = Explore
- Pin states: Visited (filled) · Wishlist (hollow + ★) · Planned (dashed); muted gray for unowned (Explore only)
- Bottom‑sheet snaps: 24% / 58% / 92%
- Cards: `.wateryCardStyle()` glassy look with ultraThinMaterial and highlight stroke
- Transitions: `.wateryTransition()` for smooth push/pop

### Site Details Card Pattern
- Hero image header with rounded top corners
- Title + meta line (area/country)
- Quick‑facts chips: Beginner/Advanced · Max depth · Avg temp · Visibility · Type
- Primary CTA varies by mode: Log (My Map) vs ★ Wishlist (Explore)

### Screenshots & Diagrams
- Place screenshots in `docs/screens/` and reference them from README.md
- Suggested names: `map-my-map.png`, `map-explore.png`, `history.png`, `site-details.png`, `profile.png`

### App Icon
- **Source**: Custom design
- **Designer**: TBD
- **License**: Proprietary
- **Files**: `Assets.xcassets/AppIcon.appiconset/`

### Design Prototype
- **Source**: Figma design exported as React/TypeScript
- **Location**: `design/` directory
- **Framework**: React 18 + Vite + TypeScript
- **UI Components**: shadcn/ui (MIT License)
- **License**: MIT (shadcn/ui components)
- **Attribution**: https://ui.shadcn.com/
- **Figma URL**: https://www.figma.com/design/JwMxy351eNAi3eQvWX6GBA/UmiLog-Dive-Log-App
- **Usage**: Visual reference for native iOS implementation
- **Documentation**: See DESIGN.md for iOS translation guide

### SF Symbols
- **Source**: Apple SF Symbols 5.0
- **License**: Apple SDK Agreement
- **Usage**: System icons throughout app
- **Icons Used**:
  - `house.fill` - Home/Dashboard
  - `plus.circle.fill` - Log dive action
  - `clock.fill` - History/Recent dives
  - `map.fill` - Site explorer
  - `ellipsis.circle.fill` - More/Settings
  - `fish.fill` - Wildlife tracking
  - `rosette` - Certifications/Awards
  - `mappin.circle.fill` - Location markers
  - `calendar` - Date selection
  - `chart.bar.fill` - Statistics
  - `mic.fill` - Voice input
  - `qrcode` - Sign-off feature
  - `lock.fill` - Privacy/security

## 🗺️ Data Sources

### Dive Sites Database

#### Current (v1) - 24 Sites ✅
- **Files**: 
  - `Resources/SeedData/sites_seed.json` (9 core sites)
  - `Resources/SeedData/sites_extended.json` (15 additional)
- **Regions**: Red Sea (4), Caribbean (3), Southeast Asia (8), Pacific (5), Mediterranean (4)
- **Sources**: OpenDiveSites, Wikidata, Wikivoyage, manual curation
- **License**: CC BY-SA 4.0 (OpenDiveSites), CC0 (Wikidata), CC-BY-SA 3.0 (Wikivoyage)
- **Attribution**: "Dive site data from OpenDiveSites, Wikidata, and Wikivoyage contributors"
- **Size**: ~150KB uncompressed

#### Sprint Target - 100–150 Sites 🎯
- **File**: `Resources/SeedData/curated_sites.json`
- **Regional Distribution**:
  - Red Sea: 20–25 (Egypt, Sudan, Jordan, Israel)
  - Caribbean: 25–30 (Mexico, Belize, Cayman, BVI, Bahamas)
  - Southeast Asia: 25–30 (Thailand, Indonesia, Philippines, Malaysia)
  - Pacific: 15–20 (Australia GBR, Fiji, Palau, PNG, Hawaii)
  - Mediterranean: 10–15 (Malta, Greece, Croatia, France, Italy)
  - Indian Ocean + Other: 13–20 (Maldives, Japan, cenotes)
- **Sources**: 
  - Wikidata SPARQL (CC0 - Public Domain)
  - OpenStreetMap Overpass API (ODbL - Open Database License)
  - Wikivoyage (CC-BY-SA 3.0)
  - OBIS species aggregates (Various, store only derived stats)
  - Government tourism boards (CC-BY where available)
- **Fields per site**: 
  - Core: id, name, region, area, country, lat, lon, description
  - Metadata: min_depth, max_depth, avg_temp, avg_visibility, difficulty, type
  - Tags: 2–5 from controlled taxonomy (sharks, wreck, drift, etc.)
  - Facets: entry_modes, notable_features, seasonality, shop_count
  - Media: 1+ licensed images (CC-BY preferred, Wikimedia Commons)
  - Provenance: source URLs, licenses, retrieved_at
- **Size estimate**: ~800KB–1MB uncompressed

#### Future (v2) - 10,000+ Sites 🚀
- Backend-generated tiles served via CDN
- Incremental updates via ULID-based diffs
- Always offline-capable with bundled "Open Core" (150–500 sites)

### Wildlife Species

#### Current - 35 Species ✅
- **File**: `Resources/SeedData/species_catalog.json`
- **Categories**: Fish (28), Reptiles (2), Mammals (3), Invertebrates (2)
- **Rarity levels**: Common, Uncommon, Rare, VeryRare
- **Regional distribution**: Red Sea, Caribbean, Southeast Asia, Pacific, Mediterranean
- **Fields**: id, name, scientific_name, category, rarity, regions (array), imageUrl
- **Sources**:
  - FishBase.org (CC BY-NC 3.0) - used as reference, not direct scrape
  - SeaLifeBase.org (CC BY-NC 3.0) - used as reference
  - WoRMS (World Register of Marine Species) - taxonomy validation
  - Manual curation from dive guides
- **Attribution**: "Species taxonomy validated against WoRMS and FishBase"
- **Size**: ~15KB uncompressed

#### Future Expansion (Optional)
- Expand to 100–150 species with regional checklists
- OBIS aggregates for site-specific diversity hints
- Store only derived stats, not raw occurrence data

## 🛠️ Third-Party Libraries

### GRDB.swift
- **Version**: 6.24.0
- **License**: MIT
- **Copyright**: © 2015-2024 Gwendal Roué
- **Usage**: SQLite database interface
- **URL**: https://github.com/groue/GRDB.swift

### SQLCipher
- **Version**: 4.5.5
- **License**: BSD-style
- **Copyright**: © 2008-2024 Zetetic LLC
- **Usage**: Database encryption
- **URL**: https://www.zetetic.net/sqlcipher/

### ZIPFoundation
- **Version**: 0.9.18
- **License**: MIT
- **Copyright**: © 2017-2024 Thomas Zoechling
- **Usage**: Export/import compression
- **URL**: https://github.com/weichsel/ZIPFoundation

### Swift Collections
- **Version**: 1.1.0
- **License**: Apache 2.0
- **Copyright**: © Apple Inc.
- **Usage**: Data structures
- **URL**: https://github.com/apple/swift-collections

### Swift Algorithms
- **Version**: 1.2.0
- **License**: Apache 2.0
- **Copyright**: © Apple Inc.
- **Usage**: Collection algorithms
- **URL**: https://github.com/apple/swift-algorithms

## 📸 Stock Photography

### Design Prototype Images
- **Source**: Unsplash
- **License**: Unsplash License (free for commercial use)
- **Usage**: Web prototype reference images only (not in production iOS app)
- **Attribution**: "Photos from Unsplash used under Unsplash License"
- **URL**: https://unsplash.com/license
- **Location**: `design/` directory (web prototype)

### Production App Images
- **Ocean Surface**: Unsplash (Free license)
  - Photo by [Author Name]
  - URL: [unsplash.com/photos/...]
  
### Tutorial Images
- **Diver Silhouette**: Custom illustration
- **Equipment Icons**: SF Symbols + custom

## 🎵 Sound Effects

### UI Sounds
- **Bubble Sound**: freesound.org
  - License: CC0
  - File: `bubble_pop.caf`
  
- **Success Chime**: System sound
  - Source: iOS SDK

## 📝 Fonts

### System Fonts
- **SF Pro Display**: iOS system font
- **SF Pro Text**: iOS system font
- **SF Mono**: Code/numbers display

### Custom Fonts (if added)
- None currently

## 🌐 Localization

### Translations
- **English (Base)**: In-house
- **Japanese**: TBD (Post-MVP)
- **Spanish**: TBD (Post-MVP)
- **French**: TBD (Post-MVP)

## 📄 Legal Documents

### Privacy Policy
- **Author**: Legal team/template
- **Last Updated**: TBD
- **URL**: https://umilog.app/privacy

### Terms of Service
- **Author**: Legal team/template
- **Last Updated**: TBD
- **URL**: https://umilog.app/terms

### EULA
- **Type**: Standard Apple EULA
- **Customizations**: None

## 🏷️ Attribution Requirements

### In-App Attribution Screen
Required attributions to display:
```
Data Sources:
• Dive sites from OpenDiveSites (CC BY-SA 4.0)
• Fish data from FishBase.org (CC BY-NC 3.0)
• Marine life from SeaLifeBase.org (CC BY-NC 3.0)

Open Source Libraries:
• GRDB.swift (MIT License)
• SQLCipher (BSD License)
• ZIPFoundation (MIT License)
• Swift Collections & Algorithms (Apache 2.0)

Design:
• UI components from shadcn/ui (MIT License)
• Design prototype created with Figma

Icons & Graphics:
• SF Symbols by Apple Inc.
• Ocean photography from Unsplash contributors
```

### App Store Description
Include: "Contains data from OpenDiveSites, FishBase, and SeaLifeBase"

## 🎁 Credits & Thanks

### Beta Testers
- (To be added)

### Contributors
- (To be added)

### Special Thanks
- Dive community forums for research insights
- ScubaBoard members for feature feedback
- Reddit r/scuba for pain point validation

## 📊 Asset Optimization

### Image Compression
- JPEGs: 85% quality for photos
- PNGs: Optimized with pngcrush
- Size limit: 500KB per image

### Data Files
- JSON: Minified for production
- Compression: gzip for seed data
- Chunking: Species by region (~3MB each)

## 🏷️ Tag Taxonomy & Facets

### Controlled Tag Vocabulary
To ensure consistent filtering and search, all site tags must come from this controlled vocabulary:

#### Wildlife Tags
Sharks, rays, turtles, dolphins, whales, whale-sharks, mantas, hammerheads, octopus, nudibranchs, macro, pelagics, reef-fish, schools

#### Feature Tags  
Wreck, reef, wall, drift, cave, cavern, cenote, pinnacle, arch, chimney, canyon, sinkhole, blue-hole, kelp, seagrass

#### Condition Tags
Current, deep, shallow, night, technical, cold, warm, clear, murky, surge, thermocline

#### Activity Tags
Photography, penetration, snorkeling, shore-entry, boat-only, liveaboard, freediving

#### Characteristic Tags
Beginner-friendly, advanced-only, iconic, remote, seasonal, protected, training, certification

### Site Facets (Schema v4)
Precomputed attributes for instant filtering:
- **difficulty**: beginner | intermediate | advanced
- **entry_modes**: ["boat", "shore", "liveaboard"]
- **notable_features**: subset of feature tags
- **visibility_mean**: meters (e.g., 25.0)
- **temp_mean**: Celsius (e.g., 27.0)
- **seasonality_json**: {"peakMonths": ["Mar", "Apr", "May"]}
- **has_current**: boolean
- **min_depth** / **max_depth**: meters
- **shop_count**: number of nearby dive centers
- **is_beginner** / **is_advanced**: boolean hints for badges

### Materialized Filters
Precomputed counts for filter chips (stored in site_filters_materialized):
- By region: "Red Sea: Beginner (12), Wreck (8), Sharks (15)"
- By area: "Sharm el-Sheikh: Drift (5), Deep (3)"
- Global: "All Sites: Reef (45), Cave (12), Liveaboard (8)"

## 📂 Seed Data Files

### Current Files (v1)
- `sites_seed.json` - 9 core sites
- `sites_extended.json` - 15 additional sites  
- `sites_extended2.json` - potential expansion (not yet loaded)
- `sites_wikidata.json` - scraped from Wikidata (not yet loaded)
- `species_catalog.json` - 35 marine species
- `dive_logs_mock.json` - 3 completed dives
- `sightings_mock.json` - 19 wildlife sightings

### Sprint Files (v2)
- `curated_sites.json` - 100–150 master list with all metadata
- `dive_logs_extended.json` - 25 total dives (adds 22)
- `sightings_extended.json` - 60–75 total sightings (adds 40–55)
- `facets/global.json` - precomputed filter counts
- `provenance/attribution.json` - per-source licensing notes
- `scraped/` - raw scraper outputs (not loaded by app)
  - `wikidata_sites.json`
  - `wikivoyage_sites.json`
  - `osm_sites.json`
  - `scraped_sites.json` (merged, pre-QA)

### Future Files (v3+)
- Regional tiles: `tiles/{region}/{area}.json`
- Incremental diffs: `diffs/{ulid}.json`
- Open Core bundle: `open_core_v{version}.json`

## 🔄 Update Log

| Date | Asset | Change | License |
|------|-------|--------|---------|
| 2025-10-12 | Underwater DS | Added UnderwaterTheme (mesh gradient, caustics, bubbles), card and transition helpers | Internal |

| Date | Asset | Change | License |
|------|-------|--------|---------|
| 2025-10-11 | Screenshots | Added site details and profile screenshots; defined docs/screens/ convention | Internal |
| 2025-10-11 | Tokens | Added map‑first tokens (pins, snaps, accents) | - |
| 2024-10-07 | Design Prototype | Added Figma web prototype (React/TypeScript) | MIT (shadcn/ui) |
| 2024-10-07 | SF Symbols | Expanded icon mappings for tab bar and features | Apple SDK |
| 2024-10-07 | DESIGN.md | Created iOS translation guide from web design | - |
| 2024-01-01 | Initial | Asset tracking started | Various |

## ⚖️ License Compliance Checklist

- [ ] All MIT licenses included in app bundle
- [ ] CC BY-SA attributions visible to users
- [ ] Apple SDK agreement compliance verified
- [ ] No GPL/LGPL dependencies
- [ ] Export compliance (encryption) documented
- [ ] Privacy policy includes data sources

## 🚫 Excluded Assets

Assets considered but not used:
- Google Maps SDK (cost + privacy concerns)
- Mapbox (subscription model)
- Firebase (privacy + offline limitations)
- Commercial dive site APIs (licensing complexity)

---

*Keep this document updated with every external resource added to the project* 📋