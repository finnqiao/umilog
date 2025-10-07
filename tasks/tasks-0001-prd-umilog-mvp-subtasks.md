# UmiLog MVP Implementation - Detailed Sub-Tasks

## 1.0 Refactor Navigation to Map-Centric Design

### 1.1 Update App Navigation Structure
- [ ] Move scratch-off map to primary tab position
- [ ] Replace dashboard with map as default home view
- [ ] Update tab icons and labels for new hierarchy
- [ ] Add map stats overlay button to navigation

### 1.2 Migrate Dashboard Content
- [ ] Move key stats to map overlay view
- [ ] Integrate recent dives into map markers
- [ ] Create quick access menu for common actions
- [ ] Preserve dashboard as secondary view option

### 1.3 Update App State Management
- [ ] Refactor AppState to prioritize map view
- [ ] Update deep linking to support map locations
- [ ] Configure launch screen to match map theme
- [ ] Handle state restoration for map position

## 2.0 Implement Scratch-Off World Map

### 2.1 Create FeatureMap Module
- [ ] Set up FeatureMap module in project.yml
- [ ] Configure module dependencies (MapKit, Core Graphics)
- [ ] Create module folder structure
- [ ] Add to XcodeGen configuration

### 2.2 Build Core Map View
- [ ] Implement ScratchOffMapView with MapKit base
- [ ] Create custom map overlay for scratch-off effect
- [ ] Add country boundary detection logic
- [ ] Implement zoom and pan constraints

### 2.3 Implement Scratch-Off Mechanics
- [ ] Create scratch-off shader/mask effect
- [ ] Track visited countries in database
- [ ] Animate country reveal on first visit
- [ ] Add percentage completion tracking

### 2.4 Add Map Statistics Overlay
- [ ] Design stats overlay UI
- [ ] Show countries visited count
- [ ] Display percentage of world explored
- [ ] Add dive count per country

### 2.5 Create Country Detail View
- [ ] Show country dive statistics
- [ ] List dive sites in country
- [ ] Display best conditions info
- [ ] Add country-specific achievements

## 3.0 Build Geofencing & Auto-Logging System

### 3.1 Create UmiLocationKit Module
- [ ] Set up UmiLocationKit module structure
- [ ] Configure Core Location dependencies
- [ ] Add background location capabilities
- [ ] Create module tests structure

### 3.2 Implement Geofence Manager
- [ ] Create GeofenceManager service
- [ ] Register dive site geofences
- [ ] Handle region entry/exit events
- [ ] Optimize for battery efficiency

### 3.3 Build Auto-Log Service
- [ ] Create AutoLogService with heuristics
- [ ] Detect dive start (depth/pressure change)
- [ ] Track dive duration automatically
- [ ] Queue logs for user confirmation

### 3.4 Add Smart Notifications
- [ ] Request notification permissions
- [ ] Send "Log your dive?" prompts
- [ ] Include pre-filled data in notification
- [ ] Handle notification actions

### 3.5 Implement Battery Optimization
- [ ] Use significant location changes
- [ ] Batch location updates
- [ ] Suspend when battery low
- [ ] Add user controls for auto-logging

## 4.0 Create Quick-Log Experience

### 4.1 Design Quick Log Interface
- [ ] Create QuickLogView with one-tap UI
- [ ] Design compact form layout
- [ ] Add swipe gestures for common values
- [ ] Implement haptic feedback

### 4.2 Build Auto-Fill Logic
- [ ] Pre-fill location from GPS
- [ ] Suggest dive site from geofence
- [ ] Auto-detect buddy from contacts
- [ ] Pull conditions from weather API

### 4.3 Create Quick Actions
- [ ] Add "Same as last dive" option
- [ ] Implement voice input shortcuts
- [ ] Create customizable quick templates
- [ ] Add recent locations dropdown

### 4.4 Optimize Data Entry
- [ ] Use smart defaults for all fields
- [ ] Add predictive text for site names
- [ ] Implement depth/time sliders
- [ ] Create wildlife quick-add chips

## 5.0 Implement Gamification & Achievements

### 5.1 Create FeatureAchievements Module
- [ ] Set up achievements module structure
- [ ] Design achievement data models
- [ ] Create achievement icons/assets
- [ ] Configure achievement rules engine

### 5.2 Build Achievement System
- [ ] Define achievement categories
- [ ] Implement progress tracking
- [ ] Create unlock conditions
- [ ] Add rarity/difficulty levels

### 5.3 Design Achievement Types
- [ ] Country-based (visit X countries)
- [ ] Depth milestones (30m, 40m clubs)
- [ ] Streak achievements (daily/weekly)
- [ ] Wildlife spotting badges
- [ ] Special location badges

