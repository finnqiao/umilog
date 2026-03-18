# 12. Battery Optimization / Boat Mode

**Priority**: Tier 4 — Polish
**Estimated Complexity**: Medium
**Modules**: `UmiLocationKit`, `DiveMap`, `UmiCoreKit` (new PowerManager)
**Migration**: None

---

## Problem

GPS + map rendering + BLE (future) drain battery fast. Divers on full-day boat trips need their phone to last. "Battery anxiety" is a real pain point cited in the research.

## Current State

- `LocationService` uses `CLLocationManager` with 50m distance filter (reasonable)
- `GeofenceManager` monitors up to 20 sites with 500m radius — efficient (uses system geofencing, not continuous GPS)
- MapLibre renders vector tiles continuously while visible
- No power management strategy, no "boat mode"
- No `ProcessInfo.thermalState` monitoring

## Implementation Plan

### Step 1: Audit Current Power Usage

Before optimizing, measure baseline with Instruments:
- Profile "Energy Log" instrument during a typical session
- Identify top consumers: GPS, map rendering, network, CPU
- Measure background vs foreground drain

### Step 2: Boat Mode

A user-togglable low-power mode for dive boat days:

```swift
// UmiCoreKit/Power/PowerManager.swift
@Observable
final class PowerManager {
    static let shared = PowerManager()

    var isBoatModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBoatModeEnabled, forKey: "boatModeEnabled")
            applyBoatMode()
        }
    }

    var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    private func applyBoatMode() {
        if isBoatModeEnabled {
            // Reduce GPS to significant-change only
            LocationService.shared.reduceAccuracy()
            // Reduce map tile prefetch radius
            DiveMapConfiguration.shared.tilePrefetchRadius = .minimal
            // Disable background fetch
            // Reduce animation frame rate
        } else {
            LocationService.shared.restoreAccuracy()
            DiveMapConfiguration.shared.tilePrefetchRadius = .standard
        }
    }
}
```

### Step 3: Location Optimizations

```swift
// UmiLocationKit/LocationService.swift — additions
extension LocationService {
    func reduceAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 500  // 500m instead of 50m
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
    }

    func restoreAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
    }

    /// Use significant-change monitoring when backgrounded
    func switchToSignificantChangeMonitoring() {
        locationManager.stopUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func switchToStandardMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
    }
}
```

### Step 4: Map Rendering Optimizations

```swift
// DiveMap/MapVC.swift — additions
extension MapVC {
    func applyLowPowerSettings() {
        // Reduce frame rate
        mapView.preferredFramesPerSecond = 30  // instead of 60

        // Disable unnecessary visual effects
        mapView.compassView.isHidden = true

        // Reduce tile prefetch
        // MapLibre doesn't expose this directly — but we can control
        // by limiting viewport change callbacks
    }

    func applyStandardSettings() {
        mapView.preferredFramesPerSecond = 60
    }
}
```

### Step 5: Thermal State Monitoring

Automatically reduce power when device is heating up:

```swift
// UmiCoreKit/Power/PowerManager.swift
func startMonitoringThermalState() {
    NotificationCenter.default.addObserver(
        forName: ProcessInfo.thermalStateDidChangeNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.handleThermalStateChange()
    }
}

private func handleThermalStateChange() {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal, .fair:
        break  // Normal operation
    case .serious:
        // Auto-enable boat mode equivalent
        LocationService.shared.reduceAccuracy()
        mapView?.preferredFramesPerSecond = 30
    case .critical:
        // Aggressive throttling
        LocationService.shared.switchToSignificantChangeMonitoring()
        mapView?.preferredFramesPerSecond = 15
    @unknown default:
        break
    }
}
```

### Step 6: Boat Mode UI

Simple toggle in Settings + quick access from map:

```
Settings > Battery
┌─────────────────────────────────┐
│ 🚤 Boat Mode                   │
│                                 │
│ [Toggle: OFF]                   │
│                                 │
│ Reduces GPS accuracy and map    │
│ refresh rate to extend battery  │
│ life on dive boat days.         │
│                                 │
│ • GPS: ~500m accuracy           │
│ • Map: 30fps rendering          │
│ • Background: minimal updates   │
│                                 │
│ Dive logging still works        │
│ normally when you start a log.  │
└─────────────────────────────────┘
```

Also accessible via long-press on the locate-me button on the map.

## Testing

- [ ] Enable boat mode → verify GPS accuracy reduces
- [ ] Verify map still usable in boat mode (slower but functional)
- [ ] Log a dive while in boat mode → verify full accuracy restores during logging
- [ ] Measure battery drain: boat mode OFF vs ON over 2 hours (Instruments)
- [ ] Thermal state handling: verify auto-throttle at .serious
- [ ] Background → foreground transition: verify correct state restoration
- [ ] Boat mode persists across app restart

## Metrics

Target: **30-40% reduction in battery drain** during idle map browsing with boat mode enabled.
