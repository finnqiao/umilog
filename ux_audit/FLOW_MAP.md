# UmiLog Flow Map

**Audit Date:** 2026-01-02
**Commit:** 54c299be769cda266bde198760391357f2292fcd
**Build:** Xcode 16, iOS 18.6, iPhone 16 Pro Simulator

---

## Surface Catalog

### Primary Screens (Tab Navigation)

| ID | Name | Type | Entry | Exit | Preconditions | Purpose |
|----|------|------|-------|------|---------------|---------|
| S001 | Map (NewMapView) | Screen | Tab.map | Tab switch | DB seeded | Explore dive sites on interactive map |
| S002 | History (DiveHistoryView) | Screen | Tab.history | Tab switch | DB seeded | View logged dives chronologically |
| S003 | Wildlife (WildlifeView) | Screen | Tab.wildlife | Tab switch | DB seeded | Browse and search species catalog |
| S004 | Profile (ProfileView) | Screen | Tab.profile | Tab switch | DB seeded | View stats, achievements, settings |

### Map Bottom Surface Modes

| ID | Name | Type | Entry | Exit | Preconditions | Purpose |
|----|------|------|-------|------|---------------|---------|
| S010 | ExploreContent | Surface Mode | Default mode | Mode change | On Map tab | Browse sites with hierarchy navigation |
| S011 | InspectContent | Surface Mode | Tap site pin/card | Swipe down, back | Site selected | View site details and actions |
| S012 | FilterContent | Surface Mode | Filter button | Apply/Cancel | In Explore mode | Set site filters (difficulty, type) |
| S013 | SearchContent | Surface Mode | Search button | Select/Dismiss | On Map tab | Search sites, regions, areas, species |
| S014 | PlanContent | Surface Mode | Plan button | Close | In Inspect mode | Trip planning (Coming Soon) |

### Modal Sheets

| ID | Name | Type | Entry | Exit | Preconditions | Purpose |
|----|------|------|-------|------|---------------|---------|
| S020 | LogLauncherView | Sheet (.medium/.large) | Tab.log (FAB) | Dismiss/Select | None | Choose Quick Log or Live Log |
| S021 | LiveLogWizardView | Sheet (Full) | "Start Live Log" | Save/Cancel | Site optional | 4-step dive logging wizard |
| S022 | QuickLogView | Sheet (Full) | "Quick Log" | Save/Cancel | None | Fast single-form dive logging |
| S023 | SitePickerView | Sheet (Full) | Site selection button | Select/Cancel | In log flow | Search and select dive site |
| S024 | CreateSiteFromGPSView | Sheet (Full) | GPS dive saved | Save/Cancel | GPS coords available | Create new site from GPS |

### Navigation Stack Destinations

| ID | Name | Type | Entry | Exit | Preconditions | Purpose |
|----|------|------|-------|------|---------------|---------|
| S030 | DiveDetailView | Pushed | Tap dive row | Back | Dive exists | View full dive details |
| S031 | SpeciesDetailView | Pushed | Tap species card | Back | Species exists | View species info, sightings, habitats |
| S032 | DashboardView | Pushed | Profile menu | Back | None | Dashboard with stats overview |
| S033 | SiteExplorerView | Pushed | Profile menu | Back | None | List-based site browser |
| S034 | SettingsView | Pushed | Profile menu | Back | None | App settings and data management |
| S035 | PrivacySettingsView | Pushed | Settings | Back | None | Privacy toggles |
| S036 | SyncSettingsView | Pushed | Settings | Back | None | iCloud sync settings |
| S037 | PendingSitesView | Pushed | Settings | Back | None | Manage dives without site assignment |

### Overlay Components

| ID | Name | Type | Entry | Exit | Preconditions | Purpose |
|----|------|------|-------|------|---------------|---------|
| S040 | SiteCalloutCard | Overlay | Tap map pin | Dismiss/View Details | Site tapped | Quick preview with actions |
| S041 | FeaturedDestinationCard | Overlay | First launch | Dismiss | First-time user | Highlight featured destination |
| S042 | ProximityPromptCard | Overlay | Enter geofence | Accept/Dismiss | At dive site, permissions | Prompt to start logging |
| S043 | ContextLabel | Overlay | Always (Map) | N/A | On Map tab | Show mode status and site count |
| S044 | MinimalSearchButton | Overlay | Always (Map) | Opens Search | On Map tab | Quick access to search |

### Loading/Transition States

| ID | Name | Type | Entry | Exit | Preconditions | Purpose |
|----|------|------|-------|------|---------------|---------|
| S050 | SeedingLoadingView | Screen | App launch | DB seeded | First launch | Show loading while DB seeds |

---

## State Dimensions

