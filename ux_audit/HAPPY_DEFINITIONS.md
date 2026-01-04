# UmiLog Happy Definitions

**Audit Date:** 2026-01-02
**Standard:** Each flow defines expected "happy path" behavior based on iOS best practices (Apple Maps, AllTrails, Strava patterns).

---

## F001 - First Launch Experience

### A) User Intent
New user opens UmiLog for the first time and wants to understand what the app offers.

### B) Preconditions
- Fresh install, no UserDefaults
- Database not yet seeded
- Location permission: Not Determined

### C) Happy Path Steps
1. Launch app → S050 (SeedingLoadingView)
2. See branded loading screen with pulse animation, "Loading dive sites..."
3. Wait < 3 seconds (target) for database seeding
4. Transition to S001 (Map) with featured destination animation
5. S041 (FeaturedDestinationCard) appears at top
6. Map animates to featured location (e.g., Phuket)
7. User dismisses card or pans map
8. S010 (ExploreContent) shows at peek detent with site count

### D) Expected UX Behaviors [Documented]
- **Loading feedback**: Branded splash with progress indicator
- **First impression**: Fly-in animation to engaging destination
- **Discovery prompt**: Featured card explains destination significance
- **Map shows content**: Visible clusters/pins immediately after load

### E) Data Invariants
- Database seeded with 14,000+ sites
- Featured destination flag set after dismissal
- No location permission prompt until user action

### F) Happy Evidence Requirements
- Screenshot: Loading view renders (not white screen)
- Screenshot: Featured card with destination info
- Timing: Load to interactive < 3s
- Automation: XCUITest launch → wait for map pins

### G) Known Gaps
- **Implementation Gap**: White screen observed for 5-15s instead of loading view
- **Proposed**: Move seeding to background with proper loading UI

---

## F002 - Explore Sites on Map

### A) User Intent
User wants to discover dive sites in a geographic area using the map.

### B) Preconditions
- Database seeded
- On Map tab (S001)

### C) Happy Path Steps
1. Start at S001 (Map) in Explore mode (S010)
2. See world map with clustered pins (tan/cream circles)
3. Pan/zoom to region of interest
4. Clusters de-cluster into individual pins
5. Bottom surface shows updated site count ("Sites nearby: X")
6. Scroll site list in bottom surface
7. Tap site card → Surface expands to medium, map centers on site

### D) Expected UX Behaviors [Documented per Apple Maps]
- **Cluster tap**: Zooms into cluster bounds (not opens detail)
- **Pin tap**: Shows S040 (SiteCalloutCard) overlay
- **List tap**: Opens S011 (InspectContent)
- **Pan gesture**: Smooth 60fps, callout dismisses on pan
- **Surface drag**: Rubber-bands at detent limits
- **Back edge**: Returning from Inspect preserves scroll position

### E) Data Invariants
- Site count matches visible viewport
- Pins match list items
- Hierarchy breadcrumb reflects current drill-down

### F) Happy Evidence Requirements
- Manual: Pan map, verify cluster behavior
- Manual: Tap pin, verify callout appears
- XCUITest: Tap site row, verify InspectContent loads
- Dimension: Test with 0 sites in viewport (empty state)

### G) Known Gaps
- **P0 (Previous audit)**: Site cards/pins don't respond to taps - gesture conflict
- **Proposed**: Add `.contentShape(Rectangle())` and debug gesture recognizers

---

## F003 - Search for Dive Site

### A) User Intent
User wants to find a specific dive site by name or location.

### B) Preconditions
- Database seeded
- On Map tab

### C) Happy Path Steps
1. Tap S044 (MinimalSearchButton) in top-right
2. → S013 (SearchContent) opens, surface expands
3. Keyboard appears, search field focused
4. Type query (e.g., "Similan")
5. Hierarchical results appear: Countries → Regions → Areas → Sites → Species
6. Sections expandable/collapsible
7. Tap site result
8. → Dismiss keyboard
9. → S011 (InspectContent) opens, map centers on site

### D) Expected UX Behaviors [Documented]
- **Keyboard focus**: Immediate on appear (0.3s delay for animation)
- **Results update**: As-you-type, debounced
- **Clear button**: "X" clears query
- **Section collapse**: Tap header to toggle
- **Distance shown**: If location granted, show km to site

### E) Data Invariants
- Results match query substring
- Site type filters apply to results
- Selecting site sets selectedSiteIdForScroll

### F) Happy Evidence Requirements
- Manual: Tap search button, verify focus
- Manual: Type query, verify results appear
- XCUITest: Search "coral", select site, verify map moves
- Dimension: Test with no results (empty state)

