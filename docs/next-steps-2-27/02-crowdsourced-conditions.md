# 2. Crowdsourced Real-Time Conditions Layer

**Priority**: Tier 1 — Critical (top differentiator)
**Estimated Complexity**: High
**Modules**: `UmiDB` (migration), `UmiCloudKit` (sync), `FeatureMap` (UI), `DiveMap` (layer)
**Migration**: v10

---

## Problem

UmiLog captures per-dive conditions (visibility, current, temperature) but doesn't aggregate or share them. The research identifies "Waze for diving" as the #1 Blue Ocean differentiator — showing recent, crowdsourced conditions at dive sites on the map.

## Current State

- `DiveLog` stores: `temperature`, `visibility`, `current` (enum), `conditions` (enum)
- `DiveSite` has: `averageTemp`, `averageVisibility` (static seed averages)
- CloudKit sync infrastructure exists with `SyncableRecord` protocol
- No aggregation logic, no conditions-specific reporting

## Implementation Plan

### Step 1: ConditionReport Model + Migration v10

A lightweight report that doesn't require a full dive log:

```swift
// UmiDB/Models/ConditionReport.swift
struct ConditionReport: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "condition_reports"

    var id: String              // UUID
    var siteId: String          // FK → sites
    var reporterId: String      // CloudKit user record ID (anonymized)
    var visibility: Double?     // meters
    var current: Current?       // .none, .light, .moderate, .strong
    var temperature: Double?    // celsius
    var surfaceConditions: SurfaceConditions?  // .calm, .choppy, .rough
    var notes: String?          // freeform ("jellyfish warning", "blue water!")
    var reportedAt: Date        // when conditions were observed
    var createdAt: Date
    var source: ReportSource    // .diveLog, .quickReport, .synced

    enum SurfaceConditions: String, Codable, DatabaseValueConvertible {
        case calm, choppy, rough
    }
    enum ReportSource: String, Codable, DatabaseValueConvertible {
        case diveLog, quickReport, synced
    }

    // Association
    static let site = belongsTo(DiveSite.self)
}
```

Migration v10:
```swift
migrator.registerMigration("v10_condition_reports") { db in
    try db.create(table: "condition_reports") { t in
        t.primaryKey("id", .text).notNull()
        t.column("siteId", .text).notNull()
            .references("sites", onDelete: .cascade)
        t.column("reporterId", .text).notNull()
        t.column("visibility", .double)
        t.column("current", .text)
        t.column("temperature", .double)
        t.column("surfaceConditions", .text)
        t.column("notes", .text)
        t.column("reportedAt", .datetime).notNull()
        t.column("createdAt", .datetime).notNull()
        t.column("source", .text).notNull().defaults(to: "quickReport")
    }
    try db.create(index: "idx_condition_reports_site_date",
                  on: "condition_reports",
                  columns: ["siteId", "reportedAt"])
}
```

### Step 2: Auto-Generate Reports from Dive Logs

When a dive is saved, automatically create a `ConditionReport` from its conditions data:

```swift
// In DiveLog save flow
func createConditionReport(from dive: DiveLog) -> ConditionReport {
    ConditionReport(
        id: UUID().uuidString,
        siteId: dive.siteId!,
        reporterId: localUserId,
        visibility: dive.visibility,
        current: dive.current,
        temperature: dive.temperature,
        surfaceConditions: nil,
        notes: nil,
        reportedAt: dive.startTime,
        createdAt: Date(),
        source: .diveLog
    )
}
```

### Step 3: Quick Report Sheet

A lightweight sheet (no full dive log needed) accessible from site detail cards:

```
┌─────────────────────────────────┐
│ Report Conditions at Blue Hole  │
│                                 │
│ Visibility    [▰▰▰▰▰░░] 15m    │
│ Current       ○ None ● Light    │
│               ○ Moderate ○ Strong│
│ Water Temp    [▰▰▰▰░░░] 24°C   │
│ Surface       ○ Calm ● Choppy  │
│                                 │
│ Notes  [________________________]│
│                                 │
│      [Submit Report]            │
└─────────────────────────────────┘
```

Files:
- `FeatureMap/ConditionReport/QuickReportSheet.swift`
- `FeatureMap/ConditionReport/QuickReportViewModel.swift`

Entry points:
- "Report Conditions" button on site inspect card
- Quick action from site annotation tap

### Step 4: Aggregation & Display on Site Cards

Compute recent conditions per site:

```swift
// UmiDB/Queries/ConditionReportQueries.swift
struct SiteConditionSummary {
    let siteId: String
    let latestReport: ConditionReport?
    let avgVisibility24h: Double?
    let avgTemperature24h: Double?
    let dominantCurrent24h: Current?
    let reportCount24h: Int
    let reportCount7d: Int
    let freshness: Freshness  // .live (<2h), .recent (<24h), .stale (<7d), .old
}

enum Freshness {
    case live, recent, stale, old
    var color: Color { ... }
    var label: String { ... }  // "2h ago", "Yesterday", "3 days ago"
}
```

Display on site detail cards:
```
┌─────────────────────────────┐
│ Blue Hole · Dahab           │
│ ★★★★☆  Advanced             │
│                             │
│ 🌊 Recent Conditions        │
│ Vis: 20m  Temp: 26°C       │
│ Current: Light  ● 2h ago   │
│ 3 reports today             │
└─────────────────────────────┘
```

### Step 5: Map Conditions Overlay

Add a toggleable layer on the MapLibre map showing conditions at each site:

- **Color coding**: Green (excellent vis) → Yellow (moderate) → Red (poor)
- **Recency ring**: Bright ring = fresh report, faded = stale
- **Toggle**: Add to existing layer switcher (alongside difficulty pins, clusters)

Implementation via MapLibre GeoJSON source:
```swift
// DiveMap/Layers/ConditionsLayer.swift
func buildConditionsGeoJSON(summaries: [SiteConditionSummary]) -> Data {
    // GeoJSON FeatureCollection with properties:
    // visibility, current, temperature, freshness, reportCount
}
```

### Step 6: CloudKit Sync

Extend `SyncableRecord` conformance to `ConditionReport`:
- Sync reports to shared CloudKit database (not private)
- Anonymize reporter ID (hash of CKRecord.ID, no PII)
- Pull recent reports for visible sites on map viewport change
- Rate-limit: max 1 report per site per user per hour
- Moderation: flag system for inappropriate notes

## Testing

- [ ] Create a quick report, verify it appears on site card
- [ ] Log a dive with conditions, verify auto-generated report
- [ ] Test aggregation with multiple reports at same site
- [ ] Verify freshness labels update correctly
- [ ] Test conditions layer toggle on/off
- [ ] Verify CloudKit sync (requires CloudKit entitlement + device)
- [ ] Test rate limiting (duplicate report prevention)

## Risks

- **Privacy**: Reporter IDs must be anonymized. No user names or profiles exposed
- **Data quality**: Outlier reports could skew averages. Consider median over mean
- **Spam**: Rate limiting + device attestation needed before public launch
- **CloudKit quotas**: High-traffic sites could generate many records. Aggregate server-side if possible
