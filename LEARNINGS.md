# 📚 UmiLog Learnings

> Document key decisions, discoveries, and lessons learned during development.

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

#### SwiftUI State Management
- `@StateObject` vs `@ObservedObject` confusion causes view recreation
- Use `@StateObject` for ownership, `@ObservedObject` for references
- Task cancellation needs explicit handling in async views

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