# 3. Dive File Import (UDDF / Subsurface XML)

**Priority**: Tier 1 — Critical (interim dive computer solution)
**Estimated Complexity**: Medium
**Modules**: `FeatureSettings` (existing), `UmiDB`
**Migration**: None (uses existing DiveLog schema)

---

## Problem

Manual dive data entry is "universally despised." Full BLE dive computer sync is complex (Tier 3), but file import from dive computer desktop software is an achievable interim step that unblocks power users immediately.

## Current State

- `UDDFImporter.swift` exists in `FeatureSettings/Import/` — parses basic UDDF XML
- `CSVImporter.swift` exists for CSV import
- `ImportPreviewView.swift` provides preview-before-import UI
- Current UDDF parser handles: date, maxDepth, bottomTime, temperature, pressure, notes, site name
- Missing: depth profiles, gas mixes, multiple gases, Subsurface XML format, GPS matching

## Implementation Plan

### Step 1: Audit & Harden UDDFImporter

Review the existing parser against the UDDF 3.2.2 spec:

**Currently parsed** (verify correctness):
- `<datetime>` → DiveLog.date, startTime
- `<greatestdepth>` → maxDepth (Kelvin→Celsius, Pascal→bar conversions)
- `<diveduration>` → bottomTime
- `<lowesttemperature>` → temperature
- `<tankpressurebegin>`, `<tankpressureend>` → startPressure, endPressure
- `<notes>` → notes
- `<site><name>` → site name matching

**Add support for**:
- `<averagedepth>` → averageDepth
- `<visibility>` → visibility
- `<currentstrength>` → current
- `<waypoint>` depth profile samples (store as JSON blob or new table)
- `<gas>` definitions (air, nitrox, trimix) — store O2% at minimum
- `<site><geography><latitude>`, `<longitude>` → GPS for site matching
- `<buddy>` → notes field (append)
- `<divemode>` (opencircuit, rebreather) → notes or future field
- Multiple dives per file (already a `<repetitiongroup>`)

### Step 2: Subsurface XML Importer

Subsurface is the most popular open-source dive log software. Its XML format differs from UDDF:

```swift
// FeatureSettings/Import/SubsurfaceImporter.swift
final class SubsurfaceImporter {
    struct ParsedDive {
        var date: Date
        var time: Date?
        var duration: TimeInterval   // seconds
        var maxDepth: Double         // meters (already metric)
        var meanDepth: Double?
        var airTemp: Double?
        var waterTemp: Double?
        var startPressure: Double?   // bar
        var endPressure: Double?
        var visibility: String?      // Subsurface uses 1-5 star rating
        var notes: String?
        var buddy: String?
        var divemaster: String?
        var suit: String?
        var location: String?
        var gps: CLLocationCoordinate2D?
        var tags: [String]
        var cylinder: CylinderInfo?
    }

    func parse(data: Data) throws -> [ParsedDive]
}
```

Subsurface XML structure:
```xml
<divelog>
  <divesites>
    <site uuid="..." name="Blue Hole" gps="28.572 34.558"/>
  </divesites>
  <dives>
    <dive number="1" date="2025-12-15" time="09:30:00" duration="45:00 min">
      <depth max="30.2 m" mean="18.5 m"/>
      <temperature water="26.0 C" air="30.0 C"/>
      <cylinder size="12.0 l" start="200 bar" end="50 bar" o2="21.0%"/>
      <location gps="28.572 34.558">Blue Hole, Dahab</location>
      <buddy>Jane</buddy>
      <notes>Amazing visibility</notes>
    </dive>
  </dives>
</divelog>
```

### Step 3: Unified Import Flow

