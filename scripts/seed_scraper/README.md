# Dive Site Data Scraper

> Open-source data acquisition pipeline for UmiLog. Harvests 100-150+ world-class dive sites from licensed sources with full provenance tracking and compliance validation.

## Quick Start

```bash
cd scripts/seed_scraper
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run the full pipeline
python3 run_pipeline.sh
```

## Data Sources (Open & Licensed)

| Source | License | Coverage | Fields |
|--------|---------|----------|--------|
| **Wikidata** | CC0 | 100-150 sites | name, coords, depth, country |
| **OpenStreetMap** | ODbL | 50-100 sites | name, coords, type |
| **Wikivoyage** | CC-BY-SA 3.0 | 40-80 sites | name, description, depth hints |
| **OBIS** | Various | Species agg. | top taxa per site buffer |

**Total Expected**: 200-250 candidates → Deduplicated to 100-150 curated sites

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ STAGE 1: Data Acquisition (1-2 hours)                       │
├─────────────────────────────────────────────────────────────┤
│  wikidata_sites.py          OSM Overpass API  Wikivoyage    │
│  ↓                          ↓                 ↓             │
│  scraped/wikidata.json      osm.json         wikivoyage.json│
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ STAGE 2: Deduplication & Merging (30 min)                   │
├─────────────────────────────────────────────────────────────┤
│  dedupe_merge.py                                            │
│  - H3-10 spatial bucketing (~250m cells)                    │
│  - DBSCAN clustering                                        │
│  - Jaro-Winkler name matching (≥0.92)                      │
│  ↓                                                          │
│  scraped/merged.json (~250 candidates)                      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ STAGE 3: Quality Assurance & Validation (1 hour)            │
├─────────────────────────────────────────────────────────────┤
│  validate_curate.py                                         │
│  - Coordinate validation (not on land)                      │
│  - Depth sanity (5-130m)                                    │
│  - Visibility/temp plausibility                             │
│  ↓                                                          │
│  qa_report.json (outliers flagged)                          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ STAGE 4: Manual Curation (2-4 hours)                        │
├─────────────────────────────────────────────────────────────┤
│  Human Review & Enrichment:                                 │
│  - Fill missing fields (description, tags, entry modes)     │
│  - Assign difficulty (beginner/intermediate/advanced)      │
│  - Find CC-licensed images (Commons)                        │
│  - Verify regional quotas                                   │
│  ↓                                                          │
│  Resources/SeedData/curated_sites.json (100-150 final)     │
└─────────────────────────────────────────────────────────────┘
```

## Scripts

### 1. `wikidata_sites.py`
Harvests dive sites from Wikidata SPARQL endpoint.
- **Input**: None (queries online)
- **Output**: `scraped/wikidata_sites.json`
- **Time**: ~2-5 min
- **License**: CC0
- **Sites**: ~100-150 candidates

```bash
python3 wikidata_sites.py
```

### 2. `osm_overpass_sites.py`
Queries OpenStreetMap for sport=diving tags.
- **Input**: None (queries Overpass API)
- **Output**: `scraped/osm_sites.json`
- **Time**: ~5-10 min
- **License**: ODbL
- **Sites**: ~50-100 candidates

```bash
python3 osm_overpass_sites.py
```

### 3. `wikivoyage_scraper.py`
Scrapes Wikivoyage regional dive articles.
- **Input**: None (queries Wikivoyage HTML)
- **Output**: `scraped/wikivoyage_sites.json`
- **Time**: ~10-15 min
- **License**: CC-BY-SA 3.0
- **Sites**: ~40-80 candidates

```bash
python3 wikivoyage_scraper.py
```

### 4. `dedupe_merge.py`
Merges & deduplicates from all sources.
- **Input**: `scraped/{wikidata,osm,wikivoyage}_sites.json`
- **Output**: `scraped/merged.json` (~250 candidates)
- **Algorithm**: H3-10 bucketing + DBSCAN + Jaro-Winkler ≥0.92
- **Time**: ~5 min

```bash
python3 dedupe_merge.py
```

### 5. `validate_curate.py`
QA validation & flagging.
- **Input**: `scraped/merged.json`
- **Output**: `qa_report.json`, `scraped/validated.json`
- **Checks**:
  - Coordinates in water (reverse geocode or water mask)
  - Depth 5–130m (recreational diving)
  - Visibility 3–60m
  - Temp 0–35°C
  - Name uniqueness
- **Time**: ~5-10 min

```bash
python3 validate_curate.py
```

### 6. Manual Curation
1. Open `scraped/validated.json`
2. Review & enrich fields:
   - Add descriptions from Wikivoyage
   - Assign 2-5 tags from controlled vocabulary
   - Set difficulty (beginner/intermediate/advanced)
   - Set entry modes (boat/shore/liveaboard)
   - Find 1+ CC-licensed images (Wikimedia Commons)
3. Select 100-150 per regional quotas (Red Sea, Caribbean, SEA, Pacific, Med, Indian Ocean, Other)
4. Save as `Resources/SeedData/curated_sites.json`

## Full Pipeline Runbook

```bash
#!/bin/bash
set -e

cd scripts/seed_scraper

echo "🌊 Starting full dive site scraping pipeline..."

# Stage 1: Acquire data from all sources
echo "📍 Stage 1: Data Acquisition"
python3 wikidata_sites.py
python3 osm_overpass_sites.py
python3 wikivoyage_scraper.py

