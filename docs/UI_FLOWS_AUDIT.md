# UI Flows Audit (2025-10-26)

Purpose: document the current functional UI flows, known issues, and incomplete areas for the iOS app. This is documentation-only; no code changes.

Legend
- Functional now: works today based on code paths
- Problems/Risks: known gaps, stubs, or UX risks
- Incomplete/Missing: not implemented or only partially implemented
- Key files: primary sources in this repo
- Next actions: documentation tasks now, future code tasks later (see TODO triage)
- Owner: placeholder (TBD)

1) Map (Discover / My Map)
Overview
- Map-first tab using MapLibre (DiveMap) with MapKit fallback; bottom sheet tiers Regions → Areas → Sites; search and filters sheets.
Functional now
- MapLibre rendering with clustering and viewport-driven refresh; MapKit fallback available.
- Bottom sheet navigation across regions/areas/sites with counts and chips.
- SearchSheet and FilterSheet present; basic search works; filter UI toggles update view model.
Problems/Risks
- Layers button toggles a flag; no layers panel implemented.
- Some filters are stubs (nearby/planned true-returns); filter state not persisted.
- User-location/permissions not wired; “nearby” behavior unspecified.
Incomplete/Missing
- Layers panel UX; full filter pipeline + persistence; location permission flow and user-location indicator.
Key files
- Modules/FeatureMap/Sources/NewMapView.swift
- Modules/FeatureMap/Sources/SiteDetailSheet.swift
- Modules/FeatureMap/Sources/MapClusterView.swift
- Modules/DiveMap/Sources/*
Next actions
- Spec Layers v1 (or hide), define filter persistence model, and document “nearby” behavior and permissions sequence. (See TODO: Triage P0/P1)
Owner: TBD

2) Site Detail Sheet
Overview
- Site summary/quick facts with primary CTA to log.
Functional now
- Displays site details from DB; “Log Dive at <site>” opens Live Log Wizard.
Problems/Risks
- “Add to Wishlist” is TODO; no error/empty-state for missing media.
Incomplete/Missing
- Wishlist persistence and share actions; media/gallery.
Key files
- Modules/FeatureMap/Sources/SiteDetailSheet.swift
Next actions
- Document wishlist UX + data link; add share/deep-link specs. (TODO: P2 Wishlist)
Owner: TBD

3) Search & Filters (Map)
Overview
- Sheets for site search and filter mode selection.
Functional now
- SearchSheet filters list by name/location; FilterSheet switches mode/status chips.
Problems/Risks
- Filter logic partially stubbed; no persistence; search indexing not formalized beyond basic LIKE.
Incomplete/Missing
- Full filter pipeline, saved filters, and FTS5-backed search strategy.
Key files
- Modules/FeatureMap/Sources/NewMapView.swift (integrations)
- Modules/FeatureMap/Sources/SearchSheet.swift
- Modules/FeatureMap/Sources/FilterSheet.swift
Next actions
- Specify filter fields + persistence; outline FTS strategy using SiteRepository. (TODO: P1)
Owner: TBD

4) History (Dive list + detail)
Overview
- Browse logged dives, search, and view details.
Functional now
- Dive list with searchable text; detail view with stats; manual refresh.
Problems/Risks
- No auto-refresh upon new log save (notification not observed).
Incomplete/Missing
- Sorting/filtering; edit/delete flows; richer empty states.
Key files
- Modules/FeatureHistory/Sources/DiveHistoryView.swift
- Modules/FeatureHistory/Sources/DiveHistoryViewModel.swift
Next actions
- Listen to .diveLogUpdated for live updates; spec sorting/filtering UX. (TODO: P0, P2)
Owner: TBD

5) Logging (Wizard + Quick Log)
Overview
- 4-step wizard (fast save after step 2); Quick Log one-screen flow.
Functional now
- Wizard saves dive + sightings, bumps site visitedCount, posts notification; center FAB presents wizard.
Problems/Risks
- Quick Log not exposed in tab entry; permission prompts (mic/location) not in a formal UX flow.
Incomplete/Missing
- Decide Quick Log entry point; unify success UX; permissions sequence and copy.
Key files
- Modules/FeatureLiveLog/Sources/LiveLogWizardView.swift
- Modules/FeatureLiveLog/Sources/QuickLogView.swift
- Modules/FeatureLiveLog/Sources/*ViewModel.swift
Next actions
- Decide Quick Log entry (spec); author permission UX. (TODO: P1 Quick Log, P0 Permissions)
Owner: TBD

6) Wildlife
Overview
- Wildlife tab/cards.
Functional now
- Placeholder grid renders mock cards.
Problems/Risks
- No data wiring to sightings/species; search does not reflect DB.
Incomplete/Missing
- Species index, filters, linkage to logged sightings, media.
Key files
- Modules/FeatureMap/Sources/WildlifeView.swift
Next actions
- Spec species index + filters; wire to SpeciesRepository and sightings. (TODO: P2)
Owner: TBD

7) Profile
Overview
- Stats tiles, achievements placeholders, developer toggles.
Functional now
- Static stats tiles; developer section shows Underwater Theme toggle control UI.
Problems/Risks
- Underwater Theme toggle uses environment binding not provided by root AppState; no persistence.
Incomplete/Missing
- Actual settings, backups/sync, theme persistence.
Key files
- Modules/FeatureMap/Sources/ProfileView.swift
- Modules/UmiDesignSystem/Sources/Underwater/UnderwaterTheme.swift
Next actions
- Define app-wide theme state/persistence; outline Profile/Settings IA. (TODO: P0 theme, P2 settings)
Owner: TBD

8) Underwater Theme (global)
Overview
- Thematic background (mesh gradient, caustics, bubbles) around content.
Functional now
- UnderwaterThemeView wraps content when appState.underwaterThemeEnabled.
Problems/Risks
- Profile’s toggle binding is not connected to AppState; no persistence implemented.
Incomplete/Missing
- Central theme state and storage; user-visible setting flow.
Key files
- UmiLog/UmiLogApp.swift
- Modules/UmiDesignSystem/Sources/Underwater/*
Next actions
- Document a shared theme binding on AppState and persistence (UserDefaults/Keychain). (TODO: P0)
Owner: TBD

9) Location & Geofencing
Overview
- Abstractions for location and geofence-based prompts.
Functional now
- LocationService and GeofenceManager services exist with APIs.
Problems/Risks
- Not integrated into app lifecycle; permissions not requested in flows; “nearby sites” filter is stubbed.
Incomplete/Missing
- Permission UX, lifecycle wiring, user-location display, geofence policy.
Key files
- Modules/UmiLocationKit/Sources/LocationService.swift
- Modules/UmiLocationKit/Sources/GeofenceManager.swift
Next actions
- Spec permission prompts/sequence; define geofence monitoring policy; plan “nearby” filter behavior. (TODO: P0/P1)
Owner: TBD

Appendix: Data/Seeding Context (for UI readiness)
- Database migrations v1/v3/v4 and seeding via DatabaseSeeder.seedIfNeeded() load optimized tiles (Resources/SeedData/optimized/tiles/*.json) with fallback to legacy seeds.
- SiteRepository/DiveRepository/SpeciesRepository provide current data access used by Map, History, and Wizard.
