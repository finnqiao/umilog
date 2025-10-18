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
        
        // Run migrations
        try migrator.migrate(writer)
    }
}
