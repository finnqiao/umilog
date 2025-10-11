# Mock Data Specification for UmiLog

This document outlines all data types, schemas, and mock data requirements for testing the map-first refactor.

## 📊 Data Types Overview

### 1. **Dive Sites** (Primary)
### 2. **Dive Logs** (Historical dives)
### 3. **Wildlife Species** (Catalog)
### 4. **Wildlife Sightings** (Per dive)
### 5. **Operators** (Future - dive centers)

---

## 1. 🗺️ Dive Sites

### Schema (Current)
```swift
DiveSite {
    id: String              // UUID
    name: String            // "Shark & Yolanda Reef"
    location: String        // "Sharm el-Sheikh, Egypt"
    latitude: Double        // 27.7833
    longitude: Double       // 34.3167
    region: String          // "Red Sea"
    averageDepth: Double    // 18.0 (meters)
    maxDepth: Double        // 30.0 (meters)
    averageTemp: Double     // 26.0 (celsius)
    averageVisibility: Double // 30.0 (meters)
    difficulty: Difficulty  // .beginner | .intermediate | .advanced
    type: SiteType         // .reef | .wreck | .wall | .cave | .shore | .drift
    description: String?    // "Famous for shark encounters..."
    wishlist: Bool         // false
    visitedCount: Int      // 0 (user-specific)
    createdAt: Date
}
```

### Enhanced Schema (For Import Compatibility)
```json
{
  "id": "site_shark_yolanda",
  "name": "Shark & Yolanda Reef",
  "location": "Sharm el-Sheikh, Egypt",
  "latitude": 27.7833,
  "longitude": 34.3167,
  "region": "Red Sea",
  "ocean": "Red Sea",
  "country": "Egypt",
  "area": "Sharm el-Sheikh",
  "averageDepth": 18.0,
  "maxDepth": 30.0,
  "averageTemp": 26.0,
  "averageVisibility": 30.0,
  "difficulty": "Advanced",
  "type": "Reef",
  "description": "Famous for shark encounters and the sunken Yolanda cargo",
  "tags": ["sharks", "wreck", "drift"],
  "wishlist": false,
  "visitedCount": 0
}
```

### Mock Data Needed
**Coverage Goals:**
- **3 regions** minimum: Red Sea, Caribbean, Mediterranean
- **20-30 sites total** for realistic map density
- **Mix of difficulties**: 30% Beginner, 50% Intermediate, 20% Advanced
- **Mix of types**: Reefs (60%), Wrecks (20%), Others (20%)
- **2-3 sites marked as visited** (visitedCount > 0) for testing My Map
- **1-2 sites on wishlist** for testing wishlist filters

**Key Test Sites:**
1. **Shark & Yolanda Reef** (Red Sea) - Advanced, Reef - VISITED
2. **Blue Hole Dahab** (Red Sea) - Advanced, Sinkhole
3. **Ras Mohammed** (Red Sea) - Advanced, Wall - VISITED
4. **Palancar Reef** (Caribbean) - Beginner, Reef
5. **Great Blue Hole** (Caribbean) - Advanced, Sinkhole - WISHLIST
6. **Blue Grotto Malta** (Mediterranean) - Intermediate, Cave

---

## 2. 📝 Dive Logs

### Schema (Current)
```swift
DiveLog {
    id: String
    siteId: String         // FK to DiveSite
    date: Date            // 2024-10-05
    startTime: Date       // 09:30
    endTime: Date?        // 10:15
    maxDepth: Double      // 28.0 meters
    averageDepth: Double? // 19.6 meters
    bottomTime: Int       // 45 minutes
    startPressure: Int    // 200 bar
    endPressure: Int      // 60 bar
    temperature: Double   // 26.0°C
    visibility: Double    // 30.0 meters
    current: Current      // .none | .light | .moderate | .strong
    conditions: Conditions // .excellent | .good | .fair | .poor
    notes: String         // "Amazing dive! Saw..."
    instructorName: String?
    instructorNumber: String?
    signed: Bool
    createdAt: Date
    updatedAt: Date
}
```