```
┌─ Import Dives ──────────────────┐
│                                 │
│  Select a file to import:       │
│                                 │
│  [📄 Choose File...]            │
│                                 │
│  Supported formats:             │
│  • UDDF (.uddf)                 │
│  • Subsurface (.ssrf, .xml)     │
│  • CSV (.csv)                   │
│                                 │
│  ─────────────────────────────  │
│  Or import from:                │
│  [Subsurface Cloud]  [Files]    │
└─────────────────────────────────┘

        ↓ File selected

┌─ Preview ───────────────────────┐
│ Found 23 dives                  │
│                                 │
│ ┌─ Dec 15 · Blue Hole ───────┐ │
│ │ 30.2m max · 45min · 26°C   │ │
│ │ Site match: Blue Hole ✅    │ │
│ │ [✓ Import]                  │ │
│ └─────────────────────────────┘ │
│ ┌─ Dec 14 · Unknown Site ────┐ │
│ │ 18.0m max · 38min · 24°C   │ │
│ │ Site match: 📍 GPS → Ras   │ │
│ │ Mohammed (1.2km) [Change]   │ │
│ │ [✓ Import]                  │ │
│ └─────────────────────────────┘ │
│                                 │
│ 2 duplicates skipped            │
│        [Import 21 Dives]        │
└─────────────────────────────────┘
```

Files:
- `FeatureSettings/Import/ImportFlowView.swift` (update existing)
- `FeatureSettings/Import/ImportPreviewView.swift` (update existing)
- `FeatureSettings/Import/ImportDiveCard.swift` (new)
- `FeatureSettings/Import/SiteMatchingService.swift` (new)

### Step 4: Site Matching Heuristics

```swift
// FeatureSettings/Import/SiteMatchingService.swift
struct SiteMatch {
    let site: DiveSite
    let confidence: MatchConfidence  // .exact, .likely, .possible, .none
    let method: MatchMethod          // .nameExact, .nameFuzzy, .gpsProximity
    let distance: Double?            // meters, if GPS matched
}

final class SiteMatchingService {
    func findMatch(name: String?, gps: CLLocationCoordinate2D?, db: Database) -> SiteMatch? {
        // 1. Exact name match (case-insensitive)
        // 2. GPS proximity match (< 2km from known site)
        // 3. Fuzzy name match (Levenshtein distance, contains)
        // 4. Return nil — user picks manually or creates new site
    }
}
```

### Step 5: File Association (UTTypes)

Register the app to open dive log files from Files/email/AirDrop:

```swift
// In project.yml or Info.plist
// Document types:
//   - .uddf (application/uddf+xml)
//   - .ssrf (Subsurface native)
//   - .xml (with validation)

// UTType declarations in code:
extension UTType {
    static let uddf = UTType(filenameExtension: "uddf")!
    static let subsurface = UTType(filenameExtension: "ssrf")!
}
```

Handle in `DeepLinkRouter.swift` — open file → launch import flow.

### Step 6: Duplicate Detection

Before importing, check for existing dives:

```swift
func isDuplicate(_ parsed: ParsedDive, in db: Database) -> Bool {
    // Match on: same date (±5min) AND same max depth (±1m) AND same duration (±5min)
    let existing = try DiveLog
        .filter(Column("date").between(parsed.date - 300, parsed.date + 300))
        .filter(Column("maxDepth").between(parsed.maxDepth - 1, parsed.maxDepth + 1))
        .fetchOne(db)
    return existing != nil
}
```

## Testing

- [ ] Import a real UDDF file exported from Subsurface
- [ ] Import a Subsurface .ssrf file with multiple dives
- [ ] Verify unit conversions (Kelvin→°C, Pascal→bar) in UDDF
- [ ] Test site matching: exact name, GPS proximity, fuzzy, no match
- [ ] Test duplicate detection (same dive imported twice)
- [ ] Test file association (open .uddf from Files app)
- [ ] Test import of 100+ dives (performance)
- [ ] Test with malformed/incomplete XML files (error handling)

## Sample Test Files

- Subsurface project provides sample files: https://github.com/subsurface/subsurface/tree/master/dives
- UDDF sample files from the UDDF spec website
- Generate test files from Subsurface desktop app

## Risks

- **Format variations**: Different dive computers export slightly different UDDF. Test broadly
- **Encoding**: XML files may be UTF-8 or ISO-8859-1. Handle both
- **Large files**: Logbooks with 1000+ dives — parse incrementally, don't load all into memory