### G) Known Gaps
- **P0 (Previous audit)**: Search button non-responsive - hit-test blocking
- **Implemented Fix**: Added explicit tap target (44x44) and contentShape

---

## F004 - Quick Log a Dive

### A) User Intent
User just finished a dive and wants to log it quickly without detailed wizard.

### B) Preconditions
- Any state
- Optionally: Location permission for GPS

### C) Happy Path Steps
1. Tap Tab.log (FAB) → S020 (LogLauncherView) sheet
2. See options: "Quick Log" and "Start Live Log"
3. Tap "Quick Log" → S022 (QuickLogView) sheet
4. See quick actions: "Same as Last" (if previous dive), "Current Location"
5. Tap site button → S023 (SitePickerView)
6. Search/select site → Return to QuickLog
7. Enter max depth (quick buttons: 18m, 25m, 30m, 35m, 40m)
8. Enter bottom time (quick buttons: 30, 40, 45, 50, 60 min)
9. Optionally expand "More Details" for temp, visibility, notes
10. Tap "Log Dive" button
11. → Dive saved, sheet dismisses
12. → Tab switches to S002 (History)
13. New dive appears at top of list with "NEW" badge

### D) Expected UX Behaviors [Documented per Strava]
- **Smart defaults**: Pre-fill from last dive if available
- **GPS option**: "Use Current Location" if permission granted
- **Quick depth/time**: Tap preset buttons to fill fields
- **Validation**: Save button disabled until depth + time entered
- **Success feedback**: Haptic on save, navigate to History

### E) Data Invariants
- Dive saved with correct site_id
- visitedCount incremented on site
- wishlist cleared if was set
- Notification posted (.diveLogSavedSuccessfully)

### F) Happy Evidence Requirements
- Manual: Complete full quick log flow
- XCUITest: Fill form, save, verify in History
- Dimension: Test with GPS-only dive (shows CreateSiteFromGPSView)

### G) Known Gaps
- **Documented**: "Same as Last" requires previous dive - empty state okay

---

## F005 - Live Log Wizard (4-Step)

### A) User Intent
User wants detailed dive logging with site selection, metrics, wildlife, and review.

### B) Preconditions
- Any state
- Optional: Pre-selected site (from map or proximity)

### C) Happy Path Steps
1. Enter via S020 "Start Live Log" OR S011 "Start Dive" OR S042 "Start Dive"
2. → S021 (LiveLogWizardView) opens with step 1
3. **Step 1 - Site & Timing**: Select site, set date/time
4. Tap site button → S023, select site, return
5. Tap "Continue" (enabled when site selected)
6. **Step 2 - Metrics**: Enter depth, bottom time, pressures, temp, visibility
7. Quick validation: depth > 0, time > 0 required
8. Tap "Continue"
9. **Step 3 - Wildlife & Notes**: Search species, tap chips to select, add notes
10. Tap "Continue"
11. **Step 4 - Review & Save**: See summary of all fields
12. Tap "Save" → Save operation
13. Success banner appears "Dive Logged Successfully!"
14. "View in History" button available
15. → Dismiss, navigate to History

### D) Expected UX Behaviors [Documented per Strava]
- **Progress bar**: StepperBar shows step X of 4
- **Back navigation**: "Back" returns to previous step, data preserved
- **Validation gates**: Can't proceed without required fields
- **Species search**: Chips are multi-select
- **Review shows all**: Complete summary before save

### E) Data Invariants
- Dive saved with all fields
- Sightings saved for selected species
- Site visitedCount incremented
- Navigation to History after save

### F) Happy Evidence Requirements
- Manual: Complete all 4 steps
- XCUITest: Step through wizard, verify each step
- Dimension: Test with pre-selected site (skips selection in step 1)

### G) Known Gaps
- **None identified**: Wizard flow appears well-implemented

---

## F006 - View Dive History

### A) User Intent
User wants to review their logged dives chronologically.

### B) Preconditions
- On History tab
- At least one dive logged (for full flow)

### C) Happy Path Steps
1. Tap Tab.history → S002 (DiveHistoryView)
2. See list of dives with site name, stats, date
3. Pull-to-refresh to reload
4. Use search bar to filter by site/notes
5. Tap dive row → S030 (DiveDetailView)
6. See full details: site, depth, time, temp, visibility, notes, instructor
7. Tap back → Return to list at same scroll position

### D) Expected UX Behaviors [Documented]
- **Pull-to-refresh**: Standard iOS refresh
- **Searchable**: Filter by site name, location, notes
- **Swipe-to-delete**: Trailing swipe shows delete action
- **NEW badge**: Shows for dives < 7 days old
- **Signed badge**: Rosette icon if instructor signed

