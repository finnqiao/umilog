import Foundation
import GRDB

public enum DatabaseMigrator {
    public static func migrate(_ writer: DatabaseWriter) throws {
        var migrator = GRDB.DatabaseMigrator()
        
        // MARK: - v1: Initial Schema
        migrator.registerMigration("v1_initial_schema") { db in
            // Dive sites table
            try db.create(table: "sites") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("location", .text).notNull()
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("region", .text).notNull()
                t.column("averageDepth", .double).notNull()
                t.column("maxDepth", .double).notNull()
                t.column("averageTemp", .double).notNull()
                t.column("averageVisibility", .double).notNull()
                t.column("difficulty", .text).notNull()
                t.column("type", .text).notNull()
                t.column("description", .text)
                t.column("wishlist", .boolean).notNull().defaults(to: false)
                t.column("visitedCount", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
            }
            
            // Indexes for sites
            try db.create(index: "idx_sites_location", on: "sites", columns: ["latitude", "longitude"])
            try db.create(index: "idx_sites_region", on: "sites", columns: ["region"])
            try db.create(index: "idx_sites_wishlist", on: "sites", columns: ["wishlist"])
            
            // Full-text search for sites
            try db.create(virtualTable: "sites_fts", using: FTS5()) { t in
                t.synchronize(withTable: "sites")
                t.column("name")
                t.column("location")
                t.column("description")
            }
            
            // Dives table
            try db.create(table: "dives") { t in
                t.column("id", .text).primaryKey()
                t.column("siteId", .text).notNull()
                    .references("sites", onDelete: .restrict)
                t.column("date", .datetime).notNull()
                t.column("startTime", .datetime).notNull()
                t.column("endTime", .datetime)
                t.column("maxDepth", .double).notNull()
                t.column("averageDepth", .double)
                t.column("bottomTime", .integer).notNull()
                t.column("startPressure", .integer).notNull()
                t.column("endPressure", .integer).notNull()
                t.column("temperature", .double).notNull()
                t.column("visibility", .double).notNull()
                t.column("current", .text).notNull()
                t.column("conditions", .text).notNull()
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("instructorName", .text)
                t.column("instructorNumber", .text)
                t.column("signed", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            
            // Indexes for dives
            try db.create(index: "idx_dives_start_time", on: "dives", columns: ["startTime"])
            try db.create(index: "idx_dives_site", on: "dives", columns: ["siteId"])
            try db.create(index: "idx_dives_date", on: "dives", columns: ["date"])
            
            // Wildlife species table
            try db.create(table: "wildlife_species") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("scientificName", .text).notNull()
                t.column("category", .text).notNull()
                t.column("rarity", .text).notNull()
                t.column("regions", .text).notNull() // Comma-separated
                t.column("imageUrl", .text)
            }
            
            // Indexes for wildlife species
            try db.create(index: "idx_species_category", on: "wildlife_species", columns: ["category"])
            try db.create(index: "idx_species_rarity", on: "wildlife_species", columns: ["rarity"])
            
            // Wildlife sightings table
            try db.create(table: "sightings") { t in
                t.column("id", .text).primaryKey()
                t.column("diveId", .text).notNull()
                    .references("dives", onDelete: .cascade)
                t.column("speciesId", .text).notNull()
                    .references("wildlife_species", onDelete: .restrict)
                t.column("count", .integer).notNull().defaults(to: 1)
                t.column("notes", .text)
                t.column("createdAt", .datetime).notNull()
            }
            
            // Indexes for sightings
            try db.create(index: "idx_sightings_dive", on: "sightings", columns: ["diveId"])
            try db.create(index: "idx_sightings_species", on: "sightings", columns: ["speciesId"])
        }
        
        // MARK: - v3: Tags, Search, Indexes
        migrator.registerMigration("v3_tags_search_indexes") { db in
            // Add tags column to sites
            try db.alter(table: "sites") { t in
                t.add(column: "tags", .text).notNull().defaults(to: "[]")
            }
            
            // Site tags normalization table for fast tag filtering
            try db.create(table: "site_tags") { t in
                t.column("site_id", .text).notNull()
                    .references("sites", onDelete: .cascade)
                t.column("tag", .text).notNull()
                t.primaryKey(["site_id", "tag"], onConflict: .replace)
            }
            try db.create(index: "idx_site_tags_tag", on: "site_tags", columns: ["tag"])
            
            // Add core indexes for filtering
            try db.create(index: "idx_sites_difficulty", on: "sites", columns: ["difficulty"])
            try db.create(index: "idx_sites_type", on: "sites", columns: ["type"])
            try db.create(index: "idx_sites_lat_lon", on: "sites", columns: ["latitude", "longitude"])
            
            // Rebuild FTS to include tags and more fields
            try db.execute(sql: "DROP TABLE IF EXISTS sites_fts")
            try db.create(virtualTable: "sites_fts", using: FTS5()) { t in
                t.column("name")
                t.column("region")
                t.column("location")
                t.column("tags")
                t.column("description")
                // Note: content table synchronization would require triggers
                // For now, manual FTS rebuild in seeder via INSERT INTO sites_fts(sites_fts) VALUES('rebuild')
            }
        }
        
        // MARK: - v4: Facets, Media, Shops, Materialized Filters
        migrator.registerMigration("v4_facets_media_shops_filters") { db in
            // Site facets (precomputed attributes)
            try db.create(table: "site_facets") { t in
                t.column("site_id", .text).primaryKey()
                    .references("sites", onDelete: .cascade)
                t.column("difficulty", .text).notNull()
                t.column("entry_modes", .text).notNull().defaults(to: "[]")
                t.column("notable_features", .text).notNull().defaults(to: "[]")
                t.column("visibility_mean", .double)
                t.column("temp_mean", .double)
                t.column("seasonality_json", .text).defaults(to: "{}")
                t.column("shop_count", .integer).notNull().defaults(to: 0)
                t.column("image_asset_ids", .text).notNull().defaults(to: "[]")
                t.column("has_current", .integer).notNull().defaults(to: 0)
                t.column("min_depth", .double)
                t.column("max_depth", .double)
                t.column("is_beginner", .integer).notNull().defaults(to: 0)
                t.column("is_advanced", .integer).notNull().defaults(to: 0)
                t.column("updated_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(index: "idx_site_facets_difficulty", on: "site_facets", columns: ["difficulty"])
            try db.create(index: "idx_site_facets_has_current", on: "site_facets", columns: ["has_current"])
            
            // Site media (licensed photos/videos)
            try db.create(table: "site_media") { t in
                t.column("id", .text).primaryKey()
                t.column("site_id", .text).notNull()
                    .references("sites", onDelete: .cascade)
                t.column("kind", .text).notNull()  // "photo" or "video"
                t.column("url", .text).notNull()
                t.column("width", .integer)
                t.column("height", .integer)
                t.column("license", .text)  // e.g., "CC-BY-4.0"
                t.column("attribution", .text)
                t.column("source_url", .text)
                t.column("sha256", .text)
                t.column("is_redistributable", .integer).notNull().defaults(to: 1)
            }
            try db.create(index: "idx_site_media_site", on: "site_media", columns: ["site_id"])
            
            // Dive shops/centers
            try db.create(table: "dive_shops") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("country", .text)
                t.column("region", .text)
                t.column("area", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("website", .text)
                t.column("phone", .text)
                t.column("email", .text)
                t.column("services", .text).notNull().defaults(to: "[]")
                t.column("license", .text)
                t.column("source_url", .text)
            }
            
            // Site-shop associations
            try db.create(table: "site_shops") { t in
                t.column("site_id", .text).notNull()
                    .references("sites", onDelete: .cascade)
                t.column("shop_id", .text).notNull()
                    .references("dive_shops", onDelete: .cascade)
                t.column("distance_km", .double)
                t.primaryKey(["site_id", "shop_id"], onConflict: .replace)
            }
            
            // Materialized filter counts (precomputed for instant chips)
            try db.create(table: "site_filters_materialized") { t in
                t.column("region", .text)
                t.column("area", .text)
                t.column("facet", .text).notNull()  // "tag", "difficulty", "feature", "entry"
                t.column("value", .text).notNull()  // e.g., "wreck", "beginner"
                t.column("count", .integer).notNull()
                t.primaryKey(["region", "area", "facet", "value"], onConflict: .replace)
            }
        }
        
        // MARK: - v5: Geographic Hierarchy, Species Taxonomy, Species-Site Linkage
        migrator.registerMigration("v5_geography_species_taxonomy") { db in
            // Countries table (ISO 3166-1 alpha-2 codes)
            try db.create(table: "countries") { t in
                t.column("id", .text).primaryKey()  // ISO code: "EG", "TH", "JP"
                t.column("name", .text).notNull()
                t.column("name_local", .text)
                t.column("continent", .text).notNull()
                t.column("wikidata_id", .text)
            }
            try db.create(index: "idx_countries_continent", on: "countries", columns: ["continent"])

            // Regions table (diving regions, normalized)
            try db.create(table: "regions") { t in
                t.column("id", .text).primaryKey()  // e.g., "red-sea", "coral-triangle"
                t.column("name", .text).notNull()
                t.column("country_id", .text).references("countries", onDelete: .setNull)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("wikidata_id", .text)
            }
            try db.create(index: "idx_regions_country", on: "regions", columns: ["country_id"])

            // Areas table (sub-regions, e.g., Dahab, Koh Tao)
            try db.create(table: "areas") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("region_id", .text).references("regions", onDelete: .setNull)
                t.column("country_id", .text).references("countries", onDelete: .setNull)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("wikidata_id", .text)
            }
            try db.create(index: "idx_areas_region", on: "areas", columns: ["region_id"])
            try db.create(index: "idx_areas_country", on: "areas", columns: ["country_id"])

            // Add geographic foreign keys to sites
            try db.alter(table: "sites") { t in
                t.add(column: "country_id", .text).references("countries", onDelete: .setNull)
                t.add(column: "region_id", .text).references("regions", onDelete: .setNull)
                t.add(column: "area_id", .text).references("areas", onDelete: .setNull)
                t.add(column: "wikidata_id", .text)
                t.add(column: "osm_id", .text)
            }
            try db.create(index: "idx_sites_country", on: "sites", columns: ["country_id"])
            try db.create(index: "idx_sites_region_id", on: "sites", columns: ["region_id"])
            try db.create(index: "idx_sites_area_id", on: "sites", columns: ["area_id"])

            // Species families table (simplified taxonomy)
            try db.create(table: "species_families") { t in
                t.column("id", .text).primaryKey()  // e.g., "carcharhinidae"
                t.column("name", .text).notNull()   // "Requiem Sharks"
                t.column("scientific_name", .text).notNull()
                t.column("category", .text).notNull()  // "Fish", "Coral", etc.
                t.column("worms_aphia_id", .integer)
                t.column("gbif_key", .integer)
            }
            try db.create(index: "idx_families_category", on: "species_families", columns: ["category"])

            // Add taxonomy fields to wildlife_species
            try db.alter(table: "wildlife_species") { t in
                t.add(column: "family_id", .text).references("species_families", onDelete: .setNull)
                t.add(column: "conservation_status", .text)  // IUCN: LC, VU, EN, CR
                t.add(column: "description", .text)
                t.add(column: "thumbnail_url", .text)
                t.add(column: "worms_aphia_id", .integer)
                t.add(column: "gbif_key", .integer)
                t.add(column: "fishbase_id", .integer)
            }
            try db.create(index: "idx_species_family", on: "wildlife_species", columns: ["family_id"])
            try db.create(index: "idx_species_scientific", on: "wildlife_species", columns: ["scientificName"])

            // Site-species junction table (many-to-many with likelihood)
            try db.create(table: "site_species") { t in
                t.column("site_id", .text).notNull()
                    .references("sites", onDelete: .cascade)
                t.column("species_id", .text).notNull()
                    .references("wildlife_species", onDelete: .cascade)
                t.column("likelihood", .text).notNull().defaults(to: "occasional")  // common, occasional, rare
                t.column("season_months", .text)  // JSON array: ["Jan","Feb"]
                t.column("depth_min_m", .integer)
                t.column("depth_max_m", .integer)
                t.column("source", .text)  // "gbif", "obis", "user", "curated"
                t.column("source_record_count", .integer)
                t.column("last_updated", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.primaryKey(["site_id", "species_id"], onConflict: .replace)
            }
            try db.create(index: "idx_site_species_site", on: "site_species", columns: ["site_id"])
            try db.create(index: "idx_site_species_species", on: "site_species", columns: ["species_id"])
            try db.create(index: "idx_site_species_likelihood", on: "site_species", columns: ["likelihood"])

            // FTS5 for species search
            try db.create(virtualTable: "species_fts", using: FTS5()) { t in
                t.column("name")
                t.column("scientific_name")
                // Note: Manual population required via INSERT INTO species_fts
            }
        }

        // MARK: - v6: GPS Draft Logging & Planned Sites
        migrator.registerMigration("v6_gps_draft_planned_sites") { db in
            // Add isPlanned column to sites
            try db.alter(table: "sites") { t in
                t.add(column: "isPlanned", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "idx_sites_planned", on: "sites", columns: ["isPlanned"])

            // Rebuild dives table to make siteId nullable and add GPS columns.
            // SQLite doesn't support ALTER COLUMN, so we must recreate the table.

            // 1. Create new dives table with nullable siteId and GPS columns
            try db.execute(sql: """
                CREATE TABLE dives_new (
                    id TEXT PRIMARY KEY,
                    siteId TEXT REFERENCES sites(id) ON DELETE RESTRICT,
                    pendingLatitude REAL,
                    pendingLongitude REAL,
                    date DATETIME NOT NULL,
                    startTime DATETIME NOT NULL,
                    endTime DATETIME,
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
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL,
                    CHECK (siteId IS NOT NULL OR (pendingLatitude IS NOT NULL AND pendingLongitude IS NOT NULL))
                )
            """)

            // 2. Copy existing data (all existing dives have siteId, GPS fields will be NULL)
            try db.execute(sql: """
                INSERT INTO dives_new (
                    id, siteId, pendingLatitude, pendingLongitude, date, startTime, endTime,
                    maxDepth, averageDepth, bottomTime, startPressure, endPressure,
                    temperature, visibility, current, conditions, notes,
                    instructorName, instructorNumber, signed, createdAt, updatedAt
                )
                SELECT
                    id, siteId, NULL, NULL, date, startTime, endTime,
                    maxDepth, averageDepth, bottomTime, startPressure, endPressure,
                    temperature, visibility, current, conditions, notes,
                    instructorName, instructorNumber, signed, createdAt, updatedAt
                FROM dives
            """)

            // 3. Drop old table and rename new one
            try db.execute(sql: "DROP TABLE dives")
            try db.execute(sql: "ALTER TABLE dives_new RENAME TO dives")

            // 4. Recreate indexes
            try db.create(index: "idx_dives_start_time", on: "dives", columns: ["startTime"])
            try db.create(index: "idx_dives_site", on: "dives", columns: ["siteId"])
            try db.create(index: "idx_dives_date", on: "dives", columns: ["date"])
            try db.create(
                index: "idx_dives_pending_gps",
                on: "dives",
                columns: ["pendingLatitude", "pendingLongitude"]
            )
        }

        // MARK: - v7: CloudKit Sync, Trips, User Site States
        migrator.registerMigration("v7_sync_trips_user_states") { db in
            // Sync metadata table - tracks sync status for each record
            try db.create(table: "sync_metadata") { t in
                t.column("id", .text).primaryKey()
                t.column("record_type", .text).notNull()  // "dives", "sightings", "user_site_states"
                t.column("local_record_id", .text).notNull()
                t.column("ck_record_id", .text)
                t.column("ck_system_fields", .blob)  // Serialized CKRecord.ID + metadata
                t.column("sync_status", .text).notNull().defaults(to: "pending")  // pending, synced, conflict, error
                t.column("last_synced_at", .datetime)
                t.column("local_updated_at", .datetime).notNull()
                t.column("error_message", .text)
                t.column("retry_count", .integer).notNull().defaults(to: 0)
            }
            try db.create(
                index: "idx_sync_metadata_record",
                on: "sync_metadata",
                columns: ["record_type", "local_record_id"],
                unique: true
            )
            try db.create(index: "idx_sync_metadata_status", on: "sync_metadata", columns: ["sync_status"])

            // Sync queue for pending operations
            try db.create(table: "sync_queue") { t in
                t.column("id", .text).primaryKey()
                t.column("operation", .text).notNull()  // "create", "update", "delete"
                t.column("record_type", .text).notNull()
                t.column("local_record_id", .text).notNull()
                t.column("payload", .blob)  // JSON-encoded record data
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("attempts", .integer).notNull().defaults(to: 0)
                t.column("last_attempt_at", .datetime)
                t.column("error_message", .text)
                t.column("priority", .integer).notNull().defaults(to: 0)  // Higher = more urgent
            }
            try db.create(index: "idx_sync_queue_priority", on: "sync_queue", columns: ["priority"])
            try db.create(index: "idx_sync_queue_record", on: "sync_queue", columns: ["record_type", "local_record_id"])

            // User site states - separates user data from seed data
            // This allows sync of user preferences without syncing the entire sites table
            try db.create(table: "user_site_states") { t in
                t.column("site_id", .text).primaryKey()
                    .references("sites", onDelete: .cascade)
                t.column("is_wishlist", .boolean).notNull().defaults(to: false)
                t.column("is_planned", .boolean).notNull().defaults(to: false)
                t.column("user_notes", .text)
                t.column("user_rating", .integer)  // 1-5 stars
                t.column("last_visited_at", .datetime)
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updated_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(index: "idx_user_site_states_wishlist", on: "user_site_states", columns: ["is_wishlist"])
            try db.create(index: "idx_user_site_states_planned", on: "user_site_states", columns: ["is_planned"])

            // Trips table for trip planning
            try db.create(table: "trips") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("start_date", .date)
                t.column("end_date", .date)
                t.column("notes", .text)
                t.column("cover_image_url", .text)
                t.column("calendar_event_id", .text)  // EventKit identifier
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updated_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(index: "idx_trips_dates", on: "trips", columns: ["start_date", "end_date"])

            // Trip sites junction table
            try db.create(table: "trip_sites") { t in
                t.column("trip_id", .text).notNull()
                    .references("trips", onDelete: .cascade)
                t.column("site_id", .text).notNull()
                    .references("sites", onDelete: .cascade)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("planned_date", .date)
                t.column("notes", .text)
                t.primaryKey(["trip_id", "site_id"], onConflict: .replace)
            }
            try db.create(index: "idx_trip_sites_trip", on: "trip_sites", columns: ["trip_id"])
            try db.create(index: "idx_trip_sites_site", on: "trip_sites", columns: ["site_id"])

            // Migrate existing wishlist/planned data from sites to user_site_states
            try db.execute(sql: """
                INSERT INTO user_site_states (site_id, is_wishlist, is_planned, updated_at)
                SELECT id, wishlist, isPlanned, CURRENT_TIMESTAMP
                FROM sites
                WHERE wishlist = 1 OR isPlanned = 1
            """)
        }

        // MARK: - v8: Region Descriptions
        migrator.registerMigration("v8_region_descriptions") { db in
            try db.alter(table: "regions") { t in
                t.add(column: "tagline", .text)
                t.add(column: "description", .text)
            }
        }

        // MARK: - v9: FTS5 Incremental Triggers
        // Eliminates the need for full FTS5 rebuild after seed data changes
        migrator.registerMigration("v9_fts5_incremental_triggers") { db in
            // Drop any legacy auto-generated triggers
            try db.execute(sql: "DROP TRIGGER IF EXISTS __sites_fts_ai")
            try db.execute(sql: "DROP TRIGGER IF EXISTS __sites_fts_ad")
            try db.execute(sql: "DROP TRIGGER IF EXISTS __sites_fts_au")

            // Sites FTS triggers - keep index in sync automatically
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS sites_fts_insert AFTER INSERT ON sites BEGIN
                    INSERT INTO sites_fts(rowid, name, region, location, tags, description)
                    VALUES (NEW.rowid, NEW.name, NEW.region, NEW.location, NEW.tags, NEW.description);
                END
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS sites_fts_update AFTER UPDATE ON sites BEGIN
                    DELETE FROM sites_fts WHERE rowid = OLD.rowid;
                    INSERT INTO sites_fts(rowid, name, region, location, tags, description)
                    VALUES (NEW.rowid, NEW.name, NEW.region, NEW.location, NEW.tags, NEW.description);
                END
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS sites_fts_delete AFTER DELETE ON sites BEGIN
                    DELETE FROM sites_fts WHERE rowid = OLD.rowid;
                END
            """)

            // Species FTS triggers
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS species_fts_insert AFTER INSERT ON wildlife_species BEGIN
                    INSERT INTO species_fts(rowid, name, scientific_name)
                    VALUES (NEW.rowid, NEW.name, NEW.scientificName);
                END
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS species_fts_update AFTER UPDATE ON wildlife_species BEGIN
                    DELETE FROM species_fts WHERE rowid = OLD.rowid;
                    INSERT INTO species_fts(rowid, name, scientific_name)
                    VALUES (NEW.rowid, NEW.name, NEW.scientificName);
                END
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS species_fts_delete AFTER DELETE ON wildlife_species BEGIN
                    DELETE FROM species_fts WHERE rowid = OLD.rowid;
                END
            """)
        }

        // MARK: - v10: Certifications + Sighting Photos
        migrator.registerMigration("v10_certifications_sighting_photos") { db in
            try db.create(table: "certifications") { t in
                t.column("id", .text).primaryKey()
                t.column("agency", .text).notNull()
                t.column("agencyOther", .text)
                t.column("level", .text).notNull()
                t.column("certNumber", .text)
                t.column("certDate", .datetime)
                t.column("expiryDate", .datetime)
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
            try db.create(index: "idx_certifications_primary", on: "certifications", columns: ["isPrimary"])
            try db.create(index: "idx_certifications_updated_at", on: "certifications", columns: ["updatedAt"])

            try db.create(table: "sighting_photos") { t in
                t.column("id", .text).primaryKey()
                t.column("sightingId", .text).notNull()
                    .references("sightings", onDelete: .cascade)
                t.column("filename", .text).notNull()
                t.column("thumbnailFilename", .text).notNull()
                t.column("width", .integer).notNull()
                t.column("height", .integer).notNull()
                t.column("capturedAt", .datetime)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_sighting_photos_sighting", on: "sighting_photos", columns: ["sightingId"])
            try db.create(index: "idx_sighting_photos_sort", on: "sighting_photos", columns: ["sightingId", "sortOrder"])
        }

        // MARK: - v11: BLE Dive Profiles + Gear Inventory + AI Metadata
        migrator.registerMigration("v11_ble_profiles_gear_ai") { db in
            try db.create(table: "dive_profiles") { t in
                t.column("id", .text).primaryKey()
                t.column("diveId", .text).notNull().unique()
                    .references("dives", onDelete: .cascade)
                t.column("samples", .blob).notNull()
                t.column("sampleIntervalSec", .integer)
                t.column("sampleCount", .integer).notNull()
                t.column("source", .text).notNull().defaults(to: "unknown")
                t.column("computerSerial", .text)
                t.column("computerModel", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_dive_profiles_dive", on: "dive_profiles", columns: ["diveId"], unique: true)

            try db.create(table: "gear_items") { t in
                t.column("id", .text).primaryKey()
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
            try db.create(index: "idx_gear_items_active", on: "gear_items", columns: ["isActive"])
            try db.create(index: "idx_gear_items_next_service", on: "gear_items", columns: ["nextServiceDate"])

            try db.create(table: "dive_gear") { t in
                t.column("diveId", .text).notNull()
                    .references("dives", onDelete: .cascade)
                t.column("gearId", .text).notNull()
                    .references("gear_items", onDelete: .cascade)
                t.primaryKey(["diveId", "gearId"], onConflict: .replace)
            }
            try db.create(index: "idx_dive_gear_gear", on: "dive_gear", columns: ["gearId"])

            try db.alter(table: "dives") { t in
                t.add(column: "gasMixesJson", .text)
                t.add(column: "computerDiveNumber", .integer)
                t.add(column: "surfaceInterval", .integer)
                t.add(column: "safetyStopPerformed", .boolean)
            }
            try db.create(index: "idx_dives_computer_number", on: "dives", columns: ["computerDiveNumber"])

            try db.alter(table: "sightings") { t in
                t.add(column: "aiConfidence", .double)
                t.add(column: "aiSuggestionsJson", .text)
            }
        }

        // Run migrations
        try migrator.migrate(writer)
    }
}
