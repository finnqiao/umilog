# 10. Gear Inventory & Maintenance Alerts

**Priority**: Tier 3 — Blue Ocean
**Estimated Complexity**: Medium
**Modules**: `UmiDB` (migration), `FeatureSettings` or new `FeatureGear` (UI)
**Migration**: v10 or v11

---

## Problem

Divers own equipment that requires regular maintenance (regulators serviced annually, O2 sensors replaced, tanks hydro-tested). There's no good way to track gear usage or service schedules tied to dive activity.

## Current State

- `DiveLog` has `startPressure`, `endPressure` (tank data) but no tank type/size
- No gear/equipment model in schema
- No maintenance tracking
- Local notifications already used by `GeofenceManager` (UNUserNotificationCenter pattern exists)
- No gear-related UI anywhere

## Implementation Plan

### Step 1: GearItem Model + Migration

```swift
// UmiDB/Models/GearItem.swift
struct GearItem: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "gear_items"

    var id: String                    // UUID
    var name: String                  // "My Aqualung Regulator"
    var category: GearCategory
    var brand: String?                // "Aqualung", "Scubapro"
    var model: String?                // "Mikron"
    var serialNumber: String?
    var purchaseDate: Date?
    var lastServiceDate: Date?
    var nextServiceDate: Date?        // triggers reminder
    var serviceIntervalMonths: Int?   // default by category
    var notes: String?
    var isActive: Bool                // false = retired/sold
    var totalDiveCount: Int           // computed, cached
    var createdAt: Date
    var updatedAt: Date
}

enum GearCategory: String, Codable, CaseIterable, DatabaseValueConvertible {
    case regulator     // Service every 12-24 months
    case bcd           // Service every 12-24 months
    case computer      // Battery every 12-24 months
    case tank          // Hydro test every 5 years, visual every year
    case wetsuit       // No fixed schedule
    case drysuit       // Seal service annually
    case fins
    case mask
    case light         // Battery, O-rings
    case camera        // O-rings, housing service
    case spool_reel
    case smb           // Surface marker buoy
    case other

    var defaultServiceIntervalMonths: Int? {
        switch self {
        case .regulator, .bcd: return 12
        case .computer: return 18
        case .tank: return 12        // visual annual, hydro 5yr
        case .drysuit: return 12
        case .light: return 6
        default: return nil
        }
    }

    var displayName: String { ... }
    var systemImage: String { ... }
}
```

Junction table for gear used per dive:

```swift
// UmiDB/Models/DiveGear.swift
struct DiveGear: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "dive_gear"

    var diveId: String    // FK → dives
    var gearId: String    // FK → gear_items

    static let dive = belongsTo(DiveLog.self)
    static let gear = belongsTo(GearItem.self)
}
```

Migration:
```swift
try db.create(table: "gear_items") { t in
    t.primaryKey("id", .text).notNull()
    t.column("name", .text).notNull()
    t.column("category", .text).notNull()
    t.column("brand", .text)
    t.column("model", .text)
    t.column("serialNumber", .text)
    t.column("purchaseDate", .date)
    t.column("lastServiceDate", .date)
    t.column("nextServiceDate", .date)
    t.column("serviceIntervalMonths", .integer)
    t.column("notes", .text)
    t.column("isActive", .boolean).notNull().defaults(to: true)
    t.column("totalDiveCount", .integer).notNull().defaults(to: 0)
    t.column("createdAt", .datetime).notNull()
    t.column("updatedAt", .datetime).notNull()
}

try db.create(table: "dive_gear") { t in
    t.column("diveId", .text).notNull()
        .references("dives", onDelete: .cascade)
    t.column("gearId", .text).notNull()
        .references("gear_items", onDelete: .cascade)
    t.primaryKey(["diveId", "gearId"])
}
```

### Step 2: Gear List View

