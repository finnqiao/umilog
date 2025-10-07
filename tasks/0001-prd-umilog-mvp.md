# Product Requirements Document: UmiLog MVP

## Introduction/Overview

UmiLog is a log-first dive tracking application that transforms the tedious task of dive logging into an engaging, delightful experience. By combining intelligent auto-logging, beautiful scratch-off world map visualization, and gamification elements, UmiLog makes divers WANT to log their dives immediately after surfacing. The app targets the 90% of divers who don't use dedicated dive computers, offering them a friction-free way to build a visual record of their underwater adventures.

### Problem Statement
Current dive logging is a painful process - divers either forget to log, find it too time-consuming, or lose motivation after a few entries. Existing apps are either too complex (targeting tech divers) or too basic (missing the visual reward element). There's no solution that makes logging feel rewarding and effortless while creating a beautiful visualization of one's diving journey.

## Goals

1. **Reduce logging friction**: Enable dive logging in under 30 seconds with intelligent defaults and one-tap actions
2. **Visual engagement**: Create a "scratch-off map" experience that makes divers excited to see their world map fill up
3. **Behavioral change**: Achieve 80% of dives logged within 1 hour through gamification and smart reminders
4. **Community growth**: Connect divers through shared locations and collaborative data
5. **Retention**: Keep users engaged after 10 dives and maintain yearly active usage

## User Stories

### Core User Stories

1. **As a casual vacation diver**, I want to quickly log my dive without remembering all the details, so that I can get back to enjoying my vacation while still maintaining my dive record.

2. **As an active dive enthusiast**, I want to see my diving map grow like a scratch-off world map, so that I feel accomplished and motivated to explore new locations.

3. **As any diver**, I want the app to automatically detect when I'm at a dive site and pre-fill my log, so that I only need to confirm or adjust minor details.

4. **As a social diver**, I want to see who else has dived at my location recently, so that I can connect with fellow divers and share experiences.

5. **As a goal-oriented diver**, I want to track my progress through countries, dive count, and species spotted, so that I have tangible achievements to work toward.

6. **As a forgetful diver**, I want smart reminders based on my location and patterns, so that I never miss logging a dive.

7. **As a dive student**, I want my instructor to easily sign off on my dives digitally, so that I have verified logs for certification.

## Functional Requirements

### 1. Smart Auto-Logging System

1.1. **Geofencing Detection**
   - System must detect when user enters within 500m radius of known dive sites
   - System must trigger "Ready to dive?" notification when at dive site during typical diving hours (6am-6pm)
   - System must learn user's diving patterns and adjust notifications accordingly

1.2. **Auto-Population**
   - System must pre-fill dive site based on GPS location
   - System must auto-populate weather conditions from real-time APIs
   - System must suggest water temperature based on historical data for location/season
   - System must pre-fill tide and current data from ocean APIs
   - System must remember user's typical equipment and defaults

1.3. **One-Tap Logging**
   - System must allow complete dive logging with single confirmation tap if all defaults are acceptable
   - System must present smart defaults based on:
     - Location data
     - Time of day
     - Previous dives at same site
     - Community averages for the site

### 2. Scratch-Off World Map

2.1. **Map Visualization**
   - System must display world map with countries in muted/grey state initially
   - System must "reveal" countries in vibrant colors when user logs dive there
   - System must show dive pins on map for each logged location
   - System must animate the "scratching off" effect when new country is revealed

2.2. **Map Interactions**
   - System must allow tap on country to show:
     - Number of dives in that country
     - Date range of visits
     - List of dive sites visited
     - Best dive highlights
   - System must allow tap on individual pins to show dive summary
   - System must support pinch-to-zoom for detailed exploration
   - System must show heat map overlay option for dive frequency

2.3. **Progress Tracking**
   - System must display country count prominently (e.g., "14 of 195 countries explored")
   - System must show percentage of world explored
   - System must highlight "next closest" unexplored dive destinations

### 3. Gamification & Achievements

3.1. **Progress Metrics**
   - System must track and display:
     - Total dives logged
     - Countries explored
     - Species spotted
     - Total bottom time
     - Deepest dive
     - Logging streak

3.2. **Achievement System**
   - System must award badges for:
     - Country milestones (5, 10, 25, 50+ countries)
     - Dive count milestones (10, 25, 50, 100, 250, 500, 1000)
     - Species collection milestones
     - Fast logging (within 30 minutes of dive)
     - Logging streaks (7, 30, 90 days)

3.3. **Delightful Moments**
   - System must celebrate fast logging with animations/sounds
   - System must show "New Country!" celebration when scratching off new area
   - System must provide encouraging messages for consistent logging
   - System must show comparative stats ("Faster than 90% of divers!")

### 4. Social & Community Features

4.1. **Location-Based Discovery**
   - System must show "Recent divers at this site" when at dive location
   - System must allow users to see anonymized dive conditions from last 7 days
   - System must enable "diving now" status for real-time connections

4.2. **Collaborative Intelligence**
   - System must aggregate community data to improve auto-fill accuracy
   - System must show "Most spotted species" at each site
   - System must display "Best conditions" recommendations based on community data

4.3. **Sharing**
   - System must allow sharing of scratch-off map progress
   - System must generate beautiful dive summary cards for social sharing
   - System must create yearly recap visualizations

### 5. Instructor/Shop Integration

5.1. **Digital Sign-Off**
   - System must generate QR codes for dive verification
   - System must allow instructors to digitally sign student dives
   - System must maintain tamper-proof verification records

5.2. **Certification Tracking**
   - System must track user's certification levels
   - System must allow upload/verification of certification cards
   - System must show certification requirements progress

