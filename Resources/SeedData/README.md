# Seed Data

This directory contains JSON seed data files used to populate the UmiLog database with realistic test data for development and testing.

## Files Overview

### 📍 Dive Sites
- **`sites_seed.json`** - 9 core dive sites across Red Sea, Caribbean, and Mediterranean
- **`sites_extended.json`** - 15 additional world-famous dive sites including Southeast Asia and Pacific regions

**Total Sites:** 24 dive locations spanning global diving destinations

**Key Features:**
- Real coordinates and locations
- Realistic depth, temperature, and visibility data
- Variety of site types: Reef, Wreck, Cave, Pinnacle, Wall, Sinkhole, etc.
- Difficulty levels: Beginner, Intermediate, Advanced
- Some sites marked as visited (visitedCount > 0) for testing "My Map" feature
- Some sites on wishlist for testing wishlist filters

### 🐠 Wildlife Species
- **`species_catalog.json`** - 35 real marine species with scientific names

**Categories:** Fish, Reptile, Mammal, Invertebrate
**Rarity Levels:** Common, Uncommon, Rare, VeryRare
**Regional Distribution:** Species are tagged with regions where they can be found

### 📝 Dive Logs
- **`dive_logs_mock.json`** - 3 completed dive logs with realistic data

**Features:**
- Linked to real dive sites (Shark & Yolanda, Ras Mohammed, Richelieu Rock)
- Realistic dive profiles (depth, time, pressure, conditions)
- Mix of signed (by instructor) and unsigned dives
- Recent dates (Sept-Oct 2024)
- Detailed dive notes describing the experience

### 👁️ Wildlife Sightings
- **`sightings_mock.json`** - 19 wildlife sightings across the 3 dives

**Features:**
- Linked to dive logs via `diveId`
- Linked to species catalog via `speciesId`
- Realistic counts (individual specimens vs. schools)
- Optional notes describing the sighting

## Data Relationships

```
DiveSite (1) ----< (many) DiveLog
                              |
                              |
                              v
                         (many) WildlifeSighting
                              |
                              v
                         (1) WildlifeSpecies
```

## JSON Schema Reference

### DiveSite
```json
{
  "id": "string (UUID-like)",
  "name": "string",
  "region": "string",
  "area": "string",
  "country": "string",
  "latitude": "number",
  "longitude": "number",
  "averageDepth": "number (meters)",
  "maxDepth": "number (meters)",
  "averageTemp": "number (celsius)",
  "averageVisibility": "number (meters)",
  "difficulty": "Beginner | Intermediate | Advanced",
  "type": "Reef | Wreck | Wall | Cave | Sinkhole | etc.",
  "description": "string",
  "tags": ["array", "of", "strings"],
  "wishlist": "boolean",
  "visitedCount": "integer"
}
```

### WildlifeSpecies
```json
{
  "id": "string (UUID-like)",
  "name": "string",
  "scientificName": "string (binomial nomenclature)",
  "category": "Fish | Reptile | Mammal | Invertebrate",
  "rarity": "Common | Uncommon | Rare | VeryRare",
  "regions": ["array", "of", "region", "names"],
  "imageUrl": "string | null"
}
```

### DiveLog
```json
{
  "id": "string (UUID-like)",
  "siteId": "string (FK to DiveSite)",
  "date": "ISO 8601 date string",
  "startTime": "ISO 8601 datetime string",
  "endTime": "ISO 8601 datetime string | null",
  "maxDepth": "number (meters)",
  "averageDepth": "number (meters) | null",
  "bottomTime": "integer (minutes)",
  "startPressure": "integer (bar)",
  "endPressure": "integer (bar)",
  "temperature": "number (celsius)",
  "visibility": "number (meters)",
  "current": "None | Light | Moderate | Strong",
  "conditions": "Excellent | Good | Fair | Poor",
  "notes": "string",
  "instructorName": "string | null",
  "instructorNumber": "string | null",
  "signed": "boolean",
  "createdAt": "ISO 8601 datetime string",
  "updatedAt": "ISO 8601 datetime string"
}
```

### WildlifeSighting
```json
{
  "id": "string (UUID-like)",
  "diveId": "string (FK to DiveLog)",
  "speciesId": "string (FK to WildlifeSpecies)",
  "count": "integer",
  "notes": "string | null",
  "createdAt": "ISO 8601 datetime string"
}
```

## Usage in Code

These files should be loaded by the `DatabaseSeeder` during first launch or when the database is empty.

### Example Loader Logic
```swift
// 1. Check if database is empty
if sitesRepository.isEmpty() {
    // 2. Load seed files
    let seedSites = loadJSON("sites_seed")
    let extendedSites = loadJSON("sites_extended")
    
    // 3. Insert into database
    await sitesRepository.bulkInsert(seedSites + extendedSites)
}

// Similar pattern for species, dives, and sightings
```

## Testing Scenarios Covered

✅ **Map View**
- 24 pins across multiple regions
- Mix of visited and unvisited sites
- Wishlist filtering
- "My Map" vs "Nearby" modes

✅ **Dive History**
- 3 completed dives to display
- Signed vs unsigned status
- Different dive conditions
- Wildlife sightings per dive

✅ **Wildlife Catalog**
- 35 species across all categories
- Rarity filtering
- Region-based filtering
- Pokédex-style collection tracking

✅ **Dive Detail View**
- Full dive statistics
- Linked site information
- Wildlife sightings with counts
- Instructor sign-off display

## Data Sources

All data is based on real-world dive sites and marine species:
- GPS coordinates verified from dive site databases
- Species scientific names from marine biology references
- Dive profiles match realistic recreational diving parameters
- Descriptions reflect actual site characteristics

## Maintenance

When adding new mock data:
1. Maintain consistent ID format (`site_*`, `species_*`, `dive_*`, `sighting_*`)
2. Ensure foreign key relationships are valid
3. Use realistic values within expected ranges
4. Include proper ISO 8601 date formatting
5. Update the `meta` section with generation timestamp

## Notes

- All temperatures are in Celsius
- All depths are in meters
- All pressures are in bar (standard scuba metric)
- Dates use ISO 8601 format with UTC timezone
- Enum values must match Swift enum cases exactly (case-sensitive)