### Mock Data Needed
**Coverage Goals:**
- **2-3 completed dives** for testing History view
- **1 signed dive** by instructor for testing sign-off feature
- **Mix of conditions** for chip display testing
- **Recent dates** (within last month) for realistic testing

**Example Dives:**
1. **Shark & Yolanda Reef** - Oct 5, 2024 09:30
   - Max depth: 28m, 45min, 26°C
   - Moderate current
   - Signed by instructor
   - Wildlife: Hammerhead, Napoleon Wrasse, Barracuda

2. **Ras Mohammed** - Oct 5, 2024 14:00
   - Max depth: 32m, 50min, 25°C
   - Strong current
   - Not signed
   - Wildlife: Eagle Ray, Barracuda, Sea Turtle

---

## 3. 🐠 Wildlife Species (Catalog)

### Schema (Current)
```swift
WildlifeSpecies {
    id: String
    name: String           // "Scalloped Hammerhead"
    scientificName: String // "Sphyrna lewini"
    category: Category     // .fish | .coral | .mammal | .invertebrate | .reptile
    rarity: Rarity        // .common | .uncommon | .rare | .veryRare
    regions: [String]     // ["Red Sea", "Caribbean"]
    imageUrl: String?     // Optional
}
```

### Mock Data Needed
**Coverage Goals:**
- **20-30 species** across all categories
- **Regional distribution** matching dive sites
- **Mix of rarities** for Pokédex display
- **Popular species** that appear in multiple regions

**Red Sea Species (10):**
1. Scalloped Hammerhead - Fish, Rare
2. Napoleon Wrasse - Fish, Uncommon
3. Great Barracuda - Fish, Common
4. Spotted Eagle Ray - Fish, Uncommon
5. Green Sea Turtle - Reptile, Common
6. Moray Eel - Fish, Common
7. Lionfish - Fish, Common
8. Octopus - Invertebrate, Common
9. Coral Grouper - Fish, Common
10. Stingray - Fish, Common

**Caribbean Species (10):**
1. Green Sea Turtle - Reptile, Common
2. Caribbean Reef Shark - Fish, Uncommon
3. Spotted Eagle Ray - Fish, Uncommon
4. Queen Angelfish - Fish, Common
5. Nassau Grouper - Fish, Uncommon
6. Barracuda - Fish, Common
7. Nurse Shark - Fish, Common
8. Dolphin - Mammal, Rare
9. Moray Eel - Fish, Common
10. Octopus - Invertebrate, Common

**Mediterranean Species (10):**
1. Octopus - Invertebrate, Common
2. Grouper - Fish, Common
3. Moray Eel - Fish, Common
4. Barracuda - Fish, Common
5. Tuna - Fish, Uncommon
6. Sea Turtle - Reptile, Uncommon
7. Jellyfish - Invertebrate, Common
8. Sea Bass - Fish, Common
9. Damselfish - Fish, Common
10. Lobster - Invertebrate, Common

---

## 4. 👁️ Wildlife Sightings

### Schema (Current)
```swift
WildlifeSighting {
    id: String
    diveId: String        // FK to DiveLog
    speciesId: String     // FK to WildlifeSpecies
    count: Int           // Number seen
    notes: String?       // "School of ~20"
    createdAt: Date
}
```

### Mock Data Needed
**Coverage Goals:**
- **5-8 sightings per dive** for realistic diversity
- **Mix of counts**: Single specimens and schools
- **Link to existing dives** in mock data

**Dive 1 Sightings (Shark & Yolanda):**
1. Scalloped Hammerhead - count: 2
2. Napoleon Wrasse - count: 1
3. Great Barracuda - count: 15 (school)
4. Green Sea Turtle - count: 1
5. Lionfish - count: 3