### E) Data Invariants
- List sorted by date descending
- Delete removes from database
- Search filters client-side

### F) Happy Evidence Requirements
- Manual: Scroll list, pull refresh
- Manual: Search query, verify filtering
- XCUITest: Tap row, verify detail view
- Dimension: Test with 0 dives (empty state)

### G) Known Gaps
- **Empty state**: Has CTA "Start Logging" → opens LogLauncher (fixed per UX-013)

---

## F007 - Browse Wildlife Species

### A) User Intent
User wants to explore marine species catalog and see what they've spotted.

### B) Preconditions
- On Wildlife tab
- Species catalog seeded

### C) Happy Path Steps
1. Tap Tab.wildlife → S003 (WildlifeView)
2. See scope chips: "All-time" (default), "This area"
3. See species grid with images, names, sighting counts
4. Search to filter species
5. Tap species card → S031 (SpeciesDetailView)
6. See hero image, name, scientific name, quick facts
7. See "Your Sightings" if any
8. See "Where to Find" for known habitats
9. Tap back → Return to grid

### D) Expected UX Behaviors [Documented]
- **Scope toggle**: "This area" filters to current map viewport
- **Species image**: Shows category-colored fallback if no image
- **Sighting count**: "Seen Nx" badge if spotted
- **Grayscale hint**: Unseen species could be grayscale (Proposed)

### E) Data Invariants
- Species list from species_catalog
- Sightings from sightings table
- "This area" uses map viewport bounds

### F) Happy Evidence Requirements
- Manual: Toggle scope chips
- Manual: Search species
- XCUITest: Tap species, verify detail view
- Dimension: Test "This area" with no sightings

### G) Known Gaps
- **Proposed**: Empty state for "This area" with no sightings could suggest panning map

---

## F008 - View Profile & Stats

### A) User Intent
User wants to see their diving statistics and achievements.

### B) Preconditions
- On Profile tab

### C) Happy Path Steps
1. Tap Tab.profile → S004 (ProfileView)
2. See certification header (placeholder: "Advanced Open Water")
3. See stat tiles: Total Dives, Max Depth, Sites Visited, Species
4. See Total Bottom Time
5. See Achievements badges
6. See Cloud backup status
7. See "Get Started" action rows
8. Tap menu (ellipsis) → Options: Dashboard, Site Explorer, Settings
9. Select "Settings" → S034 (SettingsView)

### D) Expected UX Behaviors [Documented]
- **Stats tiles**: Real-time calculated from dive logs
- **Achievements**: Static for now, unlock logic future
- **Action rows**: Navigate to features/settings

### E) Data Invariants
- Stats match sum/max of dive_logs table
- Species count = unique species from sightings

### F) Happy Evidence Requirements
- Manual: Verify stats match logged dives
- Manual: Navigate to each menu item
- Dimension: Test with 0 dives (shows zeros)

### G) Known Gaps
- **Action rows**: Most are placeholder (Watch, Import, Backfill)
- **Export**: Works (generates JSON)

---

## F009 - Inspect Site Details

### A) User Intent
User wants to view details about a specific dive site.

### B) Preconditions
- Site selected (via map pin, search, or list)

### C) Happy Path Steps
1. Tap site (pin → callout → "View Details", OR list card)
2. → S011 (InspectContent) in medium detent
3. See site name, location, difficulty badge
4. See depth range, average temp, visibility
5. See site description if available
6. See "Start Dive" button
7. Optionally tap "Plan Trip" → Coming Soon toast
8. Swipe down or tap outside → Dismiss back to Explore

### D) Expected UX Behaviors [Documented per AllTrails]
- **Medium detent**: Shows key info without fullscreen
- **Expand to full**: Drag up for more details
- **Start Dive shortcut**: Quick access to logging
- **Map stays visible**: Can see site location above surface

### E) Data Invariants
- Site data from dive_sites table
- Wishlist state persists

### F) Happy Evidence Requirements
- Manual: Inspect site, verify all fields
- Manual: Tap "Start Dive", verify wizard with pre-selected site
- XCUITest: Navigate to InspectContent, verify title

### G) Known Gaps
- **P0**: Cannot reach InspectContent if tap doesn't work
- **Plan Trip**: Shows toast, feature not implemented

---

## F010 - Filter Dive Sites

### A) User Intent
User wants to narrow down visible sites by criteria.

### B) Preconditions
- On Map tab in Explore mode

