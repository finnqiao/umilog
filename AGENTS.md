# UmiLog — Agent Instructions

Dive log iOS app. SwiftUI, GRDB, MapLibre, XcodeGen.

## Commands
```bash
xcodegen generate    # Generate Xcode project (required before build)
xcodebuild build -project UmiLog.xcodeproj -scheme UmiLog \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild test -project UmiLog.xcodeproj -scheme UmiLog \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

## Rules
- Make the smallest safe diff. Do not refactor unrelated screens.
- Always run `xcodegen generate` after changing `project.yml`.
- Do not modify `Resources/SeedData/` unless explicitly asked (56MB committed data).
- Do not change the GRDB schema without a migration.
- Do not modify Fastlane or CI config unless explicitly asked.
- MapLibre/map-related changes are high-risk — keep diffs minimal.
- Preserve offline-first behavior: no network calls in critical paths.

## Review Checklist
- [ ] No crash risk (force unwraps, unhandled optionals)
- [ ] GRDB migration included if models changed
- [ ] No new network dependencies in offline-critical paths
- [ ] project.yml updated if files added/removed
- [ ] Manual QA steps described for UI changes

## Structure
```
UmiLog/                    # App entry
Modules/
  FeatureMap/              # Map exploration (MapLibre)
  FeatureLiveLog/          # Live dive logging
  FeatureSites/            # Site explorer
  FeatureSettings/         # Settings
  UmiCoreKit/              # Core framework
  UmiDB/                   # GRDB database layer
  UmiDesignSystem/         # Design system
  DiveMap/                 # MapLibre wrapper
Resources/SeedData/        # Pre-bundled data (DO NOT modify casually)
project.yml                # XcodeGen project definition
```

## Signing
- Bundle ID: `app.umilog`
- Team: ZK79P5HJFM
- Certs: Match via `finnqiao/ios-certificates`

## CI
- `ci.yml`: build + test on push/PR
- `testflight.yml`: manual dispatch → TestFlight upload