### 1. Data State
| Dimension | How to Toggle | Affected Flows |
|-----------|--------------|----------------|
| Fresh install (no data) | Delete app + reinstall | All flows show empty states |
| Existing dives | Log dives | History, Profile stats, Wildlife sightings |
| Saved/wishlist sites | Toggle wishlist | Map pins, My Sites filter |

### 2. Permission States
| Dimension | How to Toggle | Affected Flows |
|-----------|--------------|----------------|
| Location: Not Determined | Fresh install | GPS logging, proximity prompts |
| Location: When In Use | Grant permission | GPS logging works, geofencing active |
| Location: Denied | Deny in Settings | GPS logging shows alert, no proximity |

### 3. Environment States
| Dimension | How to Toggle | Affected Flows |
|-----------|--------------|----------------|
| Network: Online | Default | All flows work normally |
| Network: Offline | Airplane mode | DB works locally, no sync |
| Dark Mode | System Settings | Map uses dark style always |
| Light Mode | System Settings | UI respects system theme |

### 4. App Configuration
| Dimension | How to Toggle | Affected Flows |
|-----------|--------------|----------------|
| Underwater Theme: On | Profile > Developer | Watery transitions enabled |
| Underwater Theme: Off | Profile > Developer | Standard iOS transitions |
| Reduce Motion: On | Accessibility Settings | Animations disabled |

### 5. Feature States
| Dimension | How to Toggle | Affected Flows |
|-----------|--------------|----------------|
| First-time user | Delete UserDefaults | Featured destination shown |
| Returning user | Normal use | Map restores last position |

---

## Navigation Graph

### Entry Points
- **E000**: App Launch → S050 (Seeding) → S001 (Map)
- **E001**: Tab Bar → S001/S002/S003/S004
- **E002**: FAB (Tab.log) → S020 (LogLauncher)
- **E003**: Notification (geofence) → App foreground → S042
- **E004**: Deep link → Not implemented

### Navigation Edges

```
Tab Navigation (E100-E104)
━━━━━━━━━━━━━━━━━━━━━━━━━
E100: Any Tab ──tap──► S001 (Map)
E101: Any Tab ──tap──► S002 (History)
E102: Any Tab ──tap──► S020 (LogLauncher) [intercepts Tab.log]
E103: Any Tab ──tap──► S003 (Wildlife)
E104: Any Tab ──tap──► S004 (Profile)

Map Surface State Machine (E200-E215)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
E200: S010 (Explore) ──tap pin──► S040 (Callout)
E201: S040 (Callout) ──"View Details"──► S011 (Inspect)
E202: S040 (Callout) ──"Log Dive"──► S021 (LiveLogWizard)
E203: S040 (Callout) ──dismiss/pan──► S010 (Explore)
E204: S010 (Explore) ──tap site card──► S011 (Inspect)
E205: S011 (Inspect) ──swipe down──► S010 (Explore)
E206: S011 (Inspect) ──"Start Dive"──► S021 (LiveLogWizard)
E207: S010 (Explore) ──filter button──► S012 (Filter)
E208: S012 (Filter) ──apply/cancel──► S010 (Explore)
E209: S010/S011 ──search button──► S013 (Search)
E210: S013 (Search) ──select site──► S011 (Inspect)
E211: S013 (Search) ──select region/area──► S010 (Explore, drilled)
E212: S013 (Search) ──select species──► S010 (Explore, filtered)
E213: S013 (Search) ──dismiss──► Previous mode
E214: S011 (Inspect) ──"Plan Trip"──► Coming Soon toast
E215: S010 (Explore) ──breadcrumb tap──► S010 (Navigate up hierarchy)

Dive Logging Flows (E300-E320)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
E300: S020 (LogLauncher) ──"Quick Log"──► S022 (QuickLog)
E301: S020 (LogLauncher) ──"Start Live Log"──► S021 (LiveLogWizard)
E302: S020 (LogLauncher) ──close──► S001 (Map)
E303: S022 (QuickLog) ──site button──► S023 (SitePicker)
E304: S023 (SitePicker) ──select site──► S022 (QuickLog)
E305: S023 (SitePicker) ──"Use GPS"──► S022 (QuickLog, GPS mode)
E306: S022 (QuickLog) ──save (known site)──► Dismiss → S002 (History)
E307: S022 (QuickLog) ──save (GPS only)──► S024 (CreateSite)
E308: S024 (CreateSite) ──save──► Dismiss all
E309: S021 (Wizard Step 1) ──site button──► S023 (SitePicker)
E310: S021 (Wizard) ──Continue──► Next step
E311: S021 (Wizard) ──Back──► Previous step
E312: S021 (Wizard Step 4) ──Save──► Dismiss → S002 (History)

History Flows (E400-E410)
━━━━━━━━━━━━━━━━━━━━━━━━
E400: S002 (History) ──tap dive──► S030 (DiveDetail)
E401: S030 (DiveDetail) ──back──► S002 (History)
E402: S002 (History) ──swipe delete──► Delete confirmation
E403: S002 (History) ──pull refresh──► Reload data
E404: S002 (History) ──search──► Filter list
E405: S002 (History, empty) ──"Start Logging"──► S020 (LogLauncher)

Wildlife Flows (E500-E510)
━━━━━━━━━━━━━━━━━━━━━━━━━
E500: S003 (Wildlife) ──tap species──► S031 (SpeciesDetail)
E501: S031 (SpeciesDetail) ──back──► S003 (Wildlife)
E502: S003 (Wildlife) ──scope chip "All-time"──► Show all species
E503: S003 (Wildlife) ──scope chip "This area"──► Filter to viewport
E504: S003 (Wildlife) ──search──► Filter species list

Profile Flows (E600-E620)
━━━━━━━━━━━━━━━━━━━━━━━━
E600: S004 (Profile) ──menu > Dashboard──► S032 (Dashboard)
E601: S004 (Profile) ──menu > Site Explorer──► S033 (SiteExplorer)
E602: S004 (Profile) ──menu > Settings──► S034 (Settings)
E603: S034 (Settings) ──Privacy Settings──► S035 (Privacy)
E604: S034 (Settings) ──Sync──► S036 (Sync)
E605: S034 (Settings) ──Pending Locations──► S037 (PendingSites)
E606: S034 (Settings) ──Export Data──► Share sheet
E607: S034 (Settings) ──Import Data──► File picker
E608: S004 (Profile) ──"Export All Data"──► Share sheet (placeholder)
E609: S004 (Profile) ──action rows──► Placeholder (no navigation)

Contextual/Ambient Flows (E700-E710)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
E700: Geofence trigger ──proximity──► S042 (ProximityPrompt)
E701: S042 (ProximityPrompt) ──"Start Dive"──► S021 (LiveLogWizard)
E702: S042 (ProximityPrompt) ──dismiss──► Hide
E703: First launch ──featured destination──► S041 (FeaturedCard)
E704: S041 (FeaturedCard) ──dismiss/pan──► Hide, complete experience
E705: Dive saved notification ──post──► Tab switch to S002 (History)
```

