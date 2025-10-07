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
- [ ] Setup Xcode project with XcodeGen
- [ ] Configure SwiftUI app shell
- [ ] Setup GRDB + SQLCipher
- [ ] Create modular Swift Package structure

### Phase 1: Core Features

#### 🎨 Design Implementation
- [ ] Create SwiftUI design system components
- [ ] Implement color tokens with dark mode support
- [ ] Build reusable card components
- [ ] Create custom button styles (primary, secondary, tertiary)
- [ ] Design stat card grid layout
- [ ] Implement navigation tab bar
- [ ] Add SF Symbols icon system

#### 🗺️ Map & Trip Cards
- [ ] Implement MapKit integration
- [ ] Custom dive site annotations
- [ ] Clustering for dense areas
- [ ] Trip card UI components (matching design prototype)
- [ ] Offline map tile caching
- [ ] Visited vs wishlist filtering
- [ ] Hero map card with overlay (Dashboard)

#### 📍 Site Index & GPS
- [ ] Load seed site database (~5MB)
- [ ] GPS proximity queries
- [ ] Site search with FTS5
- [ ] Add new site flow
- [ ] Offline site suggestions
- [ ] Site detail views

#### 🎙️ Live Logging
- [ ] State machine (idle → recording → complete)
- [ ] Voice input integration
- [ ] Command parsing ("depth twenty")
- [ ] Manual input fallback
- [ ] Sub-100ms commit performance
- [ ] Crash recovery system
- [ ] Auto-save drafts

#### 🐠 Wildlife Tracking  
- [ ] Regional species database
- [ ] Species search/browse
- [ ] Sighting quick-entry
- [ ] Collection progress UI
- [ ] Photo attachment support
- [ ] Statistics dashboard

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

- [ ] None yet - new project!

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

## 📅 Sprint Planning

### Current Sprint (Week 1-2)
- Foundation setup
- Database schema
- Basic UI shell
- Site index

### Next Sprint (Week 3-4)
- Live logging
- Voice input
- Wildlife tracking
- Map view

### Sprint 3 (Week 5-6)
- QR sign-off
- Backfill wizard
- Export features
- Watch app

### Sprint 4 (Week 7-8)
- Polish & bug fixes
- Performance optimization
- TestFlight beta
- Documentation

---

*Updated: 2024 - Track progress and maintain velocity* 🚀