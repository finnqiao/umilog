# UmiLog

Dive log iOS app — area-first navigation, offline-first.

## Commands
```bash
brew install xcodegen swiftlint   # First-time setup
xcodegen generate                 # Generate Xcode project from project.yml
open UmiLog.xcworkspace           # Open in Xcode

# Data pipeline
make wd-fetch       # Fetch Wikidata dive sites
make build-all      # Full data pipeline
make seed-deploy    # Deploy seed files to Resources

# CI
fastlane build      # Simulator build (no signing)
fastlane test       # Unit tests
fastlane ci_beta    # Build + sign + upload to TestFlight
```

## Stack
- iOS 17+, SwiftUI, Swift 5.9+
- GRDB 6.29 (SQLite ORM)
- MapLibre 6.10 (mapping)
- Sentry 8.40 (error tracking)
- XcodeGen (project generation from project.yml)
- Fastlane + Match (signing + CI)

## Structure
```
UmiLog/            # App entry point
Modules/           # Feature modules
  FeatureMap/      # Map exploration (MapLibre)
  FeatureLiveLog/  # Live dive logging
  FeatureSites/    # Site explorer
  FeatureSettings/ # Settings
  UmiCoreKit/      # Core framework
  UmiDB/           # GRDB database layer
  UmiDesignSystem/ # Design components
  DiveMap/         # MapLibre integration
Resources/
  SeedData/        # Pre-bundled dive site data (56MB, committed)
  Maps/            # GeoJSON, map styles
data/              # Data pipeline scripts (SPARQL, Overpass)
fastlane/          # Fastlane config (Fastfile, Matchfile, Appfile)
```

## Signing
- Bundle ID: app.umilog
- Team ID: ZK79P5HJFM
- Match certs in github.com/finnqiao/ios-certificates (private)

## CI
- GitHub Actions `ci.yml`: build + test on push/PR
- GitHub Actions `testflight.yml`: manual trigger, builds and uploads to TestFlight