---

## Gated/Unreached Surfaces

### Feature-Gated
| Surface | Gate | Status | How to Enable |
|---------|------|--------|---------------|
| PlanContent (S014) | Coming Soon | Placeholder | Await implementation |
| Deep Links | Not implemented | Missing | Await implementation |
| Apple Watch | Not implemented | UI only | Await implementation |
| CSV/UDDF Import | Not implemented | UI only | Await implementation |
| Backfill Past Dives | Not implemented | UI only | Await implementation |

### Permission-Gated
| Surface | Gate | Status | How to Enable |
|---------|------|--------|---------------|
| ProximityPromptCard | Location permission | Conditional | Grant location access |
| GPS in QuickLog | Location permission | Conditional | Grant location access |
| CreateSiteFromGPSView | Location + GPS dive | Conditional | Use GPS, save dive |

### Data-Gated
| Surface | Gate | Status | How to Enable |
|---------|------|--------|---------------|
| DiveDetailView | Logged dives exist | Conditional | Log a dive |
| SpeciesDetailView sightings | Species sighted | Conditional | Log dive with species |
| PendingSitesView content | GPS dives without sites | Conditional | Log GPS dive, skip site |

---

## Hierarchy Navigation (Map Explore Mode)

```
World Level (.world)
    │
    ├─── Tap region cluster ──► Region Level (.region(id))
    │                               │
    │                               ├─── Tap area row ──► Area Level (.area(regionId, areaId))
    │                               │                          │
    │                               │                          └─── Sites list shown
    │                               │
    │                               └─── Breadcrumb tap ──► World Level
    │
    └─── Search select region ──► Region Level (.region(id))

Country Level (.country(id)) [via search]
    │
    └─── Auto-zoom to country bounds
```

---

## Surface Detent Behavior

| Mode | Allowed Detents | Default | Behavior |
|------|-----------------|---------|----------|
| Explore | peek, medium, expanded | peek | Drag to expand |
| Inspect | peek, medium, expanded | medium | Swipe down to dismiss at peek |
| Filter | expanded | expanded | Full screen filter UI |
| Search | expanded | expanded | Keyboard focus on appear |
| Plan | medium, expanded | medium | Coming Soon |

---

## Back Edge Behavior (State Preservation)

| From | To | State Preserved |
|------|----|-----------------|
| DiveDetail | History | Scroll position |
| SpeciesDetail | Wildlife | Scroll position, search, scope |
| Inspect Mode | Explore Mode | Hierarchy level, filters |
| Search Mode | Previous Mode | Hierarchy, filters |
| Filter Mode | Explore Mode | Filters applied (if Apply) |
| Settings children | Settings | All state |
| Any modal | Parent | Parent state unchanged |