### C) Happy Path Steps
1. Tap filter button in ExploreContent
2. → S012 (FilterContent), surface expands to full
3. See filter options: difficulty, site type, lens (logged, saved, planned)
4. Toggle desired filters
5. Tap "Apply" → Return to Explore with filters active
6. Site count updates, pins filter
7. Clear via "Clear filters" button

### D) Expected UX Behaviors [Documented]
- **Filter persistence**: Should persist across app restart (via MapStatePersistence)
- **Active indicator**: Badge shows filter count
- **Cancel**: Reverts to previous state

### E) Data Invariants
- Filters stored in ExploreFilters struct
- Applied via viewModel.applyFilters()

### F) Happy Evidence Requirements
- Manual: Set filters, verify list updates
- Manual: Restart app, verify filters persist
- Dimension: Set filter with 0 results (empty state)

### G) Known Gaps
- **P1 (Previous audit)**: Filters reset on restart - persistence not wired

---

## F011 - Proximity Dive Prompt (Geofencing)

### A) User Intent
User arrives at a dive site and wants to be prompted to log.

### B) Preconditions
- Location permission: When In Use or Always
- Notification permission (for background)
- User enters geofence of known dive site

### C) Happy Path Steps
1. User physically near dive site (simulated via location change)
2. GeofenceManager detects entry
3. → S042 (ProximityPromptCard) appears above bottom surface
4. Card shows site name, "You're here" indicator
5. Tap "Start Dive" → S021 (LiveLogWizard) with site pre-selected
6. OR tap dismiss → Card hides

### D) Expected UX Behaviors [Proposed - not fully tested]
- **Non-intrusive**: Card doesn't block map
- **Haptic**: Success haptic on accept
- **Auto-dismiss**: After timeout or user action

### E) Data Invariants
- Geofences registered for nearby sites
- Only triggers once per site visit

### F) Happy Evidence Requirements
- Manual: Simulate location in simulator
- Device test: Visit actual dive site

### G) Known Gaps
- **P1 (Previous audit)**: Geofencing wired but not fully tested
- **Blocked**: Requires real device testing

---

## F012 - Export Dive Data

### A) User Intent
User wants to backup or share their dive logs.

### B) Preconditions
- On Settings
- At least one dive logged

### C) Happy Path Steps
1. Navigate Profile → Menu → Settings → S034
2. Tap "Export Data" row
3. Loading indicator appears
4. → Share sheet opens with JSON file
5. Select destination (AirDrop, Files, email)
6. File saved/sent

### D) Expected UX Behaviors [Documented]
- **File format**: JSON with ISO8601 dates
- **Progress**: Spinner while generating
- **Share sheet**: Standard iOS share

### E) Data Invariants
- Export includes all dives
- File named with timestamp

### F) Happy Evidence Requirements
- Manual: Export, verify file contents
- Manual: Import on fresh install, verify dives appear

### G) Known Gaps
- **None**: Export/Import appears functional

---

## F013 - Create Site from GPS

### A) User Intent
User logged dive at new location, wants to create a site record.

### B) Preconditions
- Dive logged with GPS coordinates (no site selected)
- QuickLog flow completed

### C) Happy Path Steps
1. Complete QuickLog with "Use Current Location"
2. Save dive
3. → S024 (CreateSiteFromGPSView) sheet appears
4. Enter site name
5. Optionally enter details
6. Tap Save
7. Site created, dive linked
8. Sheet dismisses

### D) Expected UX Behaviors [Proposed]
- **GPS shown**: Display coordinates on form
- **Reverse geocode**: Suggest location name
- **Link dive**: Automatically associates saved dive

### E) Data Invariants
- New site in dive_sites
- Dive's siteId updated
- Site appears on map

### F) Happy Evidence Requirements
- Manual: Log GPS dive, create site
- Verify site appears on map

### G) Known Gaps
- **Undocumented**: Flow exists but not well-tested

---

## Summary: Happy Path Checklist

| Flow | Can Complete | Blockers |
|------|--------------|----------|
| F001 First Launch | Partial | White screen delay |
| F002 Explore Map | Blocked | Pin/card tap not working |
| F003 Search Site | Blocked | Search button not responsive |
| F004 Quick Log | Yes | Via tab FAB |
| F005 Live Log Wizard | Yes | Via tab FAB |
| F006 View History | Yes | Works |
| F007 Browse Wildlife | Yes | Works |
| F008 View Profile | Yes | Works |
| F009 Inspect Site | Blocked | Depends on tap working |
| F010 Filter Sites | Blocked | Depends on tap working |
| F011 Proximity Prompt | Untested | Needs device/location |
| F012 Export Data | Yes | Works |
| F013 Create Site GPS | Yes | Works |
