# 🎨 UmiLog Assets & Attributions

> Track all external assets, licenses, and attributions for legal compliance.

## 📱 App Icons & Design

### App Icon
- **Source**: Custom design
- **Designer**: TBD
- **License**: Proprietary
- **Files**: `Assets.xcassets/AppIcon.appiconset/`

### SF Symbols
- **Source**: Apple SF Symbols 5.0
- **License**: Apple SDK Agreement
- **Usage**: System icons throughout app
- **Icons Used**:
  - `location.fill` - GPS indicators
  - `mic.fill` - Voice input
  - `map.fill` - Map view
  - `qrcode` - Sign-off feature
  - `lock.fill` - Privacy/security

## 🗺️ Data Sources

### Dive Sites Database
- **Source**: OpenDiveSites + Custom curation
- **License**: CC BY-SA 4.0
- **Attribution**: "Dive site data from OpenDiveSites community"
- **Files**: `Resources/SeedData/sites_seed.json`
- **Size**: ~5MB compressed

### Species Data

#### Fish Species
- **Source**: FishBase.org
- **License**: CC BY-NC 3.0
- **Attribution**: "Froese, R. and D. Pauly. Editors. 2024. FishBase."
- **API**: Not used (offline dataset)
- **Files**: `Resources/SeedData/species_fish.json`

#### Marine Life (Non-Fish)
- **Source**: SeaLifeBase.org
- **License**: CC BY-NC 3.0
- **Attribution**: "Palomares, M.L.D. and D. Pauly. Editors. 2024. SeaLifeBase."
- **Files**: `Resources/SeedData/species_marine.json`

#### Regional Species Lists
- **Caribbean**: REEF.org survey data (permission pending)
- **Indo-Pacific**: Compiled from field guides (fair use)
- **Mediterranean**: Custom curation
- **Red Sea**: Custom curation

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

### Placeholder Images
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

## 🔄 Update Log

| Date | Asset | Change | License |
|------|-------|--------|---------|
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