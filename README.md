# 🌊 UmiLog - iOS Dive Log App

> A zero-friction, offline-first dive log that makes casual logging fun, trustworthy, and fast.

## 🎯 Vision

UmiLog (海ログ - "sea log" in Japanese) solves the biggest pain points in dive logging: tedious after-dive forms, unreliable apps that lose data, and painful historical backfilling. Built for casual recreational divers who want to capture essentials quickly, even when wet, offline, and tired.

## ✨ Key Features

### MVP Scope (6-8 weeks)

#### 🗺️ Map & Trip Cards
- Interactive world map showing visited vs wishlist dive sites
- Beautiful trip cards with dive summaries
- Offline-capable with fallback views

#### 📍 Smart Site Index
- Offline database of popular dive sites
- GPS-based automatic site suggestions
- Community-driven site additions

#### 🎙️ Live Logging
- **Voice input** for hands-free logging (depth, time, pressures)
- Pre-filled defaults based on location and season
- Sub-100ms data commits for reliability
- Apple Watch Ultra immersion detection support

#### 🐠 Wildlife Tracking
- Regional species lists (offline)
- "Pokédex"-style collection progress
- Quick sighting entry during dives

#### ✍️ Digital Sign-off
- QR code generation for instructor/DM verification
- 20-second sign-off workflow
- PDF generation with signatures

#### 📊 Backfill Wizard
- Import years of past dives in minutes
- CSV/UDDF import support
- Photo EXIF and calendar assistance

#### 🔐 Data Ownership
- **100% offline-first** - all features work without internet
- End-to-end encrypted CloudKit sync (optional)
- Export to PDF/CSV/UDDF formats
- Face ID app lock

## 🏗️ Architecture

- **Platform**: iOS 17+ (SwiftUI)
- **Database**: GRDB + SQLCipher (encrypted SQLite)
- **Sync**: CloudKit with E2E encryption
- **Voice**: On-device Speech framework
- **Offline**: All core features work without connectivity
- **Performance**: <2s cold start, <100ms field commits

### Design System
See [DESIGN.md](DESIGN.md) for comprehensive UI/UX specifications and iOS translation guide. A web prototype is available in the `design/` directory for visual reference.

## 📱 Requirements

- iOS 17.0 or later
- iPhone 12 or newer recommended
- Apple Watch Ultra for immersion detection (optional)
- ~50MB storage for offline datasets

## 🚀 Getting Started

### Prerequisites

1. **Xcode 15.0+** - [Download from App Store](https://apps.apple.com/app/xcode/id497799835)
2. **Apple Developer Account** - For CloudKit and device testing
3. **Homebrew** - Package manager for macOS
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/umilog.git
cd umilog
```

2. Install build tools:
```bash
brew install xcodegen swiftlint
```

3. Generate Xcode project:
```bash
xcodegen generate
```

4. Open in Xcode:
```bash
open UmiLog.xcworkspace
```

5. Select your development team in Xcode:
   - Open project settings
   - Select "UmiLog" target
   - Choose your team in "Signing & Capabilities"

6. Build and run:
   - Select target device/simulator
   - Press `Cmd+R` to run

## 🧪 Testing

Run all tests:
```bash
xcodebuild test -workspace UmiLog.xcworkspace -scheme UmiLog -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 📊 Success Metrics

- **North Star**: Dives successfully logged per active diver per trip day
- **Activation**: Time-to-first-dive < 5 min
- **Backfill**: 10 historical dives < 8 min
- **Sign-off**: Median time < 20 seconds
- **Data Loss**: Zero tolerance

## 🗺️ Roadmap

### Phase 0: Foundation (Current)
- [x] Project setup and architecture
- [ ] Core database schema
- [ ] Offline-first infrastructure

### Phase 1: MVP (6-8 weeks)
- [ ] Map & trip cards
- [ ] Live logging with voice
- [ ] Site index with GPS
- [ ] Wildlife tracking
- [ ] QR sign-off
- [ ] Backfill wizard
- [ ] Watch Ultra support

### Phase 2: Delight (Post-MVP)
- [ ] Shop stamps & badges
- [ ] Enhanced wildlife features
- [ ] Social features (private groups)
- [ ] Advanced statistics

### Phase 3: Scale
- [ ] Dive computer integrations
- [ ] PADI/SSI partnerships
- [ ] Shop dashboards
- [ ] Android version

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Dive site data: OpenDiveSites (CC BY-SA 4.0)
- Species data: FishBase, SeaLifeBase
- Icons: SF Symbols, custom designs

## 📧 Contact

- Email: team@umilog.app
- Discord: [Join our community](https://discord.gg/umilog)
- Issues: [GitHub Issues](https://github.com/yourusername/umilog/issues)

---

*UmiLog - Log dives before the rinse bucket drains* 🤿