### 5.4 Create Celebration UI
- [ ] Design achievement unlock animation
- [ ] Add confetti/particle effects
- [ ] Create achievement notification banner
- [ ] Build achievement showcase view

### 5.5 Implement Progress Tracking
- [ ] Create progress bars for each achievement
- [ ] Show "almost there" hints
- [ ] Add achievement statistics
- [ ] Create leaderboard view

## 6.0 Add Community Features

### 6.1 Create FeatureCommunity Module
- [ ] Set up community module structure
- [ ] Design privacy-first architecture
- [ ] Create aggregation services
- [ ] Add CloudKit sharing config

### 6.2 Build "Divers Here Now" Feature
- [ ] Show anonymous diver count at site
- [ ] Display recent activity heat map
- [ ] Add time-based filtering
- [ ] Implement privacy controls

### 6.3 Create Popular Sites Discovery
- [ ] Aggregate site visit data
- [ ] Show trending dive sites
- [ ] Add seasonal recommendations
- [ ] Display community ratings

### 6.4 Implement Social Proof Elements
- [ ] Show "X divers logged here today"
- [ ] Add "Most visited this month" badges
- [ ] Create discovery suggestions
- [ ] Add community milestones

## 7.0 Integrate External APIs

### 7.1 Create UmiWeatherKit Module
- [ ] Set up weather services module
- [ ] Configure API authentication
- [ ] Add caching layer
- [ ] Create fallback mechanisms

### 7.2 Integrate Weather APIs
- [ ] Connect to weather service
- [ ] Fetch current conditions
- [ ] Get marine forecasts
- [ ] Cache recent queries

### 7.3 Add Ocean Condition APIs
- [ ] Integrate tide data service
- [ ] Fetch water temperature
- [ ] Get visibility estimates
- [ ] Add current/swell data

### 7.4 Build Condition Predictions
- [ ] Create best time to dive algorithm
- [ ] Show condition trends
- [ ] Add weather alerts
- [ ] Generate dive recommendations

## 8.0 Polish & Delightful Moments

### 8.1 Add Micro-Interactions
- [ ] Implement pull-to-refresh with bubbles
- [ ] Add water ripple effects
- [ ] Create smooth transitions
- [ ] Add subtle animations

### 8.2 Create Onboarding Experience
- [ ] Design welcome sequence
- [ ] Add interactive map tutorial
- [ ] Create first dive celebration
- [ ] Implement tips system

### 8.3 Enhance Visual Design
- [ ] Apply ocean-themed gradients
- [ ] Add underwater parallax effects
- [ ] Create custom loading states
- [ ] Implement dark mode support

### 8.4 Add Sound Design
- [ ] Create underwater ambient sounds
- [ ] Add achievement sound effects
- [ ] Implement haptic patterns
- [ ] Add optional sound themes

### 8.5 Performance Optimization
- [ ] Profile and optimize map rendering
- [ ] Implement image caching
- [ ] Optimize database queries
- [ ] Add performance monitoring

## Implementation Priority Order

### Phase 1: Core Map Experience (Week 1-2)
1. Refactor navigation (1.0)
2. Basic scratch-off map (2.1-2.3)
3. Map statistics (2.4-2.5)

### Phase 2: Smart Logging (Week 3-4)
1. Quick log interface (4.1-4.2)
2. Geofencing setup (3.1-3.2)
3. Auto-logging basics (3.3-3.4)

### Phase 3: Engagement Features (Week 5-6)
1. Achievement system (5.1-5.3)
2. Celebration UI (5.4-5.5)
3. Community features (6.1-6.2)

### Phase 4: Enhanced Experience (Week 7-8)
1. Weather integration (7.1-7.2)
2. Ocean conditions (7.3-7.4)
3. Polish and delight (8.1-8.5)

## Success Metrics

- Map loads in < 1 second
- Quick log completes in < 10 seconds
- Geofencing accuracy > 95%
- Achievement unlock rate > 60%
- Daily active usage > 40%
- Battery impact < 5% per day

## Testing Requirements

### Unit Tests
- All ViewModels with > 80% coverage
- Database operations
- Achievement unlock logic
- Geofencing calculations

### UI Tests
- Quick log flow
- Map interaction
- Achievement celebrations
- Navigation transitions

### Performance Tests
- Map rendering speed
- Database query optimization
- Memory usage monitoring
- Battery drain testing

## Dependencies

### External
- MapKit for base map
- Core Location for geofencing
- CloudKit for sync
- Weather API service
- Ocean conditions API

### Internal
- UmiDB for data persistence
- UmiDesignSystem for UI components
- UmiSyncKit for data sync
- UmiLocationKit for location services