# Stage 2: Deduplicate & merge
echo "🔄 Stage 2: Deduplication"
python3 dedupe_merge.py

# Stage 3: Validate
echo "✅ Stage 3: Quality Assurance"
python3 validate_curate.py

# Stage 4: Manual review (interactive)
echo "👤 Stage 4: Manual Curation"
echo "Review scraped/validated.json and manually enhance/select 100-150 sites"
echo "Save final result to ../../Resources/SeedData/curated_sites.json"

# Generate attribution file
echo "📋 Stage 5: Attribution"
python3 generate_attribution.py
```

## Data Schema

### Input (from scrapers)
```json
{
  "sites": [
    {
      "id": "wiki_Q123456",
      "name": "Blue Hole",
      "latitude": 17.315,
      "longitude": -87.534,
      "maxDepth": 124,
      "description": "Iconic sinkhole...",
      "country": "Belize",
      "source": "Wikidata",
      "source_url": "https://www.wikidata.org/...",
      "license": "CC0",
      "retrieved_at": "2025-10-18T13:00:00Z"
    }
  ]
}
```

### Output (curated_sites.json)
```json
{
  "sites": [
    {
      "id": "site_blue_hole_bz",
      "name": "Blue Hole",
      "region": "Caribbean",
      "area": "Belize Barrier Reef",
      "country": "Belize",
      "latitude": 17.315,
      "longitude": -87.534,
      "type": "blue-hole",
      "description": "Iconic sinkhole...",
      "minDepth": 6,
      "maxDepth": 124,
      "difficulty": "advanced",
      "tags": ["sinkhole", "deep", "iconic", "technical"],
      "facets": {
        "entry_modes": ["boat"],
        "notable_features": ["sinkhole", "cave"],
        "visibility_mean": 30,
        "temp_mean": 27,
        "seasonality_json": {"peakMonths": ["Mar", "Apr", "May"]},
        "has_current": false,
        "shop_count": 5
      },
      "media": [
        {
          "kind": "photo",
          "url": "https://commons.wikimedia.org/...",
          "license": "CC-BY-4.0",
          "attribution": "Photographer Name"
        }
      ],
      "provenance": {
        "sources": [
          {"name": "Wikidata", "url": "https://www.wikidata.org/...", "license": "CC0"},
          {"name": "Wikivoyage", "url": "https://en.wikivoyage.org/...", "license": "CC-BY-SA 3.0"}
        ]
      }
    }
  ]
}
```

## Licensing & Compliance

### Open Sources (Redistributable)
- ✅ **Wikidata**: CC0 (public domain)
- ✅ **OpenStreetMap**: ODbL (open database license)
- ✅ **Wikivoyage**: CC-BY-SA 3.0 (share-alike required)
- ✅ **OBIS aggregates**: Use only derived stats, not raw occurrences

### Attribution Requirements
- Store per-source license and URL in `provenance` field
- Auto-generate `attribution.json` with all credits
- Display in app's About screen

### Restricted (Internal Only)
- ⛔ PADI Travel, Dive.site, Diveboard (commercial/ToS issues)
- Mark as `non_redistributable` if included
- Never scrape commercial listings

## Configuration

`config.json`:
```json
{
  "rate_limit_seconds": 2,
  "validate_coordinates": true,
  "water_mask": "gebco/coastline.shp",
  "depth_min": 5,
  "depth_max": 130,
  "visibility_min": 3,
  "visibility_max": 60,
  "temp_min": 0,
  "temp_max": 35,
  "dedup_h3_resolution": 10,
  "name_similarity_threshold": 0.92
}
```

## Requirements

```txt
requests>=2.28.0
h3>=3.7.0
python-Levenshtein>=0.20.0
geopy>=2.3.0
beautifulsoup4>=4.11.0
lxml>=4.9.0
```

Install:
```bash
pip install -r requirements.txt
```

## Troubleshooting

### Q: Wikidata query times out
**A**: Wikidata is under load. Wait 5-10 minutes and retry. SPARQL queries can take 30s+.

### Q: OSM Overpass API returns 429 (rate limited)
**A**: Built-in backoff handles this. Wait or reduce `--rate-limit` from 2s to 5s.

### Q: Coordinates on land?
**A**: GEBCO shoreline buffer is imperfect. Manual review flagged outliers for human approval.

### Q: Missing species for a site?
**A**: OBIS aggregates are regional. Some sites have sparse records. Check manually or leave empty.

## Performance Notes

| Stage | Time | Input Sites | Output |
|-------|------|-------------|--------|
| Wikidata | 2-5 min | API | ~150 |
| OSM | 5-10 min | API | ~80 |
| Wikivoyage | 10-15 min | HTML | ~50 |
| Merge | 5 min | 280 | 250 |
| Validate | 5-10 min | 250 | 250 + report |
| **Total** | **30-45 min** | | **~250 candidates** |
| Manual (human) | 2-4 hours | 250 | **100-150 final** |

**Final**: 100-150 curated sites ready for app integration

## Next Steps (Phase 2)

- Automate scraping on GitHub Actions (weekly)
- Build PostgreSQL pipeline for 500+ sites
- Integrate OBIS species checklists
- Add MPA/reef overlay data
- Serve via CDN with incremental diffs

---

*For questions or licensing issues, contact team@umilog.app*
