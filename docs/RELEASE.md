# UmiLog Release Guide

## Prerequisites

### One-Time Setup

1. **Apple Developer Account** ($99/year)
   - Enroll at https://developer.apple.com/programs/enroll/

2. **App Store Connect App Record**
   - Go to https://appstoreconnect.apple.com
   - My Apps → (+) New App
   - Fill in:
     - Platform: iOS
     - Name: UmiLog
     - Bundle ID: `app.umilog`
     - SKU: `umilog-ios`

3. **Install Fastlane** (optional but recommended)
   ```bash
   gem install fastlane
   # or
   brew install fastlane
   ```

## Build Configurations

| Config | Use Case | Bundle ID | Notes |
|--------|----------|-----------|-------|
| Debug | Local development | app.umilog | No optimization |
| Staging | TestFlight QA | app.umilog | Optimized, staging APIs |
| Release | App Store | app.umilog | Full optimization, production |

## Quick Commands

### Local Development
```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open UmiLog.xcodeproj

# Build (Cmd+B) and Run (Cmd+R) in Xcode
```

### TestFlight Upload (Manual)
```bash
# 1. Increment build number
./scripts/increment_build.sh

# 2. Generate project
xcodegen generate

# 3. Archive in Xcode
# - Select "Any iOS Device (arm64)"
# - Product → Archive
# - Window → Organizer → Distribute App → TestFlight & App Store
```

### TestFlight Upload (Fastlane)
```bash
# One command does it all
fastlane beta
```

### App Store Release (Fastlane)
```bash
fastlane release
```

## Pre-Release Checklist

### Code Quality
- [ ] All unit tests pass (`fastlane test`)
- [ ] No compiler warnings
- [ ] SwiftLint passes (if configured)

### App Store Compliance
- [ ] Privacy Manifest updated (`UmiLog/PrivacyInfo.xcprivacy`)
- [ ] All Info.plist usage descriptions accurate
- [ ] No test/debug data in production
- [ ] App icon and launch screen present

### App Store Connect
- [ ] App record created with correct Bundle ID
- [ ] Privacy policy URL added
- [ ] App privacy disclosures completed
- [ ] Screenshots uploaded (6.7" iPhone required)
- [ ] Description and keywords set
- [ ] Age rating questionnaire completed
- [ ] Export compliance answered

### TestFlight (Before External)
- [ ] Internal testing completed
- [ ] "What to Test" notes written
- [ ] Beta review info provided (if needed)

## Version Numbers

- **Marketing Version** (`MARKETING_VERSION`): User-facing version (1.0.0, 1.1.0)
- **Build Number** (`CURRENT_PROJECT_VERSION`): Increments every upload (1, 2, 3...)

Update in `project.yml`:
```yaml
settings:
  base:
    MARKETING_VERSION: 1.0.0
    CURRENT_PROJECT_VERSION: 1
```

Or use the script:
```bash
./scripts/increment_build.sh
```

## CI/CD (GitHub Actions)

The repo has GitHub Actions configured:
- **Trigger**: Push to `main`, PRs to `main`
- **Steps**: Generate project → Build for simulator

To add TestFlight deployment via CI, you'll need:
1. App Store Connect API Key (preferred over Apple ID)
2. Store key in GitHub Secrets
3. Update `.github/workflows/ci.yml`

## Troubleshooting

### "Untrusted Developer" on device
Settings → General → VPN & Device Management → Trust your profile

### Archive fails with signing errors
- Xcode → Preferences → Accounts → Download Manual Profiles
- Or: Enable "Automatically manage signing"

### TestFlight processing stuck
- Wait up to 1 hour
- Check App Store Connect for processing status
- Ensure no binary encryption issues

### App Review rejection
- Read rejection reason in Resolution Center
- Common issues:
  - Missing privacy policy
  - Broken links
  - Placeholder content
  - Location permission justification

## Support

- Apple Developer Forums: https://developer.apple.com/forums/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Fastlane Docs: https://docs.fastlane.tools/
