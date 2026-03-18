# 6. Dive History Heat Map

**Priority**: Tier 2 — Leverages existing MapLibre infrastructure
**Estimated Complexity**: Medium
**Modules**: `DiveMap` (layer), `FeatureMap` (toggle UI)
**Migration**: None

---

## Problem

Divers want to visualize their personal dive history as a "heat map of experience" on the global map — seeing concentration of dives across regions at a glance, rather than browsing a flat list.

## Current State

- History tab exists with `DiveHistoryView` (list-based)
- Map has My Map / Explore segmented view
- `DiveLog` stores coordinates via `siteId` (→ site lat/lon) or `pendingLatitude`/`pendingLongitude`
- MapLibre supports heatmap layers natively
- No heat map or visual density layer

## Implementation Plan

### Step 1: Query Dive Coordinates

```swift
// UmiDB/Queries/DiveHeatmapQueries.swift
struct DiveHeatmapPoint {
    let latitude: Double
    let longitude: Double
    let diveCount: Int      // number of dives at this location
    let lastDiveDate: Date
}

extension AppDatabase {
    /// Fetch heatmap points grouped by site (or GPS coordinates for unmatched dives)
    func fetchHeatmapPoints() throws -> [DiveHeatmapPoint] {
        try dbWriter.read { db in
            // Site-linked dives: group by site coordinates
            let sitePoints = try Row.fetchAll(db, sql: """
                SELECT s.latitude, s.longitude, COUNT(*) as diveCount,
                       MAX(d.date) as lastDiveDate
                FROM dives d
                JOIN sites s ON d.siteId = s.id
                GROUP BY s.id
            """)

            // GPS-only dives: use pending coordinates
            let gpsPoints = try Row.fetchAll(db, sql: """
                SELECT pendingLatitude as latitude, pendingLongitude as longitude,
                       1 as diveCount, date as lastDiveDate
                FROM dives
                WHERE siteId IS NULL
                  AND pendingLatitude IS NOT NULL
            """)

            // Convert to DiveHeatmapPoint array
            ...
        }
    }
}
```

### Step 2: MapLibre Heatmap Layer

```swift
// DiveMap/Layers/HeatmapLayer.swift
final class HeatmapLayerManager {
    private let sourceId = "dive-heatmap-source"
    private let layerId = "dive-heatmap-layer"

    func addHeatmapLayer(to mapView: MLNMapView, points: [DiveHeatmapPoint]) {
        // 1. Build GeoJSON FeatureCollection
        let features = points.map { point -> [String: Any] in
            [
                "type": "Feature",
                "geometry": [
                    "type": "Point",
                    "coordinates": [point.longitude, point.latitude]
                ],
                "properties": [
                    "diveCount": point.diveCount
                ]
            ]
        }
        let geojson: [String: Any] = [
            "type": "FeatureCollection",
            "features": features
        ]
        let data = try! JSONSerialization.data(withJSONObject: geojson)

        // 2. Create shape source
        let shape = try! MLNShape(data: data, encoding: String.Encoding.utf8.rawValue)
        let source = MLNShapeSource(identifier: sourceId, shape: shape)
        mapView.style?.addSource(source)

        // 3. Create heatmap layer with underwater color palette
        let layer = MLNHeatmapStyleLayer(identifier: layerId, source: source)

        // Weight by dive count
        layer.heatmapWeight = NSExpression(
            forMLNInterpolating: .init(forKeyPath: "diveCount"),
            curveType: .linear,
            parameters: nil,
            stops: NSExpression(forConstantValue: [
                1: NSExpression(forConstantValue: 0.3),
                5: NSExpression(forConstantValue: 0.6),
                20: NSExpression(forConstantValue: 1.0)
            ])
        )

        // Underwater color ramp: deep blue → teal → cyan → white
        layer.heatmapColor = NSExpression(
            forMLNInterpolating: .init(forKeyPath: "$heatmapDensity"),
            curveType: .linear,
            parameters: nil,
            stops: NSExpression(forConstantValue: [
                0.0: NSExpression(forConstantValue: UIColor.clear),
                0.2: NSExpression(forConstantValue: UIColor(hex: "#0A1628")),  // deep navy
                0.4: NSExpression(forConstantValue: UIColor(hex: "#0D3B66")),  // ocean blue
                0.6: NSExpression(forConstantValue: UIColor(hex: "#1B998B")),  // teal
                0.8: NSExpression(forConstantValue: UIColor(hex: "#2EC4B6")),  // cyan
                1.0: NSExpression(forConstantValue: UIColor(hex: "#CBF3F0")),  // seafoam white
            ])
        )

        // Radius scales with zoom
        layer.heatmapRadius = NSExpression(
            forMLNInterpolating: .init(forKeyPath: "$zoomLevel"),
            curveType: .linear,
            parameters: nil,
            stops: NSExpression(forConstantValue: [
                3: NSExpression(forConstantValue: 20),
                8: NSExpression(forConstantValue: 40),
                12: NSExpression(forConstantValue: 60)
            ])
        )

        layer.heatmapOpacity = NSExpression(forConstantValue: 0.7)

        mapView.style?.addLayer(layer)
    }

    func removeHeatmapLayer(from mapView: MLNMapView) {
        if let layer = mapView.style?.layer(withIdentifier: layerId) {
            mapView.style?.removeLayer(layer)
        }
        if let source = mapView.style?.source(withIdentifier: sourceId) {
            mapView.style?.removeSource(source)
        }
    }

    func updatePoints(_ points: [DiveHeatmapPoint], on mapView: MLNMapView) {
        removeHeatmapLayer(from: mapView)
        addHeatmapLayer(to: mapView, points: points)
    }
}
```