```
┌─ My Gear ───────────────────────┐
│                                 │
│ ┌─ Regulator ─────────────────┐ │
│ │ 🔧 Aqualung Mikron          │ │
│ │ 45 dives · Service due Mar  │ │
│ │ ⚠️ Service overdue!         │ │
│ └─────────────────────────────┘ │
│ ┌─ BCD ──────────────────────┐  │
│ │ 🦺 Scubapro Hydros Pro     │  │
│ │ 45 dives · Serviced Oct '25│  │
│ └─────────────────────────────┘ │
│ ┌─ Computer ─────────────────┐  │
│ │ ⌚ Shearwater Perdix AI     │  │
│ │ 45 dives · Battery OK      │  │
│ └─────────────────────────────┘ │
│ ┌─ Wetsuit ──────────────────┐  │
│ │ 🩱 5mm Henderson           │  │
│ │ 45 dives                   │  │
│ └─────────────────────────────┘ │
│                                 │
│ [+ Add Gear]                    │
└─────────────────────────────────┘
```

Files:
- `FeatureSettings/Gear/GearListView.swift`
- `FeatureSettings/Gear/GearItemCard.swift`
- `FeatureSettings/Gear/GearFormView.swift`
- `FeatureSettings/Gear/GearFormViewModel.swift`

Accessible from Profile tab → "My Gear" section.

### Step 3: Gear Selection in Dive Log Wizard

Add an optional step to the 4-step wizard (or inline in an existing step):

```
Step 3: Equipment (optional)
┌─────────────────────────────────┐
│ Select gear used on this dive:  │
│                                 │
│ [✓] 🔧 Aqualung Mikron         │
│ [✓] 🦺 Scubapro Hydros Pro     │
│ [✓] ⌚ Shearwater Perdix AI     │
│ [✓] 🩱 5mm Henderson           │
│ [ ] 📷 Sony A7R IV Housing     │
│                                 │
│ [Select All Active]  [Skip]     │
└─────────────────────────────────┘
```

- Default: all active gear pre-selected (most divers use the same setup)
- "Select All Active" for quick logging
- "Skip" to skip gear tracking for this dive

### Step 4: Service Reminders

```swift
// FeatureSettings/Gear/GearReminderService.swift
final class GearReminderService {
    func scheduleReminders(for items: [GearItem]) {
        // Clear existing gear reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: items.map { "gear-service-\($0.id)" }
        )

        for item in items {
            guard let nextService = item.nextServiceDate else { continue }

            // Reminder 2 weeks before service due
            let warningDate = Calendar.current.date(byAdding: .day, value: -14, to: nextService)!
            scheduleNotification(
                id: "gear-service-\(item.id)",
                title: "Gear Service Reminder",
                body: "\(item.name) service due \(nextService.formatted(.dateTime.month().day()))",
                date: warningDate
            )
        }
    }

    func updateDiveCount(gearId: String, db: Database) throws {
        let count = try DiveGear.filter(Column("gearId") == gearId).fetchCount(db)
        try db.execute(
            sql: "UPDATE gear_items SET totalDiveCount = ? WHERE id = ?",
            arguments: [count, gearId]
        )
    }
}
```

### Step 5: Usage Stats

On gear detail view, show:
- Total dives with this gear
- Last dive date with this gear
- Dives since last service
- Average dives per month
- Total bottom time with this gear

## Testing

- [ ] Add gear item with all fields
- [ ] Add gear to a dive via wizard step
- [ ] Verify dive count updates after logging
- [ ] Set service date, verify reminder notification scheduled
- [ ] Service overdue → warning badge shown
- [ ] Retire gear (isActive = false), verify hidden from dive wizard
- [ ] Delete gear, verify dive_gear junction rows cascade
- [ ] Edit gear, verify updates persist

## Future Enhancements

- Gear photos
- Gear cost tracking (purchase price, service costs)
- Insurance info per item
- Share gear list for rental shops (what you own vs need to rent)
- Nearest service center mapping (stretch goal from research)
