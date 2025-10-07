# Task List: UmiLog MVP Implementation

## Relevant Files

### Core Map & Visualization
- `Modules/FeatureMap/Sources/ScratchOffMapView.swift` - Main scratch-off world map view
- `Modules/FeatureMap/Sources/ScratchOffMapViewModel.swift` - Map state and country tracking
- `Modules/FeatureMap/Sources/MapOverlayView.swift` - Stats overlay on map
- `Modules/FeatureMap/Sources/CountryProgressTracker.swift` - Track visited countries
- `Modules/FeatureMap/Sources/ScratchOffMapView.test.swift` - Unit tests for map view

### Geofencing & Auto-Logging
- `Modules/UmiLocationKit/Sources/GeofenceManager.swift` - Handle dive site geofencing
- `Modules/UmiLocationKit/Sources/LocationService.swift` - Core location services
- `Modules/UmiLocationKit/Sources/AutoLogService.swift` - Smart auto-logging logic
- `Modules/UmiLocationKit/Sources/GeofenceManager.test.swift` - Geofence tests

### Quick Logging
- `Modules/FeatureLiveLog/Sources/QuickLogView.swift` - One-tap logging interface
- `Modules/FeatureLiveLog/Sources/QuickLogViewModel.swift` - Quick log business logic
- `Modules/FeatureLiveLog/Sources/AutoFillService.swift` - Pre-fill dive data

### Gamification
- `Modules/FeatureAchievements/Sources/AchievementManager.swift` - Badge and achievement system
- `Modules/FeatureAchievements/Sources/ProgressTracker.swift` - Track user progress
- `Modules/FeatureAchievements/Sources/CelebrationView.swift` - Achievement celebrations

### Community Features
- `Modules/FeatureCommunity/Sources/NearbyDiversView.swift` - Show divers at location
- `Modules/FeatureCommunity/Sources/CommunityDataService.swift` - Aggregate community data

### API Integrations
- `Modules/UmiWeatherKit/Sources/WeatherService.swift` - Weather/ocean APIs
- `Modules/UmiWeatherKit/Sources/TideService.swift` - Tide and current data

### Database Updates
- `Modules/UmiDB/Sources/Models/Achievement.swift` - Achievement data model
- `Modules/UmiDB/Sources/Models/Country.swift` - Country visit tracking
- `Modules/UmiDB/Sources/Repositories/AchievementRepository.swift` - Achievement CRUD

### Navigation Updates
- `UmiLog/UmiLogApp.swift` - Update tab navigation to make map primary
- `Modules/FeatureHome/Sources/DashboardView.swift` - Refactor to map-centric view

### Notes

- The map should replace the current dashboard as the home screen
- Geofencing must be efficient to minimize battery drain
- All new features should work offline with sync later
- Community features should maintain user privacy
- Use `xcodegen generate` to regenerate project after adding new modules

## Tasks

- [ ] 1.0 Refactor Navigation to Map-Centric Design
- [ ] 2.0 Implement Scratch-Off World Map
- [ ] 3.0 Build Geofencing & Auto-Logging System  
- [ ] 4.0 Create Quick-Log Experience
- [ ] 5.0 Implement Gamification & Achievements
- [ ] 6.0 Add Community Features
- [ ] 7.0 Integrate External APIs
- [ ] 8.0 Polish & Delightful Moments