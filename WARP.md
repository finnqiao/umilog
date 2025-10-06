# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

UmiLog is an iOS dive logging app in the planning/documentation stage. This repository currently contains the architectural design and specifications for an offline-first, privacy-focused dive logging application for iOS 17+ with Apple Watch Ultra support.

## Repository Rules

When working in this repository, always:
- Update LEARNINGS.MD, TODO.MD, README.MD, ASSETS.MD, and ARCHITECTURE.MD with relevant changes
- Commit frequently in small blocks using Conventional Commits format
- Push when a feature or documentation section is complete

## Common Development Tasks

### Documentation Updates
When updating documentation:
```bash
# Review current documentation structure
ls -la *.md

# Edit documentation files
# Always update related files together (e.g., if architecture changes, update both ARCHITECTURE.md and TODO.md)

# Commit using Conventional Commits
git add ARCHITECTURE.md TODO.md
git commit -m "docs(architecture): update database schema for offline sync"
```

### Setting Up for iOS Development (Future)

Once development begins, you'll need:
```bash
# Install required tools
brew install xcodegen swiftlint sqlcipher xcbeautify

# Generate Xcode project (when project.yml exists)
xcodegen generate

# Open workspace
open UmiLog.xcworkspace
```

### Running Tests (Future Implementation)
```bash
# Unit tests
xcodebuild test -workspace UmiLog.xcworkspace -scheme UmiLog -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# UI tests  
xcodebuild test -workspace UmiLog.xcworkspace -scheme UmiLogUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Performance tests
xcodebuild test -workspace UmiLog.xcworkspace -scheme UmiLogPerformanceTests -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -resultBundlePath .build/PerfResults.xcresult
```

## Architecture Overview

### Core Technologies
- **Platform**: iOS 17+ (SwiftUI)
- **Database**: GRDB + SQLCipher for encrypted local storage
- **Sync**: CloudKit with end-to-end encryption
- **Voice Input**: On-device Speech framework
- **Watch**: Apple Watch Ultra with CMWaterSubmersionManager

### Key Architectural Decisions

#### Offline-First Design
- All data written to local SQLite first
- Background sync to CloudKit when available
- Pre-loaded datasets for dive sites and species

#### Security & Privacy
- SQLCipher database encryption with Keychain-stored keys
- End-to-end encryption for CloudKit sync using ChaChaPoly
- On-device voice processing only
- Face ID/Touch ID app lock

#### Performance Targets
- Cold start: < 2 seconds
- Database writes: < 100ms
- Search response: < 200ms
- Memory usage: < 100MB baseline

### Module Structure (Planned)

```
UmiLog/
├── App/                    # App lifecycle, scene management
├── Features/
│   ├── FeatureHome/       # Map view, trip cards
│   ├── FeatureLiveLog/    # Real-time dive logging with voice
│   ├── FeatureSiteIndex/  # Dive site database
│   ├── FeatureWildlife/   # Species tracking
│   ├── FeatureSignOff/    # QR codes, digital signatures
│   └── FeatureBackfill/   # Import wizards
├── Services/
│   ├── UmiDB/            # GRDB + SQLCipher layer
│   ├── UmiSyncKit/       # CloudKit sync engine
│   ├── UmiLocationKit/   # GPS services
│   ├── UmiSpeechKit/     # Voice recognition
│   └── UmiPDFKit/        # PDF generation
└── WatchApp/             # Apple Watch companion
```

### Database Schema

The app uses SQLCipher-encrypted SQLite with the following core tables:
- `dives` - Core dive log entries
- `sites` - Dive site locations with GPS coordinates
- `sightings` - Wildlife observations
- `gear` - Equipment tracking
- Full-text search indexes for fast queries

### Sync Strategy

1. Local-first writes to SQLite
2. Background queue for CloudKit sync
3. Last-write-wins conflict resolution
4. Field-level encryption before CloudKit storage

## Development Workflow

### Branching Strategy
```bash
# Feature branches
git checkout -b feature/voice-input

# Documentation updates
git checkout -b docs/update-architecture

# Bug fixes
git checkout -b fix/sync-conflict
```

### Commit Convention
Use Conventional Commits format:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `style:` Code style changes
- `refactor:` Code refactoring
- `perf:` Performance improvements
- `test:` Adding tests
- `chore:` Maintenance tasks

Examples:
```bash
git commit -m "feat(livelog): add voice command parsing"
git commit -m "fix(sync): handle CloudKit conflicts properly"
git commit -m "docs: update ARCHITECTURE.md with sync strategy"
```

## Testing Guidelines (Future)

### Unit Tests
- Database migrations
- Import/export parsers
- Voice command parsing
- Sync conflict resolution

### UI Tests
- Key user flows (start/stop dive, log entry)
- Offline scenarios
- Search functionality

### Performance Tests
- Cold start time measurement
- Database write latency
- Memory profiling

## Important Notes

### Privacy & Security
- Never commit API keys or secrets
- All sensitive data must be encrypted
- Voice processing must remain on-device
- CloudKit data must be E2E encrypted

### Performance Budgets
- Maintain sub-100ms database commits
- Keep cold start under 2 seconds
- Monitor memory usage closely

### Apple Watch Integration
- Use CMWaterSubmersionManager for depth/temperature
- Handle connectivity interruptions gracefully
- Provide debug toggles for simulator testing

## Resources

- [README.md](README.md) - Project overview and setup
- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed technical architecture
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [TODO.md](TODO.md) - Current task list and roadmap
- [LEARNINGS.md](LEARNINGS.md) - Technical insights and decisions

## Contact

- Email: team@umilog.app
- Discord: Community discussions
- GitHub Issues: Bug reports and feature requests