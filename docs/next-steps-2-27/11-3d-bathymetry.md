# 11. 3D Bathymetric Briefings

**Priority**: Tier 3 — Premium experience
**Estimated Complexity**: High
**Modules**: `DiveMap` (terrain layer), `FeatureMap` (site preview UI)
**Migration**: None

---

## Problem

Flat maps don't convey underwater terrain. A 3D bathymetric view helps divers understand depth contours, wall drop-offs, and reef topography before a dive — essentially a "terrain briefing."

## Current State

- MapLibre 6.10.0 supports terrain/3D rendering (`MLNRasterDEMSource`, `MLNHillshadeStyleLayer`)
- Current map uses Esri Ocean raster basemap (2D only)
- `umilog_underwater_vector.json` and other style files are flat
- `DiveSite` has `averageDepth`, `maxDepth` — but no terrain data
- No pitch/bearing controls exposed to user

## Implementation Plan

### Step 1: Source Bathymetric DEM Data

Available free sources:

| Source | Resolution | Coverage | Format |
|--------|-----------|----------|--------|
| **GEBCO** (General Bathymetric Chart of the Oceans) | 15 arc-second (~450m) | Global | NetCDF, GeoTIFF |
| **NOAA ETOPO** | 15 arc-second | Global | GeoTIFF, COG |
| **EMODnet** | ~115m | European waters | GeoTIFF |
| **SRTM15+** | 15 arc-second | Global | GeoTIFF |

**Recommended**: Use a hosted terrain tile service that serves Mapbox Terrain RGB or Terrarium format tiles. Options:
- Self-host GEBCO data as raster DEM tiles
- Use MapTiler's terrain tiles (free tier available)
- AWS Terrain Tiles (open, free, Terrarium encoding)

### Step 2: Enable Terrain in Map Style

Add terrain source to map style JSON:

```json
{
  "sources": {
    "terrain-source": {
      "type": "raster-dem",
      "url": "https://your-tiles.example.com/terrain/{z}/{x}/{y}.png",
      "tileSize": 256,
      "encoding": "terrarium"
    }
  },
  "terrain": {
    "source": "terrain-source",
    "exaggeration": 2.0
  }
}
```

Or configure programmatically:

```swift
// DiveMap/Layers/TerrainLayer.swift
final class TerrainLayerManager {
    func enableTerrain(on mapView: MLNMapView, exaggeration: Double = 2.0) {
        guard let style = mapView.style else { return }

        // Add DEM source
        let demSource = MLNRasterDEMSource(
            identifier: "bathymetry-dem",
            tileURLTemplates: ["https://tiles.example.com/terrain/{z}/{x}/{y}.png"],
            options: [
                .tileSize: 256,
                // Terrarium or Mapbox encoding
            ]
        )
        style.addSource(demSource)

        // Add hillshade layer for visual depth rendering
        let hillshade = MLNHillshadeStyleLayer(identifier: "bathymetry-hillshade", source: demSource)
        hillshade.hillshadeIlluminationDirection = NSExpression(forConstantValue: 315)
        hillshade.hillshadeExaggeration = NSExpression(forConstantValue: 0.5)
        hillshade.hillshadeShadowColor = NSExpression(forConstantValue: UIColor(hex: "#0A1628"))
        hillshade.hillshadeHighlightColor = NSExpression(forConstantValue: UIColor(hex: "#2EC4B6"))
        style.addLayer(hillshade)
    }

    func disableTerrain(on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        if let layer = style.layer(withIdentifier: "bathymetry-hillshade") {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: "bathymetry-dem") {
            style.removeSource(source)
        }
    }
}
```

### Step 3: 3D Site Preview

A dedicated "Terrain View" for individual sites with pitch/bearing controls:

```
┌─ Blue Hole · Terrain View ──────┐
│                                 │
│     ╱╲                          │
│    ╱  ╲    ___                  │
│   ╱    ╲__╱   ╲                │
│  ╱              ╲___           │
│ ╱     [3D Map]       ╲         │
│╱                      ╲______  │
│                                 │
│ 🔄 Rotate   📐 Tilt   🔍 Zoom  │
│                                 │
│ Max Depth: 130m                 │
│ Avg Depth: 40m                  │
│ Type: Wall / Sinkhole           │
└─────────────────────────────────┘
```

```swift
// FeatureMap/SitePreview/TerrainPreviewView.swift
struct TerrainPreviewView: View {
    let site: DiveSite
    @State private var pitch: Double = 60  // 0 = top-down, 85 = near-horizon
    @State private var bearing: Double = 0

    var body: some View {
        VStack {
            DiveMapView(
                center: CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude),
                zoom: 14,
                pitch: pitch,
                bearing: bearing,
                terrainEnabled: true,
                terrainExaggeration: 3.0  // exaggerate for dramatic effect
            )
            .frame(height: 300)
            .gesture(
                // Drag to rotate bearing, pinch to adjust pitch
                DragGesture().onChanged { ... }
            )

            // Controls
            HStack {
                Slider(value: $bearing, in: 0...360) { Text("Bearing") }
                Slider(value: $pitch, in: 0...85) { Text("Pitch") }
            }
            .padding()
        }
    }
}
```

### Step 4: Depth Contour Overlay

Add isobath (depth contour) lines as a vector layer:

```swift
// Option 1: Pre-generate contours from DEM
// Option 2: Use a contour tile service
// Option 3: Generate on-device from DEM tiles (computationally expensive)

let contourLayer = MLNLineStyleLayer(identifier: "depth-contours", source: contourSource)
contourLayer.lineColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.3))
contourLayer.lineWidth = NSExpression(forConstantValue: 0.5)
```

Label major contours (10m, 20m, 30m, 40m) with depth values.

### Step 5: Performance Optimization

3D rendering is GPU-intensive:

- Only enable terrain when user explicitly activates it (toggle, not default)
- Limit terrain zoom range (z8–z14, not street-level)
- Reduce exaggeration at high zoom (looks distorted up close)
- Cache terrain tiles aggressively (DEM doesn't change)
- Disable terrain on older devices (check `ProcessInfo.processInfo.thermalState`)

## Testing

- [ ] Toggle terrain on/off in map view
- [ ] Verify hillshade renders with underwater color palette
- [ ] Rotate and tilt site preview with gestures
- [ ] Verify depth contours display at appropriate zoom
- [ ] Test performance on iPhone 12 (A14) vs iPhone 15 (A16)
- [ ] Verify terrain works with offline tile packs (#1)
- [ ] Test with various site types (wall, reef, open ocean)

## Risks

- **MapLibre 3D support**: MapLibre Native iOS terrain support is available but less mature than Mapbox GL. Verify `MLNRasterDEMSource` works with chosen tile source
- **Bathymetry resolution**: 450m resolution (GEBCO) may look blocky at high zoom. Coastal regions may have higher-res data from national surveys
- **Tile hosting costs**: Self-hosting DEM tiles requires storage and bandwidth
- **GPU performance**: 3D rendering may struggle on older devices. Must be opt-in
- **Inaccuracy near shore**: Bathymetry data is least accurate in shallow coastal areas where many dive sites are located