### 6. Data & Sync

6.1. **Offline Capability**
   - System must work fully offline with local data storage
   - System must queue all actions for sync when connected
   - System must handle conflict resolution for offline edits

6.2. **Cross-Platform Sync**
   - System must sync between iOS app and web viewer
   - System must maintain data consistency across devices
   - System must sync with Apple Health for relevant metrics

### 7. Intelligent Reminders

7.1. **Smart Notifications**
   - System must detect dive completion (left dive site after 30+ minutes)
   - System must send gentle reminder to log dive
   - System must learn user's logging habits and optimize timing
   - System must use playful language ("Don't let that dive swim away!")

7.2. **Streak Maintenance**
   - System must remind users about maintaining logging streaks
   - System must celebrate streak milestones

### 8. Web Viewer

8.1. **Read-Only Access**
   - System must provide web viewer for dive history
   - System must display scratch-off map on web
   - System must allow sharing of public profile/map

8.2. **Planning Tools**
   - System must show dive sites on web for trip planning
   - System must display conditions and community insights

## Non-Goals (Out of Scope for MVP)

1. **Will NOT include** dive planning or decompression calculations
2. **Will NOT include** full social network features (comments, likes, follows)
3. **Will NOT include** dive shop booking or payment processing
4. **Will NOT include** detailed training curriculum or course management
5. **Will NOT include** equipment marketplace or trading
6. **Will NOT include** live diving tracking or emergency features
7. **Will NOT include** Android native app (web viewer only)

## Design Considerations

### Visual Design Philosophy
- **Professional base** with clean, trustworthy interface that serious divers respect
- **Playful moments** during celebrations, achievements, and progress tracking
- **Map-centric** navigation with the scratch-off map as the hero feature
- **Delightful micro-interactions** for common actions (logging, revealing countries)
- **Vibrant color reveals** contrasting with muted unexplored areas

### UI Components
- **Quick-log floating action button** always accessible
- **Map as home screen** with overlay stats
- **Gesture-based interactions** for natural map exploration
- **Card-based dive summaries** with swipe actions
- **Progress rings** for visual goal tracking

### Mobile-First Design
- **Thumb-friendly** tap targets for one-handed use
- **Voice input** option for hands-free logging
- **Minimal required fields** with smart defaults
- **Progressive disclosure** for advanced options

## Technical Considerations

### Architecture
- **Offline-first** architecture with SQLite/GRDB
- **CloudKit** for sync (privacy-focused, no custom backend)
- **MapKit** for native map rendering
- **Core Location** for geofencing
- **EventKit** for calendar integration

### Integrations Priority
1. **Weather/Ocean APIs** (Critical)
   - OpenWeather Marine API
   - NOAA Tides & Currents
   - Stormglass.io for conditions
2. **Apple HealthKit** (Important)
   - Sync relevant health metrics
   - Read workout data if available
3. **Photo Libraries** (Important)
   - Auto-attach photos from dive day
   - EXIF data for time matching
4. **Dive Computers** (Nice-to-have)
   - Bluetooth LE for compatible devices
   - Manual file import as fallback

### Performance Requirements
- **Instant map interactions** (<100ms response)
- **Quick launch** (<2 seconds to interactive map)
- **Smooth animations** (60fps for scratch-off effect)
- **Minimal battery drain** for geofencing

### Data Privacy
- **User-owned data** with full export capability
- **End-to-end encryption** for sensitive information
- **Anonymous aggregation** for community features
- **GDPR compliant** data handling

## Success Metrics

### Primary KPIs
1. **Quick Logging Rate**: 70% of dives logged within 1 hour
2. **User Retention**: 60% of users active after 10 dives
3. **Yearly Retention**: 40% of users log at least 1 dive after 1 year

### Secondary Metrics
1. **Average Time to Log**: <30 seconds for repeat sites
2. **Map Engagement**: Users view map 3+ times per week
3. **Country Progress**: Average 3+ countries per active user
4. **Social Sharing**: 20% of users share map or achievements
5. **Auto-fill Accuracy**: 80% of auto-filled data accepted without changes

### Engagement Metrics
1. **Logging Streaks**: 30% maintain 7+ day streaks
2. **Achievement Completion**: 50% earn 5+ badges
3. **Community Contribution**: 25% contribute to collaborative data

## Open Questions

1. **Privacy Balance**: How much location data sharing is acceptable for community features?
2. **Gamification Depth**: Should we add competitive leaderboards or keep it personal?
3. **Free vs Premium**: What features (if any) should be premium?
4. **API Costs**: How to manage weather/ocean API costs at scale?
5. **Verification Standards**: How strict should instructor verification be?
6. **Data Retention**: How long to keep detailed location history?
7. **Watch App Scope**: Full logging on watch or just quick capture?
8. **Offline Maps**: Should we support offline map downloads for remote locations?

## Appendix: User Personas

### Primary: Casual Vacation Diver (Sarah)
- Dives 5-10 times per year on vacation
- Often forgets to log dives after the trip
- Loves sharing travel experiences on social media
- Motivated by visual progress and achievements

### Primary: Active Enthusiast (Mike)
- Dives 20-50 times per year
- Travels specifically for diving
- Wants to track everywhere he's been
- Enjoys comparing stats with other divers

### Secondary: New Diver (Alex)
- Recently certified, building experience
- Needs to log dives for advanced certification
- Excited about the sport, highly engaged
- Looking for community and guidance

### Future: Dive Instructor (Carlos)
- Logs 100+ dives per year
- Needs efficient student verification
- Wants to promote his dive shop
- Values professional tools that save time

---

*Last Updated: October 7, 2024*
*Version: 1.0.0*