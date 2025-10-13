# 📚 UmiLog Learnings

> Document key decisions, discoveries, and lessons learned during development.

## 🔎 Latest Learnings (Oct 2025)

- Underwater theme: Achieved “underwater” feel with three light layers (animated MeshGradient, caustics via Canvas, subtle bubbles). Kept effects below 0.25 opacity and used materials for glassy UI. Provided `wateryCardStyle()` and `wateryTransition()` helpers to apply consistently.
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