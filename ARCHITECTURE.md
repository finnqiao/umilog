# 🏗️ UmiLog Architecture

## Overview

UmiLog is built on an **offline-first, privacy-focused** architecture that prioritizes reliability and performance for divers in challenging conditions (wet hands, no connectivity, time pressure).

## Core Principles

1. **Offline-First**: All core features must work without internet
2. **Data Ownership**: Users control their data with local-first storage and optional E2E encrypted sync
3. **Performance**: Sub-100ms commits for critical paths, <2s cold start
4. **Reliability**: Zero data loss tolerance, crash-safe operations
5. **Privacy**: On-device processing, encrypted storage, minimal cloud footprint

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    iOS App (SwiftUI)                     │
├─────────────────────────────────────────────────────────┤
│                    Feature Modules                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │   Home   │ │ LiveLog  │ │ Wildlife │ │ Settings │  │
│  │  (Map)   │ │ (Voice)  │ │(Species) │ │ (Export) │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
├─────────────────────────────────────────────────────────┤
│                   Service Layer                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Location │ │  Speech  │ │   PDF    │ │  Export  │  │
│  │    Kit   │ │    Kit   │ │   Kit    │ │   Kit    │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
├─────────────────────────────────────────────────────────┤
│                    Data Layer                            │
│  ┌──────────────────────┐ ┌──────────────────────────┐ │
│  │     UmiDB (GRDB)     │ │   UmiSyncKit (CloudKit)  │ │
│  │   SQLCipher + FTS5   │ │      E2E Encryption      │ │
│  └──────────────────────┘ └──────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│              System Frameworks                           │
│   CoreLocation │ Speech │ CloudKit │ CryptoKit │ PDFKit│
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  watchOS Companion                       │
│          CMWaterSubmersionManager │ HealthKit           │
└─────────────────────────────────────────────────────────┘
```

## Module Structure

### App Target
- `UmiLog/` - Main iOS app
  - `App/` - App lifecycle, scene management
  - `DI/` - Dependency injection container
  - `Router/` - Navigation coordination

### Feature Modules (Swift Packages)
- `FeatureHome/` - Map view, trip cards
- `FeatureLiveLog/` - Real-time dive logging
- `FeatureSiteIndex/` - Site database and search
- `FeatureWildlife/` - Species tracking
- `FeatureSignOff/` - QR codes, signatures
- `FeatureBackfill/` - Import wizards
- `FeatureSettings/` - Privacy, sync, exports

### Service Modules
- `UmiCoreKit/` - Shared utilities, logging, DI
- `UmiDesignSystem/` - UI components, themes
- `UmiDB/` - Database layer (GRDB + SQLCipher)
- `UmiSyncKit/` - CloudKit sync engine
- `UmiLocationKit/` - GPS services
- `UmiSpeechKit/` - Voice recognition
- `UmiPDFKit/` - PDF generation
- `UmiExportKit/` - Data export/import

## Data Flow (MVVM)

```swift
// View → ViewModel → Repository → Database

struct LiveLogView: View {
    @StateObject private var viewModel: LiveLogViewModel
    
    var body: some View {
        // SwiftUI View
    }
}

@MainActor
class LiveLogViewModel: ObservableObject {
    @Published var state: LiveLogState
    private let repository: DiveRepository
    
    func startLogging() async {
        // Business logic
        try await repository.createDive(...)
    }
}

actor DiveRepository {
    private let database: DatabasePool
    
    func createDive(_ dive: Dive) async throws {
        // Database operations
    }
}
```

## Database Schema

### Core Tables

```sql
-- Encrypted with SQLCipher
CREATE TABLE dives (
    id TEXT PRIMARY KEY,
    site_id TEXT REFERENCES sites(id),
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    max_depth_m REAL,
    bottom_time_min INTEGER,
    start_pressure_bar INTEGER,
    end_pressure_bar INTEGER,
    water_temp_c REAL,
    visibility_m REAL,
    notes TEXT,  -- Encrypted in CloudKit
    created_at INTEGER DEFAULT CURRENT_TIMESTAMP,
    updated_at INTEGER DEFAULT CURRENT_TIMESTAMP,
    sync_hash TEXT
);

CREATE TABLE sites (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    country_code TEXT,
    region_code TEXT,
    typical_conditions TEXT,  -- JSON
    wishlist INTEGER DEFAULT 0
);

