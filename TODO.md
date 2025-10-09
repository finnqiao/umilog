# 📋 UmiLog TODO

## 🎯 MVP Features (6-8 weeks)

### Phase 0: Foundation ✅
- [x] Initialize repository
- [x] Create documentation structure
- [x] Import design prototype (Figma → React/TypeScript)
- [x] Document iOS translation strategy (DESIGN.md)
- [x] Map web components to SwiftUI equivalents
- [x] Define color palette and design tokens
- [x] Update asset attributions (shadcn/ui, Unsplash)
- [x] Setup Xcode project with XcodeGen
- [x] Configure SwiftUI app shell
- [x] Setup GRDB + SQLCipher
- [x] Create modular Swift Package structure
- [x] Implement database layer with models
- [x] Create initial ViewModels and data binding
- [ ] Generate comprehensive task lists for new PRD

### Phase 1: Core MVP Features (Based on New PRD)

#### 🗺️ Scratch-Off World Map (Primary Feature)
- [ ] Refactor navigation to map-centric design
- [ ] Implement scratch-off world map visualization
- [ ] Add country tracking and progress
- [ ] Create map statistics overlay
- [ ] Build country detail views
- [ ] Animate scratch-off reveals
- [ ] Add percentage completion tracking

#### ⚡ Quick Logging Experience
- [ ] Create one-tap quick log interface
- [ ] Build auto-fill logic from context
- [ ] Add "Same as last dive" option
- [ ] Implement smart defaults
- [ ] Design compact form layout
- [ ] Add haptic feedback

#### 📍 Geofencing & Auto-Logging
- [ ] Setup UmiLocationKit module
- [ ] Implement geofence manager
- [ ] Build auto-log detection service
- [ ] Add smart notification prompts
- [ ] Optimize for battery efficiency
- [ ] Handle background location updates
- [ ] Create user controls for auto-logging

#### 🏆 Gamification & Achievements
- [ ] Create achievement system architecture
- [ ] Define achievement categories
- [ ] Build celebration UI with animations
- [ ] Implement progress tracking
- [ ] Add country-based achievements
- [ ] Create depth milestone badges
- [ ] Design streak achievements

#### 👥 Community Features
- [ ] Build "Divers Here Now" feature
- [ ] Create popular sites discovery
- [ ] Add social proof elements
- [ ] Implement privacy controls
- [ ] Show activity heat maps
- [ ] Add seasonal recommendations

#### ✍️ QR Sign-off
- [ ] QR code generation
- [ ] Camera scanner
- [ ] Signature capture UI
- [ ] PDF generation with signatures
- [ ] Instructor verification flow
- [ ] Immutable PDF storage

#### 📊 Backfill Wizard
- [ ] CSV parser and mapping
- [ ] UDDF import support
- [ ] Photo EXIF extraction
- [ ] Calendar integration
- [ ] Batch validation
- [ ] Progress indicators
- [ ] Rollback on errors

#### 🔐 Data & Privacy
- [ ] Database encryption setup
- [ ] CloudKit configuration
- [ ] E2E encryption for sync
- [ ] Face ID app lock
- [ ] Export to CSV/PDF/UDDF
- [ ] Backup/restore flows
- [ ] Privacy settings UI

#### ⌚ Apple Watch Ultra
- [ ] watchOS app setup
- [ ] Immersion detection
- [ ] Watch → Phone sync
- [ ] Offline buffering
- [ ] Complication support

## 🐛 Known Issues

- [ ] Free Apple ID build: Push Notifications and iCloud disabled — re-enable when Developer Program is active; add build config to toggle capabilities
- [ ] CloudKit features temporarily disabled/mocked — verify offline-first paths and add guards
- [ ] Audit remaining SwiftUI screens for `.foregroundColor`/`.font` ambiguity and standardize on `.foregroundStyle` + `SwiftUI.Font`

## 💡 Improvements & Ideas

### Performance
- [ ] Precompile SQL statements
- [ ] Image thumbnail generation
- [ ] Background sync optimization
- [ ] Lazy load heavy features

### UX Enhancements  
- [ ] Haptic feedback
- [ ] Swipe gestures
- [ ] Dark mode polish
- [ ] Accessibility audit

### Post-MVP Features
- [ ] Shop stamps system
- [ ] Badge achievements
- [ ] Social sharing
- [ ] Dive computer sync
- [ ] Advanced statistics
- [ ] Multi-language support

## 📈 Success Metrics Tracking

### Target Metrics
- [ ] Cold start < 2s
- [ ] Field commit < 100ms  
- [ ] TTFD < 5 min
- [ ] Backfill 10 dives < 8 min
- [ ] Sign-off < 20s
- [ ] Data loss = 0

### Instrumentation Needed
- [ ] Performance monitoring
- [ ] Crash reporting
- [ ] User analytics (privacy-safe)
- [ ] Feature usage tracking

## 🧪 Testing Checklist

### Unit Tests
- [ ] Database operations
- [ ] Voice command parsing
- [ ] Import/export logic
- [ ] Sync conflict resolution

### UI Tests
- [ ] Happy path flows
- [ ] Offline scenarios
- [ ] Error handling
- [ ] Accessibility

### Performance Tests
- [ ] Startup time
- [ ] Database writes
- [ ] Search responsiveness
- [ ] Memory usage

## 📝 Documentation

- [x] README.md
- [x] ARCHITECTURE.md
- [x] TODO.md (this file)
- [x] LEARNINGS.md
- [x] ASSETS.md
- [x] DESIGN.md (UI/UX specs and iOS translation)
- [x] WARP.md (Warp AI guidance)
- [ ] API documentation
- [ ] User guide
- [ ] Contributing guide

## 🚀 Release Checklist

### Beta Release
- [ ] TestFlight build
- [ ] Internal testing group
- [ ] Feedback collection
- [ ] Crash monitoring

### App Store Release
- [ ] App Store assets
- [ ] Privacy policy
- [ ] Terms of service
- [ ] App review preparation
- [ ] Marketing materials

### Sprint Planning (Updated for New PRD)

### Phase 1: Core Map Experience (Week 1-2)
- Refactor navigation to map-centric
- Implement scratch-off world map
- Add map statistics overlay
- Create country detail views

### Phase 2: Smart Logging (Week 3-4)
- Build quick log interface
- Setup geofencing system
- Implement auto-logging service
- Add smart notifications

### Phase 3: Engagement Features (Week 5-6)
- Create achievement system
- Build celebration UI
- Add community features
- Implement social proof

### Phase 4: Polish & APIs (Week 7-8)
- Integrate weather APIs
- Add ocean conditions
- Polish micro-interactions
- Performance optimization
- TestFlight beta release

---

*Updated: 2024 - Track progress and maintain velocity* 🚀