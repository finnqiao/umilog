# 8. BLE Dive Computer Sync

**Priority**: Tier 3 — Complex but table-stakes for power users
**Estimated Complexity**: Very High
**Modules**: New `UmiBLEKit`, `UmiDB`, `FeatureSettings` (pairing UI)
**Migration**: v11 (dive profile storage)

---

## Problem

Manual dive data entry is "universally despised." Serious divers use dive computers that store detailed logs including depth profiles, gas mixes, and decompression data. Syncing this data automatically is table-stakes.

## Current State

- `UmiWatchKit` exists for Apple Watch connectivity (WCSession, not BLE)
- No CoreBluetooth integration anywhere in the codebase
- `DiveLog` schema covers basic fields but lacks depth profiles, gas mixes, deco stops
- UDDF/Subsurface file import (plan #3) provides an interim solution
- No Info.plist entry for Bluetooth usage description

## Target Dive Computers (Phase 1)

Focus on brands with the most open BLE protocols:

| Brand | Model | BLE Protocol | Openness |
|-------|-------|-------------|----------|
| **Shearwater** | Perdix, Teric, Peregrine | Custom GATT | Well-documented, community-reversed |
| **Suunto** | D5, EON Core | Custom GATT | Partially documented |
| **Garmin** | Descent Mk2/Mk3 | Garmin Connect BLE | SDK available |

Shearwater is the best starting point — active open-source community and clear BLE protocol documentation.

## Implementation Plan

### Step 1: UmiBLEKit Module

```
Modules/UmiBLEKit/
├── Sources/
│   ├── BLEManager.swift              # CBCentralManager wrapper
│   ├── DiveComputerScanner.swift     # Discover dive computers
│   ├── DiveComputerConnection.swift  # Connection lifecycle
│   ├── Protocols/
│   │   ├── DiveComputerProtocol.swift  # Abstract protocol
│   │   ├── ShearwaterProtocol.swift    # Shearwater BLE parser
│   │   └── GenericBLEDiveComputer.swift
│   ├── Models/
│   │   ├── BLEDiveComputer.swift     # Discovered device
│   │   ├── RawDiveData.swift         # Parsed dive data
│   │   └── DepthProfile.swift        # Depth/time samples
│   └── Pairing/
│       ├── PairingManager.swift      # Remember paired devices
│       └── PairedDevice.swift        # Stored device info
```

### Step 2: BLE Scanner & Connection

```swift
// UmiBLEKit/BLEManager.swift
@Observable
final class BLEManager: NSObject, CBCentralManagerDelegate {
    private var central: CBCentralManager!
    var state: CBManagerState = .unknown
    var discoveredDevices: [BLEDiveComputer] = []
    var connectedDevice: BLEDiveComputer?
    var syncProgress: SyncProgress?

    // Known dive computer service UUIDs
    static let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FE25"),  // Shearwater
        // Add others as supported
    ]

    func startScanning() { ... }
    func connect(to device: BLEDiveComputer) { ... }
    func disconnect() { ... }
}

struct BLEDiveComputer: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let brand: DiveComputerBrand
    let rssi: Int
    var isPaired: Bool
}

enum DiveComputerBrand: String, Codable {
    case shearwater, suunto, garmin, unknown
}
```

### Step 3: Shearwater Protocol Parser

Shearwater dive computers expose data via a custom GATT service:

```swift
// UmiBLEKit/Protocols/ShearwaterProtocol.swift
final class ShearwaterProtocol: DiveComputerProtocol {
    // Shearwater BLE Service & Characteristics
    static let serviceUUID = CBUUID(string: "FE25")
    static let writeCharUUID = CBUUID(string: "...")
    static let readCharUUID = CBUUID(string: "...")

    func requestDiveHeaders() async throws -> [DiveHeader]
    func downloadDive(index: Int) async throws -> RawDiveData
    func downloadAllNewDives(since lastSync: Date?) async throws -> [RawDiveData]
}

struct RawDiveData {
    let computerSerial: String
    let diveNumber: Int
    let date: Date
    let duration: TimeInterval
    let maxDepth: Double          // meters
    let avgDepth: Double?
    let minTemperature: Double    // celsius
    let surfaceTemperature: Double?
    let startPressure: Double?    // bar
    let endPressure: Double?
    let gasMixes: [GasMix]
    let depthProfile: [DepthSample]
    let decoStops: [DecoStop]?
    let safetyStopPerformed: Bool
    let surfaceInterval: TimeInterval?
    let algorithm: String?        // Bühlmann ZHL-16C, VPM-B, etc.
    let gfLow: Int?               // gradient factor
    let gfHigh: Int?
}

struct DepthSample {
    let time: TimeInterval        // seconds from dive start
    let depth: Double             // meters
    let temperature: Double?
    let pressure: Double?         // remaining gas pressure
}

struct GasMix {
    let o2Percent: Double
    let hePercent: Double         // 0 for recreational
    let switchDepth: Double?
    var isActive: Bool
}

struct DecoStop {
    let depth: Double
    let duration: TimeInterval
}
```

### Step 4: Schema Extension for Depth Profiles

Migration v11:

```swift
// New table for detailed dive profiles (too large for DiveLog columns)
try db.create(table: "dive_profiles") { t in
    t.primaryKey("id", .text).notNull()
    t.column("diveId", .text).notNull().unique()
        .references("dives", onDelete: .cascade)
    t.column("samples", .blob).notNull()        // compressed JSON of DepthSample array
    t.column("sampleIntervalSec", .integer)      // e.g., 10 seconds
    t.column("sampleCount", .integer).notNull()
    t.column("source", .text).notNull()          // "shearwater", "suunto", "manual"
    t.column("computerSerial", .text)
    t.column("computerModel", .text)
    t.column("createdAt", .datetime).notNull()
}

// Add gas mix tracking to dives
try db.alter(table: "dives") { t in
    t.add(column: "gasMixesJson", .text)         // JSON array of GasMix
    t.add(column: "computerDiveNumber", .integer)
    t.add(column: "surfaceInterval", .integer)    // seconds
    t.add(column: "safetyStopPerformed", .boolean)
}
```

### Step 5: Pairing & Sync UI

```
┌─ Dive Computer ─────────────────┐
│                                 │
│ ┌─ Paired ────────────────────┐ │
│ │ 🔵 Shearwater Perdix AI    │ │
│ │ S/N: A12345  Last: 2 days  │ │
│ │ [Sync Now]  [Forget]       │ │
│ └─────────────────────────────┘ │
│                                 │
│ ─── or ───                      │
│                                 │
│ Scanning for dive computers...  │
│ ┌─────────────────────────────┐ │
│ │ 📡 Shearwater Teric   -65dB│ │
│ │ [Pair]                      │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 📡 Suunto D5          -72dB│ │
│ │ [Pair]                      │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

Sync flow:
```
Pair → Download headers → Show new dives → Confirm import
→ Match to sites (GPS proximity) → Save to DiveLog + DiveProfile
```

### Step 6: Auto Site Matching

When a dive is synced from a computer, it has no site association. Match using:

1. **GPS proximity** (if dive computer has GPS, or use phone's last known location at dive time)
2. **Time-based**: If user was at a geofenced site around the dive time, auto-match
3. **Manual fallback**: Let user pick from recent/nearby sites

```swift
func autoMatchSite(for rawDive: RawDiveData, db: Database) -> DiveSite? {
    // Check geofence log: was user at a monitored site around dive time?
    if let geofenceMatch = GeofenceManager.shared.siteAt(time: rawDive.date) {
        return geofenceMatch
    }

    // Check recent location history
    if let lastLocation = LocationService.shared.locationAt(time: rawDive.date) {
        return try? DiveSite.nearest(to: lastLocation, within: 2000, in: db)
    }

    return nil  // User must manually select
}
```

## Testing

- [ ] Scan discovers Shearwater device in range
- [ ] Pair and store device info
- [ ] Download dive headers from computer
- [ ] Download full dive with depth profile
- [ ] Verify data mapping to DiveLog fields
- [ ] Verify depth profile storage and retrieval
- [ ] Test auto site matching via geofence history
- [ ] Test sync with multiple new dives
- [ ] Test re-sync (skip already imported dives)
- [ ] Test Bluetooth permission request flow
- [ ] Test with Bluetooth off (graceful error)

## Risks

- **Protocol reverse engineering**: Shearwater's BLE protocol is community-documented but not officially supported. May break with firmware updates
- **Hardware dependency**: Testing requires physical dive computers. Consider a BLE simulator for CI
- **Background BLE**: iOS limits background BLE. Sync must happen while app is foregrounded
- **Battery**: BLE scanning is battery-intensive. Only scan when user explicitly initiates
- **Complexity**: This is the single most complex feature. Consider shipping file import (#3) first and deferring BLE to a later release

## References

- libdivecomputer: https://github.com/libdivecomputer/libdivecomputer (C library, could wrap via bridging header)
- Subsurface BLE implementation: https://github.com/subsurface/subsurface (reference for protocol details)
- Shearwater BLE community docs: various dive forum threads
