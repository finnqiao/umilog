# 14. Map Control Thumb-Zone Audit

**Priority**: Tier 4 — Polish
**Estimated Complexity**: Low
**Modules**: `FeatureMap`, `DiveMap`
**Migration**: None

---

## Problem

Map controls (zoom, layer toggle, locate-me, search) should be in the "thumb zone" — the bottom half of the screen reachable with one hand. Top-positioned controls require stretching and are a common UX complaint on large phones.

## Current State

- Bottom sheets with snap points are well-implemented ✅
- Tab bar with Log FAB is in the thumb zone ✅
- Map overlay controls (zoom, locate, layer toggle) positioning needs audit
- MapLibre default controls (compass, attribution, scale) are top-positioned by default

## Implementation Plan

### Step 1: Inventory All Map Controls

List every interactive element overlaying the map and its current position:

| Control | Current Position | Target Position | Size |
|---------|-----------------|-----------------|------|
| Locate Me | ? | Bottom-right, above bottom sheet | 44pt |
| Layer Toggle | ? | Bottom-right, above Locate Me | 44pt |
| Zoom In/Out | ? | Remove (pinch zoom sufficient) or bottom-right | 44pt |
| Compass | Top-right (MapLibre default) | Keep top-right (only shown when rotated) | 44pt |
| Search | ? | Top (accessible via pull-down on bottom sheet) | 44pt |
| Filter | ? | Bottom sheet content | 44pt |
| Attribution | Bottom-left (MapLibre default) | Keep bottom-left (legal) | - |

### Step 2: Reposition Controls

Target layout:
```
┌─────────────────────────────────┐
│                           🧭    │  ← Compass (only when rotated)
│                                 │
│                                 │
│         [Map Content]           │
│                                 │
│                                 │
│                          ┌───┐  │
│                          │ 🗺️│  │  ← Layer toggle
│                          ├───┤  │
│                          │ 📍│  │  ← Locate me
│                          └───┘  │
│ ┌─────────────────────────────┐ │
│ │      Bottom Sheet           │ │  ← Search, filter, site info
│ └─────────────────────────────┘ │
│ [Map] [History] [+] [🐟] [👤]  │  ← Tab bar
└─────────────────────────────────┘
```

```swift
// DiveMap/MapVC.swift or FeatureMap overlay
struct MapControlCluster: View {
    let onLocateMe: () -> Void
    let onLayerToggle: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Layer toggle
            Button(action: onLayerToggle) {
                Image(systemName: "map")
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Locate me
            Button(action: onLocateMe) {
                Image(systemName: "location.fill")
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .accessibilityElement(children: .contain)
    }
}
```

Position the cluster in the bottom-right, above the bottom sheet's peek height:

```swift
.overlay(alignment: .bottomTrailing) {
    MapControlCluster(...)
        .padding(.trailing, 16)
        .padding(.bottom, bottomSheetPeekHeight + 16)
}
```

### Step 3: Ensure 44pt Minimum Tap Targets

Audit every interactive element:

```swift
// All buttons must meet minimum size
.frame(minWidth: 44, minHeight: 44)
// Add content shape for expanded hit area on smaller visual elements
.contentShape(Rectangle())
```

### Step 4: Test Reachability

Test on the full device range:

| Device | Screen | Thumb reach from bottom-right |
|--------|--------|------------------------------|
| iPhone SE (3rd gen) | 4.7" | Full screen reachable |
| iPhone 14/15 | 6.1" | Bottom 2/3 comfortable |
| iPhone 14/15 Plus | 6.7" | Bottom 1/2 comfortable |
| iPhone 14/15 Pro Max | 6.7" | Bottom 1/2 comfortable |

Controls should be in the comfortable zone for 6.7" devices.

### Step 5: Validate One-Handed Usage

Run through these tasks using only one hand (thumb):
1. Open app → view map → locate me → works ✅
2. Tap a site pin → read info in bottom sheet → works ✅
3. Switch map layer → works ✅
4. Start logging a dive (FAB) → works ✅
5. Search for a site → pull up bottom sheet → works ✅
6. Filter sites → bottom sheet content → works ✅

## Testing

- [ ] All controls meet 44pt minimum tap target
- [ ] Locate Me button is reachable with thumb on 6.7" phone
- [ ] Layer toggle is reachable with thumb on 6.7" phone
- [ ] Controls don't overlap with bottom sheet in any detent
- [ ] Controls visible against all map styles (vector, raster, satellite)
- [ ] Controls don't obstruct map annotations
- [ ] VoiceOver can access all controls
- [ ] Dynamic Type doesn't break control layout

## Risks

- **Bottom sheet overlap**: Controls must dynamically adjust position based on bottom sheet detent. When sheet is at half-height, controls need to be above it
- **Landscape mode**: If landscape is supported, thumb zones shift. Audit separately
- **Accessibility**: Reachability mode (iOS swipe-down gesture) may interfere. Verify controls work with it enabled
