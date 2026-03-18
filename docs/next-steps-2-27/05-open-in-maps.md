# 5. "Open in Maps" Navigation

**Priority**: Tier 2 — Trivial to implement, solves real need
**Estimated Complexity**: Low
**Modules**: `FeatureMap` (UI), `UmiLocationKit` (optional helper)
**Migration**: None

---

## Problem

UmiLog stores GPS coordinates for all 1,120 sites but provides no way to navigate to them. Divers need directions to shore entry points or boat departure marinas.

## Current State

- Every `DiveSite` has `latitude`, `longitude`
- `SiteFacet` has `entryModes` (boat, shore, liveaboard) — determines navigation context
- Site detail cards (`InspectContent`) show location info but no navigation action
- `UmiLocationKit` has distance calculation helpers
- No Apple Maps integration

## Implementation Plan

### Step 1: Navigation Helper

```swift
// UmiLocationKit/Navigation/SiteNavigationService.swift
import MapKit

struct SiteNavigationService {
    /// Open Apple Maps with driving/walking directions to the site
    static func navigate(to site: DiveSite, entryMode: String? = nil) {
        let coordinate = CLLocationCoordinate2D(
            latitude: site.latitude,
            longitude: site.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = site.name

        var launchOptions: [String: Any] = [:]

        // Shore dives → walking directions (entry point is walkable)
        // Boat dives → driving directions (to marina/harbor)
        if entryMode == "shore" {
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeWalking
        } else {
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeDriving
        }

        mapItem.openInMaps(launchOptions: launchOptions)
    }

    /// Copy coordinates to clipboard
    static func copyCoordinates(of site: DiveSite) {
        let text = String(format: "%.6f, %.6f", site.latitude, site.longitude)
        UIPasteboard.general.string = text
    }

    /// Generate a shareable Google Maps URL (for cross-platform sharing)
    static func shareURL(for site: DiveSite) -> URL? {
        let urlString = String(
            format: "https://maps.apple.com/?ll=%.6f,%.6f&q=%@",
            site.latitude, site.longitude,
            site.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? site.name
        )
        return URL(string: urlString)
    }
}
```

### Step 2: Add Navigate Button to Site Detail Card

In the existing site inspect view, add a navigation action:

```
┌─ Blue Hole · Dahab ─────────────┐
│ ★★★★☆  Advanced  ·  Shore       │
│ Max 130m  ·  Vis 30m  ·  26°C   │
│                                 │
│ [🧭 Navigate]  [📋 Copy GPS]    │
│                                 │
│ Description...                  │
└─────────────────────────────────┘
```

Add to the existing `InspectContent` or site detail view:
```swift
// In site detail action bar
HStack(spacing: 12) {
    Button {
        let entryMode = site.facet?.entryModes.first
        SiteNavigationService.navigate(to: site, entryMode: entryMode)
    } label: {
        Label("Navigate", systemImage: "location.fill")
    }
    .buttonStyle(.bordered)

    Button {
        SiteNavigationService.copyCoordinates(of: site)
        Haptics.success()
    } label: {
        Label("Copy GPS", systemImage: "doc.on.doc")
    }
    .buttonStyle(.bordered)
}
```

### Step 3: Context Menu Action

Also add as a context menu option on site list rows and map annotations:

```swift
.contextMenu {
    Button {
        SiteNavigationService.navigate(to: site)
    } label: {
        Label("Open in Maps", systemImage: "map")
    }

    Button {
        SiteNavigationService.copyCoordinates(of: site)
    } label: {
        Label("Copy Coordinates", systemImage: "doc.on.doc")
    }

    if let url = SiteNavigationService.shareURL(for: site) {
        ShareLink(item: url) {
            Label("Share Location", systemImage: "square.and.arrow.up")
        }
    }
}
```

### Step 4: Entry Mode Context

Use the existing `entryModes` from `SiteFacet` to provide smarter directions:

| Entry Mode | Directions Type | Note |
|-----------|----------------|------|
| `shore` | Walking | Navigate to entry point |
| `boat` | Driving | Navigate to nearest dive shop/marina |
| `liveaboard` | Driving | Navigate to departure port |
| Unknown | Driving (default) | General directions |

For boat dives, if `DiveShop` records are linked to the site, offer to navigate to the shop instead of the dive site GPS (which is in the water).

## Testing

- [ ] Tap Navigate on a shore dive → Apple Maps opens with walking directions
- [ ] Tap Navigate on a boat dive → Apple Maps opens with driving directions
- [ ] Copy GPS → paste in notes app, verify format
- [ ] Context menu on site list row → "Open in Maps" works
- [ ] Test with site that has no facet data (falls back to driving)
- [ ] Test coordinate formatting for negative lat/lon (southern/western hemisphere)

## Future Enhancements

- Navigate to linked dive shop for boat dives
- In-app route preview (MapKit directions overlay)
- Estimated travel time display on site card
- Offline coordinate display with compass bearing from current location