**Dive 2 Sightings (Ras Mohammed):**
1. Spotted Eagle Ray - count: 1
2. Great Barracuda - count: 20 (school)
3. Green Sea Turtle - count: 2
4. Moray Eel - count: 1
5. Coral Grouper - count: 5

---

## 5. 🏢 Dive Operators (Future)

### Proposed Schema
```swift
DiveOperator {
    id: String
    name: String          // "Blue Horizon Dive Center"
    city: String         // "Hurghada"
    country: String      // "Egypt"
    latitude: Double
    longitude: Double
    affiliates: [String] // ["PADI", "SSI"]
    rating: Double?      // 4.8
    website: String?
    phone: String?
    email: String?
}
```

### Mock Data (For Future Implementation)
**Not needed for current phase** - but plan for:
- 3-5 operators per major region
- PADI/SSI certifications
- Linked to nearby dive sites

---

## 📦 Data Files Structure

### Recommended File Organization
```
Resources/SeedData/
├── sites_seed.json           ✅ Already exists (9 sites)
├── sites_extended.json       🆕 Additional 20 sites
├── species_catalog.json      🆕 30 species
├── dive_logs_mock.json       🆕 3 example dives
├── sightings_mock.json       🆕 Linked sightings
└── operators_future.json     ⏳ Future use
```

---

## 🎯 Priority Order for Mock Data Creation

### Phase 1: Immediate (For Testing Map Views) ✅
- [x] **9 dive sites** already created in `sites_seed.json`
- [ ] Expand to **25 total sites** with better geographic coverage
- [ ] Mark 2-3 sites as **visited** (visitedCount > 0)
- [ ] Mark 1-2 sites as **wishlist**

### Phase 2: High Priority (For Testing Wizard & History)
- [ ] **30 wildlife species** catalog
- [ ] **3 completed dive logs** with realistic data
- [ ] **10-15 wildlife sightings** linked to dives

### Phase 3: Nice to Have
- [ ] Additional sites for density
- [ ] Operator data (future)
- [ ] More historical dives for scrolling tests

---

## 🔄 Import Strategy

### Database Seeder Logic
```swift
DatabaseSeeder {
    1. Check if sites table is empty
    2. If empty:
       - Load sites_seed.json
       - Load sites_extended.json (if exists)
       - Insert all sites
    3. Check if species table is empty
    4. If empty:
       - Load species_catalog.json
       - Insert all species
    5. Check if dives table is empty
    6. If empty:
       - Load dive_logs_mock.json
       - Insert dives
       - Load sightings_mock.json
       - Insert sightings
}
```

### JSON Import Mapper
Handle field name differences:
- Your schema: `location` → Import format: `Location` (case)
- Your schema: `region` → Import format: `region` + `ocean`
- Your schema: compound `location` → Import: separate `city`, `country`

---

## 📝 Next Steps

1. **Expand sites_seed.json** with 15-20 more sites
2. **Create species_catalog.json** with 30 species
3. **Create dive_logs_mock.json** with 2-3 dives
4. **Create sightings_mock.json** linking dives to species
5. **Update DatabaseSeeder.swift** to load all files on first launch
6. **Test data loading** in simulator
7. **Verify map displays** pins correctly
8. **Verify wizard** can select from species
9. **Verify history** shows dives with stats

---

## 🔍 Data Validation Checklist

- [ ] All site coordinates are valid (lat: -90 to 90, lng: -180 to 180)
- [ ] All depth values are realistic (<150m for recreational)
- [ ] All temperature values match regions (Red Sea: 24-28°C, etc.)
- [ ] All dates are recent (within last 3 months for testing)
- [ ] All foreign keys match (siteId, speciesId, diveId)
- [ ] All enum values match Swift enums exactly (case-sensitive)
- [ ] All visitedCount values make sense (0 for unvisited, 1+ for visited)
- [ ] Region names are consistent across sites and species

---

**Ready to generate mock data files?** Let me know which phase to start with!
