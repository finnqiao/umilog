import Foundation
import GRDB

public enum DatabaseMigrator {
    public static func migrate(_ db: Database) throws {
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
        
        // Run migrations
        try migrator.migrate(db)
    }
}
