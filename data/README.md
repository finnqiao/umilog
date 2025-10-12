# UmiLog Data Pipeline (MVP)

This folder bootstraps a minimal, reproducible pipeline to build a real dataset from public sources.

Scope (MVP)
- Pull real recreational dive sites from Wikidata (global) with coordinates and labels
- Convert to an app seed JSON (sites_wikidata.json) that the iOS app can ingest on first run
- Keep region/area simple: region is mapped from country; area uses the administrative unit label

Planned follow-ups (from the full plan)
- Shops: Overpass/OSM (bounded regions)
- Clustering into Areas with DBSCAN for better grouping
- Biodiversity: GBIF occurrences -> site/region species tables
- PostGIS path (schema.sql) with exports by geohash and MV refresh

Prereqs
- macOS with curl and python3 available (no Homebrew deps required for MVP)

Layout
- queries/dive_sites_wd.sparql  SPARQL to retrieve sites
- raw/                         Downloaded raw JSON
- stage/                       Intermediate transformed data
- export/                      Final files for the app
- scripts/wd_to_seed.py        Converts WD JSON → app seed format
- schema.sql                   Postgres/PostGIS DDL (reference; optional)

Make targets
- make wd-fetch           # fetch WD JSON into data/raw/wd_dives.json
- make wd-build-seed      # build Resources/SeedData/sites_wikidata.json from WD JSON
- make build-all          # fetch + build

Outputs
- Resources/SeedData/sites_wikidata.json (consumed by the app seed process)

Notes
- This MVP doesn’t run PostGIS. It gives you real sites to replace/augment mock data quickly.
- Region mapping is approximate (country → region bucket). You can refine this over time.

