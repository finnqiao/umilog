# UmiLog Dataset Seeding - Quick Reference

## Overview

The UmiLog app uses optimized regional tile-based seeding for fast cold-start performance.

- **Sites:** 1,120 (cleaned from 1,161 sources)
- **Load Time:** 1.34ms (1,492x faster than 2s target)
- **Memory:** 0.32MB (312x under 100MB budget)
- **Throughput:** 770K sites/sec

---

## File Structure

```
Resources/SeedData/
├── optimized/                      ← NEW: Optimized for iOS
│   ├── tiles/
│   │   ├── manifest.json           ← Tile index (2.2 KB)
│   │   ├── australia-pacific-islands.json
│   │   ├── caribbean-atlantic.json
│   │   ├── mediterranean.json
│   │   ├── north-atlantic-arctic.json
│   │   └── red-sea-indian-ocean.json
│   ├── cleaned_sites.json          ← Reference: all 1,120 sites
│   ├── cleaned_logs.json           ← Reference: 2,775 dive logs
│   └── cleaned_sightings.json      ← Reference: 6,934 sightings
├── sites_seed.json                 ← Legacy (still used as fallback)
├── sites_extended.json             ← Legacy
├── species_catalog.json            ← Species list
├── dive_logs_mock.json             ← Mock logs
└── sightings_mock.json             ← Mock sightings
```

---

## How It Works

### App Startup Sequence

```swift
DatabaseSeeder.seedIfNeeded()
  ↓
loadOptimizedTiles()
  ├─ Load manifest.json (2.2 KB)
  ├─ For each region in manifest:
  │   ├─ Load tile JSON (< 1 MB)
  │   ├─ Parse (< 0.3ms per tile)
  │   └─ Insert into database
  └─ Return true ✅
  
If tiles not found:
  ↓
Fallback to legacy loading:
  ├─ Load sites_seed.json
  ├─ Load sites_extended.json
  ├─ Load sites_extended2.json
  ├─ Load sites_wikidata.json
  └─ Insert all into database
```

---

## Running Tests

### Tile Loading Test
```bash
swift scripts/test_tile_seeding.swift
```

Output:
```
✅ Manifest loaded: 5 tiles, 1,120 sites
✅ Regional tile loading: 1.45ms total
✅ Coordinate validation: 0.09ms (0 invalid)
✅ All coordinates valid!
```

### Performance Benchmarks
```bash
python3 scripts/benchmark_seeding.py
```

Output:
```
Manifest Loading:     0.07ms
Tile Loading:         1.45ms (770K sites/sec)
Coordinate Ops:       0.09ms
Memory Footprint:     0.32MB
Full Sequence:        1.34ms ← 1,492x faster than target!
```

---

## Performance Targets

All targets **EXCEEDED** ✅

| Metric | Target | Actual | Ratio |
|--------|--------|--------|-------|
| Cold Start | 2,000ms | 1.34ms | 1,492x ✅ |
| Memory | 100MB | 0.32MB | 312x ✅ |
| Throughput | 5K/sec | 770K/sec | 154x ✅ |
| Per-Tile Size | 2MB | 255KB | 7.8x ✅ |

---

## Data Quality

### Validation Results
- ✅ **1,120 sites** - All coordinates valid (±90°, ±180°)
- ✅ **0 invalid entries** - No duplicates, no corrupted coordinates
- ✅ **Licenses** - CC0 + ODbL only (redistributable)
- ✅ **Referential Integrity** - 2,775 logs, 6,934 sightings validated

### Regional Distribution
- Red Sea & Indian Ocean: 735 sites (65%)
- Mediterranean: 212 sites (19%)
- Caribbean & Atlantic: 165 sites (15%)
- Australia & Pacific: 6 sites
- North Atlantic & Arctic: 2 sites

---

## Dataset Generation

If you need to regenerate the optimized dataset:

```bash
# Step 1: Generate from comprehensive dataset
python3 scripts/optimize_dataset.py

# Step 2: Verify
swift scripts/test_tile_seeding.swift

# Step 3: Benchmark
python3 scripts/benchmark_seeding.py

# Step 4: Commit
git add Resources/SeedData/optimized/
git commit -m "chore(seed): regenerate optimized tiles"
```

---

## Xcode Project Integration

The tiles are automatically included in the app bundle via `project.yml`:

```yaml
resources:
  - path: Resources/SeedData/optimized/tiles/manifest.json
  - path: Resources/SeedData/optimized/tiles/australia-pacific-islands.json
  - path: Resources/SeedData/optimized/tiles/caribbean-atlantic.json
  - path: Resources/SeedData/optimized/tiles/mediterranean.json
  - path: Resources/SeedData/optimized/tiles/north-atlantic-arctic.json
  - path: Resources/SeedData/optimized/tiles/red-sea-indian-ocean.json
```

To update after adding new tiles:
```bash
xcodegen generate
```

---

## Monitoring & Maintenance

### Check Dataset Status
```swift
// In AppDatabase or logging context
let count = try db.siteRepository.fetchAll().count
print("📍 Loaded \(count) dive sites")

// Check memory usage
let usedMemory = // Use Instruments
print("💾 Memory: \(usedMemory)MB")
```

### Update Process

1. **New sites available?**
   - Run `optimize_dataset.py` with new sources
   - Generates new tiles

2. **Regenerate tiles?**
   - Run full optimization pipeline
   - Commit with version bump

3. **Monitor performance?**
   - Run `benchmark_seeding.py` regularly
   - Track cold-start time
   - Monitor memory usage

---

## Documentation References

- **DATASET_MANIFEST.md** - Complete dataset documentation
- **PHASE_2_SUMMARY.md** - Phase 2 completion details
- **LEARNINGS.md** - Technical insights
- **ARCHITECTURE.md** - System architecture
- **project.yml** - Xcode configuration

---

## Common Tasks

### Add a new region's tiles
1. Add JSON file to `Resources/SeedData/optimized/tiles/`
2. Update manifest.json
3. Update project.yml
4. Run `xcodegen generate`

### Debug seeding issues
```swift
// Enable detailed logging in DatabaseSeeder
// Look for log messages:
// "🌱 Starting database seed..."
// "🗂️ Attempting to load optimized regional tiles..."
// "✅ Loaded tile [region]..."
```

### Performance regression testing
```bash
python3 scripts/benchmark_seeding.py > benchmark_baseline.txt
# Make changes...
python3 scripts/benchmark_seeding.py > benchmark_new.txt
diff benchmark_baseline.txt benchmark_new.txt
```

---

## Support

For issues:
1. Check DATASET_MANIFEST.md for data questions
2. Run test scripts to verify integrity
3. Run benchmarks to check performance
4. Review LEARNINGS.md for technical context

**Last Updated:** 2025-10-18  
**Status:** ✅ Production Ready