-- Full-text search
CREATE VIRTUAL TABLE sites_fts USING fts5(
    name, description, 
    content='sites'
);
```

### Indexes for Performance

```sql
CREATE INDEX idx_dives_start_time ON dives(start_time DESC);
CREATE INDEX idx_dives_site ON dives(site_id);
CREATE INDEX idx_sites_location ON sites(latitude, longitude);
CREATE INDEX idx_sightings_dive ON sightings(dive_id);
```

## Offline-First Strategy

### 1. Local Database Priority
- All data written to local SQLite first
- UI reads exclusively from local DB
- Background sync to CloudKit when available

### 2. Sync Queue
```swift
struct SyncOperation {
    let recordType: CKRecord.RecordType
    let action: SyncAction  // .create, .update, .delete
    let localID: String
    let timestamp: Date
    var retryCount: Int = 0
}
```

### 3. Conflict Resolution
- Last-write-wins with field-level timestamps
- Conflicts logged for manual review
- Critical fields (depth, time) protected from overwrites

### 4. Offline Datasets
- Pre-loaded dive sites (~5MB)
- Regional species lists (~3MB per region)
- Cached map tiles for visited areas

## Security Model

### 1. Database Encryption
```swift
// SQLCipher with per-user key
let key = try KeychainService.getDatabaseKey()
let db = try DatabasePool(
    path: dbPath,
    configuration: .init(
        passphrase: { _ in key }
    )
)
```

### 2. E2E CloudKit Encryption
```swift
// Sensitive fields encrypted before CloudKit
let encryptedNotes = try ChaChaPoly.seal(
    notes.data(using: .utf8)!,
    using: userKey
)
record["notes_encrypted"] = encryptedNotes.combined
```

### 3. App Lock
- Face ID / Touch ID required
- Auto-lock on background
- Secure enclave for biometric keys

## Performance Optimizations

### 1. Database Performance
- WAL mode for concurrent reads
- Prepared statements for hot paths
- Batch inserts for imports
- FTS5 for fast search

### 2. UI Performance
- Lazy loading in lists
- Image caching with thumbnails
- Debounced search inputs
- Virtual scrolling for large datasets

### 3. Background Processing
- Low-priority sync queue
- Batch network requests
- Opportunistic processing

## Voice Input Architecture

```swift
// On-device only processing
class VoiceInputService {
    private let recognizer = SFSpeechRecognizer(locale: .current)
    
    init() {
        recognizer?.supportsOnDeviceRecognition = true
    }
    
    func parseCommand(_ text: String) -> DiveCommand? {
        // Deterministic parsing for numbers
        // "depth twenty five" → .depth(25)
        // "pressure one eight zero" → .pressure(180)
    }
}
```

## Watch Integration

### Immersion Detection
```swift
// Apple Watch Ultra only
class ImmersionMonitor {
    let submersionManager = CMWaterSubmersionManager()
    
    func startMonitoring() {
        submersionManager.delegate = self
        submersionManager.startUpdates()
    }
}
```

### Watch Connectivity
- Buffered message queue
- Automatic retry on failure
- Background transfers for reliability

## Testing Strategy

### 1. Unit Tests
- Database migrations
- Import/export parsers
- Voice command parsing
- Sync conflict resolution

### 2. Integration Tests
- Offline scenarios
- Sync reliability
- Data consistency

### 3. Performance Tests
- Cold start time < 2s
- Write latency < 100ms
- Search response < 200ms

## Monitoring & Analytics

### Privacy-Preserving Metrics
- No user tracking
- Aggregated performance metrics only
- Crash reporting with opt-in
- Local metrics for debugging

```swift
os_signpost(.begin, log: .performance, name: "DatabaseWrite")
// ... operation ...
os_signpost(.end, log: .performance, name: "DatabaseWrite")
```

## Deployment

### Build Configuration
- Debug: Local development
- Beta: TestFlight distribution
- Release: App Store distribution

### Feature Flags
```swift
enum Feature: String {
    case voiceInput = "voice_input"
    case watchSupport = "watch_support"
    
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: rawValue)
    }
}
```

## Future Considerations

### Scalability
- Sharding large tables (>100k dives)
- CDN for offline map tiles
- Background sync optimization

### Extensibility
- Plugin architecture for dive computers
- Widget support
- Shortcuts/Siri integration

### Platform Expansion
- macOS Catalyst app
- Android (Kotlin Multiplatform)
- Web PWA for sign-off

## Design System

See [DESIGN.md](DESIGN.md) for comprehensive UI/UX specifications.

### Visual Reference
- **Web Prototype**: `design/` directory (React/TypeScript)
- **Figma Source**: https://www.figma.com/design/JwMxy351eNAi3eQvWX6GBA/UmiLog-Dive-Log-App
- **Component Library**: shadcn/ui (translated to SwiftUI)

### Color Palette
- Ocean Blue `#2563EB` - Primary actions
- Teal `#0D9488` - Depth metrics
- Sea Green `#16A34A` - Success states
- Purple `#9333EA` - Wildlife
- Coral Red `#DC2626` - Warnings

### Typography
Dynamic Type with SF Pro:
- `.largeTitle` - Dashboard title
- `.title` - Section headers
- `.body` - Primary text
- `.caption` - Metadata

### Navigation
- TabView with 5 tabs: Home, Log, History, Sites, More
- NavigationStack per tab for deep navigation
- Sheet presentations for modals (dive logger, settings)

## Decision Log

| Decision | Rationale | Trade-offs |
|----------|-----------|------------|
| GRDB over Core Data | Better SQL control, FTS5 support | Manual migration management |
| CloudKit over custom backend | Zero server costs, Apple integration | iOS-only, limited query capabilities |
| On-device STT | Privacy, offline capability | Limited to device languages |
| SQLCipher | HIPAA-level encryption | ~15% performance overhead |
| SwiftUI only | Modern, less code | iOS 17+ requirement |
| shadcn/ui as design ref | Modern, accessible components | Requires manual SwiftUI translation |

---

*Last Updated: October 2024*
