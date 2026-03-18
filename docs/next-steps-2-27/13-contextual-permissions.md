# 13. Contextual Permission Flow Audit

**Priority**: Tier 4 — Polish
**Estimated Complexity**: Low
**Modules**: `UmiLocationKit`, `FeatureOnboarding`, `FeatureMap`
**Migration**: None

---

## Problem

Requesting permissions too early (on app launch) or without context leads to denials. The research emphasizes requesting permissions only when the user takes an action that needs them, with clear explanations.

## Current State

- `LocationService` uses `CLLocationManager` with WhenInUse permission
- `GeofenceManager` requests location for site monitoring
- Permission request timing not audited — may fire on app launch
- Info.plist has usage description strings (need to verify quality)
- Notifications requested by `GeofenceManager` for dive reminders
- Camera/Photo library permissions exist in entitlements but usage unknown

## Implementation Plan

### Step 1: Audit Current Permission Requests

Map every permission request to its trigger:

| Permission | Current Trigger | Ideal Trigger |
|-----------|----------------|---------------|
| Location (WhenInUse) | ? (audit needed) | First map interaction or "Locate Me" tap |
| Location (Always) | GeofenceManager init? | User enables "Site Arrival Notifications" in settings |
| Notifications | GeofenceManager init? | User enables dive reminders or gear alerts |
| Camera | Not used yet | First "Take Photo" in sighting flow |
| Photo Library | Not used yet | First "Choose Photo" in sighting/cert flow |
| Bluetooth | Not used yet | First "Connect Dive Computer" action |

### Step 2: Defer Location Permission

```swift
// UmiLocationKit/LocationService.swift
final class LocationService {
    /// Don't request on init. Wait for explicit user action.
    func requestLocationWhenNeeded() {
        guard authorizationStatus == .notDetermined else { return }

        // Show pre-permission explanation
        // Then request system permission
        locationManager.requestWhenInUseAuthorization()
    }
}
```

In `MapVC` or map view:
```swift
// Request only when user taps "Locate Me" button
func locateMeTapped() {
    if LocationService.shared.authorizationStatus == .notDetermined {
        // Show contextual explanation first
        showLocationExplanation {
            LocationService.shared.requestLocationWhenNeeded()
        }
    } else {
        centerOnUserLocation()
    }
}
```

### Step 3: Pre-Permission Explanations

Show a custom dialog *before* the system alert to explain why:

```swift
// UmiDesignSystem/Components/PermissionExplanationSheet.swift
struct PermissionExplanationSheet: View {
    let permission: PermissionType
    let onContinue: () -> Void
    let onSkip: () -> Void

    enum PermissionType {
        case location
        case locationAlways
        case notifications
        case camera
        case photoLibrary
        case bluetooth

        var title: String { ... }
        var explanation: String { ... }
        var icon: String { ... }
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: permission.icon)
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text(permission.title)
                .font(.title2.bold())

            Text(permission.explanation)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)

            Button("Not Now", action: onSkip)
                .font(.subheadline)
        }
        .padding()
    }
}
```

Explanation copy:

- **Location**: "UmiLog uses your location to show nearby dive sites on the map and calculate distances. Your location stays on your device."
- **Location Always**: "Always-on location lets UmiLog remind you to log a dive when you arrive at or leave a dive site. This uses low-power geofencing and has minimal battery impact."
- **Notifications**: "Get reminded to log your dive when you arrive at a site, and alerts when gear service is due."
- **Camera**: "Take photos of marine life to attach to your sightings log."
- **Bluetooth**: "Connect to your dive computer to automatically sync dive data."

### Step 4: Update Info.plist Usage Strings

Verify and improve the system dialog strings:

```xml
<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>UmiLog shows dive sites near you and calculates distances on the map.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>UmiLog can remind you to log a dive when you arrive at or leave a dive site. This uses low-power geofencing.</string>

<!-- Notifications -->
<key>NSUserNotificationsUsageDescription</key>
<string>Get dive log reminders at dive sites and gear service alerts.</string>

<!-- Camera (future) -->
<key>NSCameraUsageDescription</key>
<string>Take photos of marine life to attach to your wildlife sightings.</string>

<!-- Photo Library (future) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Select existing photos to attach to sightings or certification cards.</string>

<!-- Bluetooth (future) -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Connect to your dive computer to sync dive data automatically.</string>
```

### Step 5: Handle Denied State Gracefully

When a permission is denied, show a helpful inline message rather than breaking:

```swift
// Map view when location denied
if LocationService.shared.authorizationStatus == .denied {
    // Show inline banner, not a blocking alert
    InlineBanner(
        message: "Location access helps find nearby sites",
        action: "Open Settings",
        onTap: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
    )
}
```

## Testing

- [ ] Fresh install → map loads without location prompt
- [ ] Tap "Locate Me" → pre-permission sheet → system prompt
- [ ] Deny location → map still works (just no blue dot)
- [ ] Denied state → helpful inline banner with Settings link
- [ ] Enable notifications only when first reminder feature is used
- [ ] Verify all Info.plist strings are clear and accurate
- [ ] Test permission flow in onboarding vs post-onboarding
- [ ] Verify "Always" upgrade path (WhenInUse → Always) shows explanation

## Risks

- **Onboarding flow**: If onboarding currently requests permissions, need to restructure it to defer. Verify `FeatureOnboarding` doesn't request location prematurely
- **GeofenceManager dependency**: If geofencing starts automatically, it may trigger location requests. Ensure it only starts after user enables the feature