### Step 3: Toggle UI in My Map Mode

Add a segmented control or toggle within the My Map view:

```
┌─ My Map ────────────────────────┐
│ [📍 Sites]  [🔥 Heat Map]       │
│                                 │
│        ┌──────────────┐         │
│       ╱                ╲        │
│      │   ░░▒▒▓▓██▓▓░░  │       │
│      │  ░▒▓████████▓▒░ │       │
│      │   ░░▒▒▓▓██▓░░   │       │
│       ╲                ╱        │
│        └──────────────┘         │
│                                 │
│  42 dives across 12 sites       │
│  Most dived: Blue Hole (8)      │
└─────────────────────────────────┘
```

In `MapUIViewModel` or equivalent:
```swift
enum MyMapDisplayMode {
    case sites    // existing pin view
    case heatmap  // new heat map layer
}

@Published var myMapDisplayMode: MyMapDisplayMode = .sites
```

When toggling:
- `.sites` → show existing site pins, hide heatmap layer
- `.heatmap` → hide site pins, show heatmap layer, show summary stats

### Step 4: Summary Statistics Overlay

When heat map is active, show a small stats card:

```swift
struct HeatmapStatsCard: View {
    let totalDives: Int
    let uniqueSites: Int
    let mostDived: (site: String, count: Int)?
    let countries: Int

    var body: some View {
        // Compact card at bottom of map
    }
}
```

### Step 5: Edge Cases

- **No dives**: Show empty state "Log your first dive to see your heat map"
- **Single site**: Heat map still works, just shows one hotspot
- **GPS-only dives**: Include in heat map using `pendingLatitude`/`pendingLongitude`
- **Performance**: Cache GeoJSON, only rebuild when dives change (observe DB changes)

## Testing

- [ ] Toggle between pins and heat map in My Map mode
- [ ] Verify heat map renders with 1, 5, 50, 500 dives
- [ ] Verify color intensity scales with dive count
- [ ] Check GPS-only dives appear on heat map
- [ ] Verify heat map respects underwater color palette
- [ ] Test zoom behavior (radius scaling)
- [ ] Performance with large dive logs (1000+ entries)
- [ ] Empty state when no dives logged

## Risks

- **MapLibre heatmap API**: Verify `MLNHeatmapStyleLayer` is available in MapLibre Native iOS 6.10.0 (it should be — heatmap layers have been supported since early versions)
- **Performance**: Large point sets may need clustering at low zoom levels
