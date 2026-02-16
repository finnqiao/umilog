#!/usr/bin/env python3
"""
Generate pre-seeded SQLite database for UmiLog iOS app.

This script creates a ready-to-use database with all seed data pre-loaded,
eliminating the need for JSON parsing and individual inserts at runtime.

Usage:
    python3 scripts/generate_seed_db.py [output_path]

Output:
    Resources/SeedDB/umilog_seed.db (default)
"""

import json
import os
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent
SEED_DATA_DIR = PROJECT_ROOT / "Resources" / "SeedData"
OUTPUT_DIR = PROJECT_ROOT / "Resources" / "SeedDB"
DEFAULT_OUTPUT = OUTPUT_DIR / "umilog_seed.db"


def log(msg: str):
    """Print timestamped log message."""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")


def load_json(filename: str) -> dict | list | None:
    """Load JSON file from SeedData directory."""
    path = SEED_DATA_DIR / f"{filename}.json"
    if not path.exists():
        log(f"  Warning: {filename}.json not found")
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def create_schema(conn: sqlite3.Connection):
    """Create database schema matching iOS app migrations v1-v9."""
    cursor = conn.cursor()

    # GRDB migration tracking table - must be created first
    # This tells GRDB which migrations have already been applied
    cursor.execute("""
        CREATE TABLE grdb_migrations (
            identifier TEXT NOT NULL PRIMARY KEY
        )
    """)

    # v1: Sites table
    cursor.execute("""
        CREATE TABLE sites (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            location TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            region TEXT NOT NULL,
            averageDepth REAL NOT NULL,
            maxDepth REAL NOT NULL,
            averageTemp REAL NOT NULL,
            averageVisibility REAL NOT NULL,
            difficulty TEXT NOT NULL,
            type TEXT NOT NULL,
            description TEXT,
            wishlist INTEGER NOT NULL DEFAULT 0,
            visitedCount INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            tags TEXT NOT NULL DEFAULT '[]',
            country_id TEXT,
            region_id TEXT,
            area_id TEXT,
            wikidata_id TEXT,
            osm_id TEXT,
            isPlanned INTEGER NOT NULL DEFAULT 0
        )
    """)

    # Sites indexes
    cursor.execute("CREATE INDEX idx_sites_location ON sites(latitude, longitude)")
    cursor.execute("CREATE INDEX idx_sites_region ON sites(region)")
    cursor.execute("CREATE INDEX idx_sites_wishlist ON sites(wishlist)")
    cursor.execute("CREATE INDEX idx_sites_difficulty ON sites(difficulty)")
    cursor.execute("CREATE INDEX idx_sites_type ON sites(type)")
    cursor.execute("CREATE INDEX idx_sites_lat_lon ON sites(latitude, longitude)")
    cursor.execute("CREATE INDEX idx_sites_country ON sites(country_id)")
    cursor.execute("CREATE INDEX idx_sites_region_id ON sites(region_id)")
    cursor.execute("CREATE INDEX idx_sites_area_id ON sites(area_id)")
    cursor.execute("CREATE INDEX idx_sites_planned ON sites(isPlanned)")

    # v1: Dives table (with v6 modifications for GPS drafts)
    cursor.execute("""
        CREATE TABLE dives (
            id TEXT PRIMARY KEY,
            siteId TEXT REFERENCES sites(id) ON DELETE RESTRICT,
            pendingLatitude REAL,
            pendingLongitude REAL,
            date TEXT NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT,
            maxDepth REAL NOT NULL,
            averageDepth REAL,
            bottomTime INTEGER NOT NULL,
            startPressure INTEGER NOT NULL,
            endPressure INTEGER NOT NULL,
            temperature REAL NOT NULL,
            visibility REAL NOT NULL,
            current TEXT NOT NULL,
            conditions TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            instructorName TEXT,
            instructorNumber TEXT,
            signed INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            CHECK (siteId IS NOT NULL OR (pendingLatitude IS NOT NULL AND pendingLongitude IS NOT NULL))
        )
    """)
    cursor.execute("CREATE INDEX idx_dives_start_time ON dives(startTime)")
    cursor.execute("CREATE INDEX idx_dives_site ON dives(siteId)")
    cursor.execute("CREATE INDEX idx_dives_date ON dives(date)")
    cursor.execute("CREATE INDEX idx_dives_pending_gps ON dives(pendingLatitude, pendingLongitude)")

    # v1: Wildlife species table (with v5 additions)
    cursor.execute("""
        CREATE TABLE wildlife_species (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            scientificName TEXT NOT NULL,
            category TEXT NOT NULL,
            rarity TEXT NOT NULL,
            regions TEXT NOT NULL,
            imageUrl TEXT,
            family_id TEXT,
            conservation_status TEXT,
            description TEXT,
            thumbnail_url TEXT,
            worms_aphia_id INTEGER,
            gbif_key INTEGER,
            fishbase_id INTEGER
        )
    """)
    cursor.execute("CREATE INDEX idx_species_category ON wildlife_species(category)")
    cursor.execute("CREATE INDEX idx_species_rarity ON wildlife_species(rarity)")
    cursor.execute("CREATE INDEX idx_species_family ON wildlife_species(family_id)")
    cursor.execute("CREATE INDEX idx_species_scientific ON wildlife_species(scientificName)")

    # v1: Sightings table
    cursor.execute("""
        CREATE TABLE sightings (
            id TEXT PRIMARY KEY,
            diveId TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
            speciesId TEXT NOT NULL REFERENCES wildlife_species(id) ON DELETE RESTRICT,
            count INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            createdAt TEXT NOT NULL
        )
    """)
    cursor.execute("CREATE INDEX idx_sightings_dive ON sightings(diveId)")
    cursor.execute("CREATE INDEX idx_sightings_species ON sightings(speciesId)")

    # v3: Site tags table
    cursor.execute("""
        CREATE TABLE site_tags (
            site_id TEXT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
            tag TEXT NOT NULL,
            PRIMARY KEY (site_id, tag) ON CONFLICT REPLACE
        )
    """)
    cursor.execute("CREATE INDEX idx_site_tags_tag ON site_tags(tag)")

    # v4: Site facets
    cursor.execute("""
        CREATE TABLE site_facets (
            site_id TEXT PRIMARY KEY REFERENCES sites(id) ON DELETE CASCADE,
            difficulty TEXT NOT NULL,
            entry_modes TEXT NOT NULL DEFAULT '[]',
            notable_features TEXT NOT NULL DEFAULT '[]',
            visibility_mean REAL,
            temp_mean REAL,
            seasonality_json TEXT DEFAULT '{}',
            shop_count INTEGER NOT NULL DEFAULT 0,
            image_asset_ids TEXT NOT NULL DEFAULT '[]',
            has_current INTEGER NOT NULL DEFAULT 0,
            min_depth REAL,
            max_depth REAL,
            is_beginner INTEGER NOT NULL DEFAULT 0,
            is_advanced INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("CREATE INDEX idx_site_facets_difficulty ON site_facets(difficulty)")
    cursor.execute("CREATE INDEX idx_site_facets_has_current ON site_facets(has_current)")

    # v4: Site media
    cursor.execute("""
        CREATE TABLE site_media (
            id TEXT PRIMARY KEY,
            site_id TEXT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
            kind TEXT NOT NULL,
            url TEXT NOT NULL,
            width INTEGER,
            height INTEGER,
            license TEXT,
            attribution TEXT,
            source_url TEXT,
            sha256 TEXT,
            is_redistributable INTEGER NOT NULL DEFAULT 1
        )
    """)
    cursor.execute("CREATE INDEX idx_site_media_site ON site_media(site_id)")

    # v4: Dive shops
    cursor.execute("""
        CREATE TABLE dive_shops (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            country TEXT,
            region TEXT,
            area TEXT,
            latitude REAL,
            longitude REAL,
            website TEXT,
            phone TEXT,
            email TEXT,
            services TEXT NOT NULL DEFAULT '[]',
            license TEXT,
            source_url TEXT
        )
    """)

    # v4: Site-shop associations
    cursor.execute("""
        CREATE TABLE site_shops (
            site_id TEXT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
            shop_id TEXT NOT NULL REFERENCES dive_shops(id) ON DELETE CASCADE,
            distance_km REAL,
            PRIMARY KEY (site_id, shop_id) ON CONFLICT REPLACE
        )
    """)

    # v4: Materialized filter counts
    cursor.execute("""
        CREATE TABLE site_filters_materialized (
            region TEXT,
            area TEXT,
            facet TEXT NOT NULL,
            value TEXT NOT NULL,
            count INTEGER NOT NULL,
            PRIMARY KEY (region, area, facet, value) ON CONFLICT REPLACE
        )
    """)

    # v5: Countries table
    cursor.execute("""
        CREATE TABLE countries (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            name_local TEXT,
            continent TEXT NOT NULL,
            wikidata_id TEXT
        )
    """)
    cursor.execute("CREATE INDEX idx_countries_continent ON countries(continent)")

    # v5: Regions table (with v8 additions)
    cursor.execute("""
        CREATE TABLE regions (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            country_id TEXT REFERENCES countries(id) ON DELETE SET NULL,
            latitude REAL,
            longitude REAL,
            wikidata_id TEXT,
            tagline TEXT,
            description TEXT
        )
    """)
    cursor.execute("CREATE INDEX idx_regions_country ON regions(country_id)")

    # v5: Areas table
    cursor.execute("""
        CREATE TABLE areas (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            region_id TEXT REFERENCES regions(id) ON DELETE SET NULL,
            country_id TEXT REFERENCES countries(id) ON DELETE SET NULL,
            latitude REAL,
            longitude REAL,
            wikidata_id TEXT
        )
    """)
    cursor.execute("CREATE INDEX idx_areas_region ON areas(region_id)")
    cursor.execute("CREATE INDEX idx_areas_country ON areas(country_id)")

    # v5: Species families
    cursor.execute("""
        CREATE TABLE species_families (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            scientific_name TEXT NOT NULL,
            category TEXT NOT NULL,
            worms_aphia_id INTEGER,
            gbif_key INTEGER
        )
    """)
    cursor.execute("CREATE INDEX idx_families_category ON species_families(category)")

    # v5: Site-species junction table
    cursor.execute("""
        CREATE TABLE site_species (
            site_id TEXT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
            species_id TEXT NOT NULL REFERENCES wildlife_species(id) ON DELETE CASCADE,
            likelihood TEXT NOT NULL DEFAULT 'occasional',
            season_months TEXT,
            depth_min_m INTEGER,
            depth_max_m INTEGER,
            source TEXT,
            source_record_count INTEGER,
            last_updated TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (site_id, species_id) ON CONFLICT REPLACE
        )
    """)
    cursor.execute("CREATE INDEX idx_site_species_site ON site_species(site_id)")
    cursor.execute("CREATE INDEX idx_site_species_species ON site_species(species_id)")
    cursor.execute("CREATE INDEX idx_site_species_likelihood ON site_species(likelihood)")

    # v7: Sync metadata
    cursor.execute("""
        CREATE TABLE sync_metadata (
            id TEXT PRIMARY KEY,
            record_type TEXT NOT NULL,
            local_record_id TEXT NOT NULL,
            ck_record_id TEXT,
            ck_system_fields BLOB,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            last_synced_at TEXT,
            local_updated_at TEXT NOT NULL,
            error_message TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0
        )
    """)
    cursor.execute("CREATE UNIQUE INDEX idx_sync_metadata_record ON sync_metadata(record_type, local_record_id)")
    cursor.execute("CREATE INDEX idx_sync_metadata_status ON sync_metadata(sync_status)")

    # v7: Sync queue
    cursor.execute("""
        CREATE TABLE sync_queue (
            id TEXT PRIMARY KEY,
            operation TEXT NOT NULL,
            record_type TEXT NOT NULL,
            local_record_id TEXT NOT NULL,
            payload BLOB,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_attempt_at TEXT,
            error_message TEXT,
            priority INTEGER NOT NULL DEFAULT 0
        )
    """)
    cursor.execute("CREATE INDEX idx_sync_queue_priority ON sync_queue(priority)")
    cursor.execute("CREATE INDEX idx_sync_queue_record ON sync_queue(record_type, local_record_id)")

    # v7: User site states
    cursor.execute("""
        CREATE TABLE user_site_states (
            site_id TEXT PRIMARY KEY REFERENCES sites(id) ON DELETE CASCADE,
            is_wishlist INTEGER NOT NULL DEFAULT 0,
            is_planned INTEGER NOT NULL DEFAULT 0,
            user_notes TEXT,
            user_rating INTEGER,
            last_visited_at TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("CREATE INDEX idx_user_site_states_wishlist ON user_site_states(is_wishlist)")
    cursor.execute("CREATE INDEX idx_user_site_states_planned ON user_site_states(is_planned)")

    # v7: Trips table
    cursor.execute("""
        CREATE TABLE trips (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            start_date TEXT,
            end_date TEXT,
            notes TEXT,
            cover_image_url TEXT,
            calendar_event_id TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("CREATE INDEX idx_trips_dates ON trips(start_date, end_date)")

    # v7: Trip sites junction
    cursor.execute("""
        CREATE TABLE trip_sites (
            trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
            site_id TEXT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
            sort_order INTEGER NOT NULL DEFAULT 0,
            planned_date TEXT,
            notes TEXT,
            PRIMARY KEY (trip_id, site_id) ON CONFLICT REPLACE
        )
    """)
    cursor.execute("CREATE INDEX idx_trip_sites_trip ON trip_sites(trip_id)")
    cursor.execute("CREATE INDEX idx_trip_sites_site ON trip_sites(site_id)")

    # FTS5 tables (content-less for manual population)
    cursor.execute("""
        CREATE VIRTUAL TABLE sites_fts USING fts5(
            name, region, location, tags, description,
            content='', contentless_delete=1
        )
    """)

    cursor.execute("""
        CREATE VIRTUAL TABLE species_fts USING fts5(
            name, scientific_name,
            content='', contentless_delete=1
        )
    """)

    # v9: FTS5 incremental triggers for sites
    cursor.execute("""
        CREATE TRIGGER sites_fts_insert AFTER INSERT ON sites BEGIN
            INSERT INTO sites_fts(rowid, name, region, location, tags, description)
            VALUES (NEW.rowid, NEW.name, NEW.region, NEW.location, NEW.tags, NEW.description);
        END
    """)
    cursor.execute("""
        CREATE TRIGGER sites_fts_update AFTER UPDATE ON sites BEGIN
            DELETE FROM sites_fts WHERE rowid = OLD.rowid;
            INSERT INTO sites_fts(rowid, name, region, location, tags, description)
            VALUES (NEW.rowid, NEW.name, NEW.region, NEW.location, NEW.tags, NEW.description);
        END
    """)
    cursor.execute("""
        CREATE TRIGGER sites_fts_delete AFTER DELETE ON sites BEGIN
            DELETE FROM sites_fts WHERE rowid = OLD.rowid;
        END
    """)

    # v9: FTS5 incremental triggers for species
    cursor.execute("""
        CREATE TRIGGER species_fts_insert AFTER INSERT ON wildlife_species BEGIN
            INSERT INTO species_fts(rowid, name, scientific_name)
            VALUES (NEW.rowid, NEW.name, NEW.scientificName);
        END
    """)
    cursor.execute("""
        CREATE TRIGGER species_fts_update AFTER UPDATE ON wildlife_species BEGIN
            DELETE FROM species_fts WHERE rowid = OLD.rowid;
            INSERT INTO species_fts(rowid, name, scientific_name)
            VALUES (NEW.rowid, NEW.name, NEW.scientificName);
        END
    """)
    cursor.execute("""
        CREATE TRIGGER species_fts_delete AFTER DELETE ON wildlife_species BEGIN
            DELETE FROM species_fts WHERE rowid = OLD.rowid;
        END
    """)

    # Record all migrations as applied so GRDB doesn't try to re-run them
    migrations = [
        "v1_initial_schema",
        "v3_tags_search_indexes",
        "v4_facets_media_shops_filters",
        "v5_geography_species_taxonomy",
        "v6_gps_draft_planned_sites",
        "v7_sync_trips_user_states",
        "v8_region_descriptions",
        "v9_fts5_incremental_triggers"
    ]
    cursor.executemany(
        "INSERT INTO grdb_migrations (identifier) VALUES (?)",
        [(m,) for m in migrations]
    )

    conn.commit()
    log("Schema created with all migrations v1-v9")


def seed_countries(conn: sqlite3.Connection):
    """Seed countries table."""
    data = load_json("countries")
    if not data:
        return

    countries = data.get("countries", [])
    cursor = conn.cursor()

    cursor.executemany(
        "INSERT INTO countries (id, name, name_local, continent, wikidata_id) VALUES (?, ?, ?, ?, ?)",
        [(c["id"], c["name"], c.get("name_local"), c["continent"], c.get("wikidata_id")) for c in countries]
    )
    conn.commit()
    log(f"  Inserted {len(countries)} countries")


def seed_regions(conn: sqlite3.Connection):
    """Seed regions table with enrichment data."""
    data = load_json("regions")
    enriched_data = load_json("regions_enriched")

    if not data:
        return

    regions = data.get("regions", [])
    enrichments = {}
    if enriched_data:
        for r in enriched_data.get("regions", []):
            enrichments[r["id"]] = r

    cursor = conn.cursor()
    rows = []
    for r in regions:
        enrich = enrichments.get(r["id"], {})
        rows.append((
            r["id"],
            r["name"],
            r.get("country_id"),
            r.get("latitude"),
            r.get("longitude"),
            r.get("wikidata_id"),
            enrich.get("tagline"),
            enrich.get("description")
        ))

    cursor.executemany(
        "INSERT INTO regions (id, name, country_id, latitude, longitude, wikidata_id, tagline, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        rows
    )
    conn.commit()
    log(f"  Inserted {len(regions)} regions")


def seed_areas(conn: sqlite3.Connection):
    """Seed areas table."""
    data = load_json("areas")
    if not data:
        return

    areas = data.get("areas", [])
    cursor = conn.cursor()

    cursor.executemany(
        "INSERT INTO areas (id, name, region_id, country_id, latitude, longitude, wikidata_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(a["id"], a["name"], a.get("region_id"), a.get("country_id"), a.get("latitude"), a.get("longitude"), a.get("wikidata_id")) for a in areas]
    )
    conn.commit()
    log(f"  Inserted {len(areas)} areas")


def seed_species_families(conn: sqlite3.Connection):
    """Seed species families table."""
    data = load_json("families_catalog")
    if not data:
        return

    families = data.get("families", [])
    cursor = conn.cursor()

    rows = []
    for f in families:
        # Use name as fallback for scientific_name
        scientific_name = f.get("scientific_name") or f["name"]
        rows.append((
            f["id"],
            f["name"],
            scientific_name,
            f["category"],
            f.get("worms_aphia_id"),
            f.get("gbif_key")
        ))

    cursor.executemany(
        "INSERT INTO species_families (id, name, scientific_name, category, worms_aphia_id, gbif_key) VALUES (?, ?, ?, ?, ?, ?)",
        rows
    )
    conn.commit()
    log(f"  Inserted {len(families)} species families")


def seed_sites(conn: sqlite3.Connection):
    """Seed sites from enriched file."""
    data = load_json("sites_enriched")
    if not data:
        log("  Warning: sites_enriched.json not found, trying fallback")
        return

    sites = data.get("sites", [])
    cursor = conn.cursor()
    now = datetime.now().isoformat()

    rows = []
    for s in sites:
        # Build location from area and country
        area = (s.get("area") or "").strip()
        country = (s.get("country") or "").strip()
        parts = [p for p in [area, country] if p]
        location = ", ".join(parts) if parts else s.get("region", "")

        rows.append((
            s["id"],
            s["name"],
            location,
            s["latitude"],
            s["longitude"],
            s["region"],
            s.get("averageDepth", 0),
            s.get("maxDepth", 0),
            s.get("averageTemp", 0),
            s.get("averageVisibility", 0),
            s.get("difficulty", "Intermediate"),
            s.get("type", "Reef"),
            s.get("description"),
            s.get("wishlist", False),
            s.get("visitedCount", 0),
            now,
            "[]",  # tags
            None,  # country_id
            None,  # region_id
            None,  # area_id
            None,  # wikidata_id
            None,  # osm_id
            s.get("isPlanned", False)
        ))

    cursor.executemany(
        """INSERT INTO sites (id, name, location, latitude, longitude, region,
           averageDepth, maxDepth, averageTemp, averageVisibility, difficulty, type,
           description, wishlist, visitedCount, createdAt, tags, country_id, region_id,
           area_id, wikidata_id, osm_id, isPlanned) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        rows
    )
    conn.commit()
    log(f"  Inserted {len(sites)} sites")


def load_species_descriptions() -> dict:
    """Load species descriptions from enhanced file."""
    data = load_json("species_descriptions_enhanced")
    if not data:
        return {}

    descriptions = {}
    for species_id, entry in data.get("species", {}).items():
        visual = entry.get("visual_description", {})
        if not visual:
            continue

        parts = []
        if body := visual.get("body_shape"):
            parts.append(body.rstrip(".") + ".")

        colors = visual.get("colors", {})
        if primary := colors.get("primary"):
            color_line = primary
            if accents := colors.get("accents"):
                # Handle accents as string or list
                if isinstance(accents, list):
                    accents = ", ".join(accents)
                color_line += " " + str(accents)
            parts.append(color_line.rstrip(".") + ".")

        if patterns := visual.get("patterns"):
            if patterns:
                parts.append(patterns[0].rstrip(".") + ".")

        if features := visual.get("distinctive_features"):
            if features:
                feat_list = "; ".join(features[:2])
                parts.append(f"Distinctive features include {feat_list}.")

        if size := visual.get("size_cm"):
            parts.append(f"Typically reaches around {size} cm.")

        if parts:
            descriptions[species_id] = " ".join(parts)

    return descriptions


def load_species_images() -> dict:
    """Load species image URLs from iNaturalist and Wikimedia files."""
    images = {}

    # Try iNaturalist first (higher quality)
    inat_data = load_json("species_images_inaturalist")
    if inat_data:
        for species_id, entry in inat_data.get("species", {}).items():
            photos = entry.get("photos", [])
            if photos and photos[0].get("url"):
                images[species_id] = photos[0]["url"]

    # Fallback to Wikimedia
    wiki_data = load_json("species_images_wikimedia")
    if wiki_data:
        for species_id, entry in wiki_data.get("species", {}).items():
            if species_id in images:
                continue
            photos = entry.get("photos", [])
            if photos and photos[0].get("url"):
                images[species_id] = photos[0]["url"]

    return images


def seed_species(conn: sqlite3.Connection) -> int:
    """Seed wildlife species table. Returns count for rarity calculation."""
    # Try full catalog first
    data = load_json("species_catalog_full")
    if not data:
        data = load_json("species_catalog_v2")
    if not data:
        data = load_json("species_catalog")
    if not data:
        return 0

    species_list = data.get("species", [])
    descriptions = load_species_descriptions()
    images = load_species_images()

    cursor = conn.cursor()
    seen_ids = set()
    rows = []

    for s in species_list:
        if s["id"] in seen_ids:
            continue
        seen_ids.add(s["id"])

        # Get description
        desc = descriptions.get(s["id"]) or s.get("description")

        # Get image URLs
        img_url = images.get(s["id"]) or s.get("imageUrl")
        thumb_url = s.get("thumbnail_url") or img_url

        # Infer category if missing
        category = s.get("category", "").strip()
        if not category:
            name_lower = s["name"].lower()
            if any(k in name_lower for k in ["whale", "dolphin", "seal", "manatee"]):
                category = "Mammal"
            elif any(k in name_lower for k in ["turtle", "sea snake", "crocodile"]):
                category = "Reptile"
            elif any(k in name_lower for k in ["coral", "anemone", "sea fan"]):
                category = "Coral"
            elif any(k in name_lower for k in ["octopus", "squid", "jellyfish", "crab", "lobster", "shrimp", "nudibranch", "starfish", "urchin", "sponge"]):
                category = "Invertebrate"
            else:
                category = "Fish"

        # Default rarity to Common (will be recalculated later)
        rarity = s.get("rarity", "Common")
        if not rarity or rarity.strip() == "":
            rarity = "Common"

        regions = s.get("regions", [])
        regions_str = ",".join(regions) if isinstance(regions, list) else str(regions)

        rows.append((
            s["id"],
            s["name"],
            s.get("scientificName", s["name"]),
            category,
            rarity,
            regions_str,
            img_url,
            s.get("family_id"),
            s.get("conservation_status"),
            desc,
            thumb_url,
            s.get("worms_aphia_id"),
            s.get("gbif_key"),
            s.get("fishbase_id")
        ))

    cursor.executemany(
        """INSERT INTO wildlife_species (id, name, scientificName, category, rarity, regions,
           imageUrl, family_id, conservation_status, description, thumbnail_url,
           worms_aphia_id, gbif_key, fishbase_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        rows
    )
    conn.commit()
    log(f"  Inserted {len(rows)} species")
    return len(rows)


def seed_site_species_links(conn: sqlite3.Connection) -> dict:
    """Seed site-species links. Returns species->site count for rarity calculation."""
    # First try loading from species catalog (has embedded sites)
    catalog = load_json("species_catalog_full")
    if not catalog:
        catalog = load_json("species_catalog_v2")

    cursor = conn.cursor()

    # Get valid IDs
    cursor.execute("SELECT id FROM wildlife_species")
    valid_species = {row[0] for row in cursor.fetchall()}

    cursor.execute("SELECT id FROM sites")
    valid_sites = {row[0] for row in cursor.fetchall()}

    species_site_counts = {}  # species_id -> number of sites
    rows = []
    seen = set()
    now = datetime.now().isoformat()

    # Try embedded sites in catalog
    if catalog:
        for species in catalog.get("species", []):
            species_id = species["id"]
            if species_id not in valid_species:
                continue

            sites = species.get("sites", [])
            for site in sites:
                site_id = site.get("id", "").strip()
                if not site_id or site_id not in valid_sites:
                    continue

                key = f"{site_id}|{species_id}"
                if key in seen:
                    continue
                seen.add(key)

                likelihood = site.get("likelihood", "occasional")
                if likelihood not in ("common", "occasional", "rare"):
                    likelihood = "occasional"

                rows.append((
                    site_id,
                    species_id,
                    likelihood,
                    None,  # season_months
                    None,  # depth_min_m
                    None,  # depth_max_m
                    "catalog_full",
                    None,  # source_record_count
                    now
                ))

                species_site_counts[species_id] = species_site_counts.get(species_id, 0) + 1

    # Fallback to site_species.json if no embedded sites
    if not rows:
        data = load_json("site_species")
        if data:
            for link in data.get("site_species", []):
                site_id = link.get("site_id", "").strip()
                species_id = link.get("species_id", "").strip()

                if not site_id or not species_id:
                    continue
                if site_id not in valid_sites or species_id not in valid_species:
                    continue

                key = f"{site_id}|{species_id}"
                if key in seen:
                    continue
                seen.add(key)

                likelihood = link.get("likelihood", "occasional")
                if likelihood not in ("common", "occasional", "rare"):
                    likelihood = "occasional"

                rows.append((
                    site_id,
                    species_id,
                    likelihood,
                    json.dumps(link.get("season_months")) if link.get("season_months") else None,
                    link.get("depth_min_m"),
                    link.get("depth_max_m"),
                    link.get("source"),
                    link.get("source_record_count"),
                    link.get("last_updated", now)
                ))

                species_site_counts[species_id] = species_site_counts.get(species_id, 0) + 1

    if rows:
        cursor.executemany(
            """INSERT INTO site_species (site_id, species_id, likelihood, season_months,
               depth_min_m, depth_max_m, source, source_record_count, last_updated)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            rows
        )
        conn.commit()

    log(f"  Inserted {len(rows)} site-species links")
    return species_site_counts


def calculate_realistic_rarity(conn: sqlite3.Connection, species_site_counts: dict):
    """
    Calculate realistic rarity based on relative distribution among species.

    Uses percentile-based thresholds:
    - Common: top 20% of species by site count
    - Uncommon: next 30% (20-50 percentile)
    - Rare: next 30% (50-80 percentile)
    - Very Rare: bottom 20% or species with no links
    """
    cursor = conn.cursor()

    if not species_site_counts:
        log("  No site-species links found, skipping rarity calculation")
        return

    # Sort species by site count (descending)
    sorted_species = sorted(
        species_site_counts.items(),
        key=lambda x: x[1],
        reverse=True
    )

    total_species = len(sorted_species)
    if total_species == 0:
        return

    # Calculate percentile thresholds
    common_cutoff = int(total_species * 0.20)  # Top 20%
    uncommon_cutoff = int(total_species * 0.50)  # Top 50%
    rare_cutoff = int(total_species * 0.80)  # Top 80%

    updates = []
    for i, (species_id, site_count) in enumerate(sorted_species):
        if i < common_cutoff:
            rarity = "Common"
        elif i < uncommon_cutoff:
            rarity = "Uncommon"
        elif i < rare_cutoff:
            rarity = "Rare"
        else:
            rarity = "Very Rare"

        updates.append((rarity, species_id))

    # Species with no links are Very Rare
    cursor.execute("SELECT id FROM wildlife_species WHERE id NOT IN (SELECT DISTINCT species_id FROM site_species)")
    no_links = cursor.fetchall()
    for (species_id,) in no_links:
        updates.append(("Very Rare", species_id))

    cursor.executemany(
        "UPDATE wildlife_species SET rarity = ? WHERE id = ?",
        updates
    )
    conn.commit()

    # Log distribution with actual site count ranges
    cursor.execute("SELECT rarity, COUNT(*) FROM wildlife_species GROUP BY rarity ORDER BY rarity")
    distribution = cursor.fetchall()
    log(f"  Updated rarity for {len(updates)} species:")
    for rarity, count in distribution:
        log(f"    {rarity}: {count}")

    # Log site count ranges for context
    if sorted_species:
        common_min = sorted_species[common_cutoff - 1][1] if common_cutoff > 0 else 0
        uncommon_min = sorted_species[uncommon_cutoff - 1][1] if uncommon_cutoff > 0 else 0
        rare_min = sorted_species[rare_cutoff - 1][1] if rare_cutoff > 0 else 0
        log(f"  Site count thresholds: Common >= {common_min}, Uncommon >= {uncommon_min}, Rare >= {rare_min}")


def seed_site_media(conn: sqlite3.Connection):
    """Seed site media table."""
    data = load_json("site_media")
    if not data:
        return

    media = data.get("media", [])
    cursor = conn.cursor()

    # Get valid site IDs
    cursor.execute("SELECT id FROM sites")
    valid_sites = {row[0] for row in cursor.fetchall()}

    rows = []
    for m in media:
        if m.get("siteId") not in valid_sites:
            continue
        rows.append((
            m["id"],
            m["siteId"],
            m.get("kind", "photo"),
            m["url"],
            m.get("width"),
            m.get("height"),
            m.get("license"),
            m.get("attribution"),
            m.get("sourceUrl"),
            m.get("sha256"),
            m.get("isRedistributable", True)
        ))

    if rows:
        cursor.executemany(
            """INSERT INTO site_media (id, site_id, kind, url, width, height, license,
               attribution, source_url, sha256, is_redistributable)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            rows
        )
        conn.commit()
    log(f"  Inserted {len(rows)} site media records")


def build_fts_indexes(conn: sqlite3.Connection):
    """Manually populate FTS5 indexes (triggers will handle future updates)."""
    cursor = conn.cursor()

    # FTS for sites is already populated by trigger on insert
    # But let's verify and rebuild if needed
    cursor.execute("SELECT COUNT(*) FROM sites_fts")
    sites_fts_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM sites")
    sites_count = cursor.fetchone()[0]

    if sites_fts_count != sites_count:
        log(f"  Rebuilding sites FTS ({sites_fts_count} vs {sites_count} rows)")
        cursor.execute("DELETE FROM sites_fts")
        cursor.execute("""
            INSERT INTO sites_fts(rowid, name, region, location, tags, description)
            SELECT rowid, name, region, location, tags, description FROM sites
        """)

    # FTS for species
    cursor.execute("SELECT COUNT(*) FROM species_fts")
    species_fts_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM wildlife_species")
    species_count = cursor.fetchone()[0]

    if species_fts_count != species_count:
        log(f"  Rebuilding species FTS ({species_fts_count} vs {species_count} rows)")
        cursor.execute("DELETE FROM species_fts")
        cursor.execute("""
            INSERT INTO species_fts(rowid, name, scientific_name)
            SELECT rowid, name, scientificName FROM wildlife_species
        """)

    conn.commit()
    log(f"  FTS indexes ready: {sites_count} sites, {species_count} species")


def vacuum_database(conn: sqlite3.Connection, db_path: Path):
    """Compact database and report size."""
    conn.execute("VACUUM")
    conn.execute("ANALYZE")
    conn.commit()

    size_mb = db_path.stat().st_size / (1024 * 1024)
    log(f"  Database compacted: {size_mb:.2f} MB")


def main():
    output_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT

    log(f"Generating seed database: {output_path}")

    # Ensure output directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Remove existing database
    if output_path.exists():
        output_path.unlink()
        log(f"  Removed existing database")

    # Connect and create
    conn = sqlite3.connect(str(output_path))
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")

    try:
        # Create schema
        create_schema(conn)

        # Seed data in dependency order
        log("Seeding geographic hierarchy...")
        seed_countries(conn)
        seed_regions(conn)
        seed_areas(conn)

        log("Seeding species families...")
        seed_species_families(conn)

        log("Seeding sites...")
        seed_sites(conn)

        log("Seeding species...")
        species_count = seed_species(conn)

        log("Seeding site-species links...")
        species_site_counts = seed_site_species_links(conn)

        log("Calculating realistic rarity distribution...")
        calculate_realistic_rarity(conn, species_site_counts)

        log("Seeding site media...")
        seed_site_media(conn)

        log("Building FTS indexes...")
        build_fts_indexes(conn)

        log("Optimizing database...")
        vacuum_database(conn, output_path)

        # Final stats
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM sites")
        sites = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM wildlife_species")
        species = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM site_species")
        links = cursor.fetchone()[0]

        log(f"\nSeed database ready!")
        log(f"  Sites: {sites}")
        log(f"  Species: {species}")
        log(f"  Site-species links: {links}")
        log(f"  Output: {output_path}")

    finally:
        conn.close()


if __name__ == "__main__":
    main()
