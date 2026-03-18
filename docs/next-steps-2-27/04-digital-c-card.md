# 4. Digital C-Card Storage

**Priority**: Tier 2 — Low effort, high daily utility
**Estimated Complexity**: Low-Medium
**Modules**: `UmiDB` (migration), `FeatureMap` or `FeatureSettings` (UI), `UmiCloudKit` (sync)
**Migration**: v10 (batch with condition_reports if implementing together)

---

## Problem

Divers carry physical certification cards to every dive. These get lost, damaged by water, or forgotten. A digital C-Card always available on their phone replaces this friction point.

## Current State

- `DiveLog` has `instructorName`, `instructorNumber`, `signed` — per-dive instructor fields, not user certification
- `FeatureOnboarding/Steps/CertificationStepView.swift` collects basic experience level during onboarding but doesn't persist structured cert data
- No certification model, no cert display

## Implementation Plan

### Step 1: Certification Model + Migration

```swift
// UmiDB/Models/Certification.swift
struct Certification: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "certifications"

    var id: String               // UUID
    var agency: CertAgency       // .padi, .ssi, .naui, .bsac, .cmas, .other
    var agencyOther: String?     // if .other
    var level: String            // "Open Water Diver", "Advanced Open Water", etc.
    var certNumber: String?      // certification number
    var certDate: Date?          // date certified
    var expiryDate: Date?        // some certs expire (e.g., EFR, O2 provider)
    var instructorName: String?
    var instructorNumber: String?
    var divesAtCert: Int?        // dives logged at time of cert
    var cardImageFront: String?  // filename in documents dir
    var cardImageBack: String?   // filename in documents dir
    var notes: String?
    var isPrimary: Bool          // highest/active certification
    var createdAt: Date
    var updatedAt: Date
}

enum CertAgency: String, Codable, CaseIterable, DatabaseValueConvertible {
    case padi = "PADI"
    case ssi = "SSI"
    case naui = "NAUI"
    case bsac = "BSAC"
    case cmas = "CMAS"
    case gue = "GUE"
    case tdi = "TDI"
    case iantd = "IANTD"
    case other = "Other"

    var displayName: String { rawValue }
    var commonLevels: [String] { ... }
}
```

Common cert levels per agency (for picker):
- **PADI**: Open Water, Advanced Open Water, Rescue Diver, Divemaster, Instructor
- **SSI**: Open Water, Advanced Adventurer, Stress & Rescue, Dive Guide, Instructor
- **NAUI**: Scuba Diver, Advanced Scuba Diver, Master Scuba Diver, Instructor

Migration:
```swift
try db.create(table: "certifications") { t in
    t.primaryKey("id", .text).notNull()
    t.column("agency", .text).notNull()
    t.column("agencyOther", .text)
    t.column("level", .text).notNull()
    t.column("certNumber", .text)
    t.column("certDate", .date)
    t.column("expiryDate", .date)
    t.column("instructorName", .text)
    t.column("instructorNumber", .text)
    t.column("divesAtCert", .integer)
    t.column("cardImageFront", .text)
    t.column("cardImageBack", .text)
    t.column("notes", .text)
    t.column("isPrimary", .boolean).notNull().defaults(to: false)
    t.column("createdAt", .datetime).notNull()
    t.column("updatedAt", .datetime).notNull()
}
```

### Step 2: Cert Entry Form

```
┌─ Add Certification ─────────────┐
│                                 │
│ Agency     [PADI          ▾]    │
│ Level      [Advanced OW   ▾]    │
│ Cert #     [________________]   │
│ Date       [Dec 2023      ▾]    │
│                                 │
│ Instructor [________________]   │
│ Inst. #    [________________]   │
│                                 │
│ Card Photo                      │
│ ┌───────────┐ ┌───────────┐    │
│ │   Front   │ │   Back    │    │
│ │  [+ Add]  │ │  [+ Add]  │    │
│ └───────────┘ └───────────┘    │
│                                 │
│           [Save]                │
└─────────────────────────────────┘
```

Files:
- `FeatureSettings/Certifications/CertificationFormView.swift`
- `FeatureSettings/Certifications/CertificationFormViewModel.swift`
- `FeatureSettings/Certifications/AgencyPicker.swift`
- `FeatureSettings/Certifications/CertLevelPicker.swift`

### Step 3: Cert Display Card in Profile

A visually rich card that mimics a physical C-Card:

```
┌─────────────────────────────────┐
│ ┌─ PADI ──────────────────────┐ │
│ │                             │ │
│ │  ADVANCED OPEN WATER DIVER  │ │
│ │                             │ │
│ │  Cert #: 2312456789         │ │
│ │  Since: December 2023       │ │
│ │  Instructor: John Smith     │ │
│ │                             │ │
│ │  [View Card Photo]          │ │
│ └─────────────────────────────┘ │
│                                 │
│ + Add Another Certification     │
└─────────────────────────────────┘
```

Location in UI:
- Profile tab → "My Certifications" section
- Tappable to expand/view card photos full-screen
- Primary cert badge shown at top of profile

Files:
- `FeatureMap/Profile/CertificationCardView.swift`
- `FeatureMap/Profile/CertificationListView.swift`

### Step 4: Photo Capture

- Use `PhotosPicker` (iOS 17+) or camera via `UIImagePickerController`
- Store images in app's documents directory: `certifications/{certId}_front.jpg`
- Compress to reasonable size (max 1200px wide, JPEG quality 0.8)
- Show thumbnail in form, full-screen on tap

### Step 5: CloudKit Sync

- Add `SyncableRecord` conformance to `Certification`
- Sync card photos as `CKAsset` attachments
- Store in private CloudKit database (personal data)
- Sync cert data across user's devices

## Testing

- [ ] Add a cert with all fields, verify persistence
- [ ] Add cert with photo, verify storage + display
- [ ] Add multiple certs, verify list ordering (primary first)
- [ ] Edit existing cert, verify update
- [ ] Delete cert, verify photo cleanup
- [ ] Test agency picker → level picker cascade
- [ ] Verify cert appears in Profile tab

## Future Enhancements (Not in Scope)

- Agency API verification (PADI eCard API, SSI API)
- QR code on cert card for dive shop scanning
- Expiry notifications for time-limited certs (EFR, O2 Provider)
- Share cert as image or PDF
