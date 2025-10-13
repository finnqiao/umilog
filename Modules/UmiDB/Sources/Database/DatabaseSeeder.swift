import Foundation
import os

public enum DatabaseSeeder {
    static let logger = Logger(subsystem: "app.umilog", category: "DatabaseSeeder")
    
    // MARK: - Main Seeding Entry Point
    
    /// Seeds the database with comprehensive test data from JSON files
    public static func seedIfNeeded() throws {
        let db = AppDatabase.shared
        
        // Check if database is already seeded
        let siteCount = try db.siteRepository.fetchAll().count
        if siteCount > 0 {
            Self.logger.log("Database already seeded (\\(siteCount, privacy: .public) sites)")
            return
        }
        
        Self.logger.log("🌱 Starting database seed...")
        
        // 1. Load and seed dive sites
        try seedSites()
        
        // 2. Load and seed wildlife species
        try seedSpecies()
        
        // 3. Load and seed dive logs
        try seedDives()
        
        // 4. Load and seed wildlife sightings
        try seedSightings()
        
        Self.logger.log("✅ Database seeding complete!")
    }
    
    // MARK: - Site Seeding
    
    private static func seedSites() throws {
        Self.logger.log("  📍 Loading dive sites...")
        
        // Load multiple optional site files
        let primary = try loadJSON("sites_seed", as: SitesSeedFile.self)
        let ext1 = optionalJSON("sites_extended", as: SitesSeedFile.self)
        let ext2 = optionalJSON("sites_extended2", as: SitesSeedFile.self)
        let ext3 = optionalJSON("sites_wikidata", as: SitesSeedFile.self)
        
        let seedArrays: [[SiteSeedData]] = [primary.sites, ext1?.sites ?? [], ext2?.sites ?? [], ext3?.sites ?? []]
        let allSiteData = seedArrays.flatMap { $0 }
        
        // Deduplicate by id to avoid primary key insert failures when sources overlap
        var unique: [String: SiteSeedData] = [:]
        for s in allSiteData {
            // Keep first occurrence to prefer curated seeds over external
            if unique[s.id] == nil {
                unique[s.id] = s
            }
        }
        let sites = unique.values.map { convertToSite($0) }
        
        let db = AppDatabase.shared
        try db.siteRepository.createMany(sites)
        
        let regionCount = Set(sites.map { $0.region }).count
        Self.logger.log("  ✅ Loaded \\(sites.count, privacy: .public) sites across \\(regionCount, privacy: .public) regions")
    }
    
    private static func convertToSite(_ json: SiteSeedData) -> DiveSite {
        // Combine area and country to form location
        let location = [json.area, json.country].joined(separator: ", ")
        
        return DiveSite(
            id: json.id,
            name: json.name,
            location: location,
            latitude: json.latitude,
            longitude: json.longitude,
            region: json.region,
            averageDepth: json.averageDepth,
            maxDepth: json.maxDepth,
            averageTemp: json.averageTemp,
            averageVisibility: json.averageVisibility,
            difficulty: DiveSite.Difficulty(rawValue: json.difficulty) ?? .intermediate,
            type: convertSiteType(json.type),
            description: json.description,
            wishlist: json.wishlist,
            visitedCount: json.visitedCount,
            createdAt: Date()
        )
    }
    
    private static func convertSiteType(_ typeString: String) -> DiveSite.SiteType {
        // Handle extended site types that don't map directly
        switch typeString {
        case "Pinnacle", "Seamount", "Chimney", "Bay", "Cenote", "Sinkhole":
            return .wall // Map to closest existing type
        default:
            return DiveSite.SiteType(rawValue: typeString) ?? .reef
        }
    }
    
    // MARK: - Species Seeding
    
    private static func seedSpecies() throws {
        Self.logger.log("  🐠 Loading wildlife species...")
        
        let catalog = try loadJSON("species_catalog", as: SpeciesCatalogFile.self)
        
        let db = AppDatabase.shared
        
        // Insert species one by one (no bulk insert method for species yet)
        for speciesData in catalog.species {
            let species = WildlifeSpecies(
                id: speciesData.id,
                name: speciesData.name,
                scientificName: speciesData.scientificName,
                category: WildlifeSpecies.Category(rawValue: speciesData.category) ?? .fish,
                rarity: convertRarity(speciesData.rarity),
                regions: speciesData.regions,
                imageUrl: speciesData.imageUrl
            )
            
            try db.write { db in
                try species.insert(db)
            }
        }
        
        Self.logger.log("  ✅ Loaded \\(catalog.species.count, privacy: .public) wildlife species")
    }
    
    private static func convertRarity(_ rarityString: String) -> WildlifeSpecies.Rarity {
        switch rarityString {
        case "VeryRare":
            return .veryRare
        default:
            return WildlifeSpecies.Rarity(rawValue: rarityString) ?? .common
        }
    }
    
    // MARK: - Dive Log Seeding
    
    private static func seedDives() throws {
        Self.logger.log("  📝 Loading dive logs...")
        
        let logsFile = try loadJSON("dive_logs_mock", as: DiveLogsSeedFile.self)
        
        let db = AppDatabase.shared
        let dateFormatter = ISO8601DateFormatter()
        
        for logData in logsFile.dives {
            let dive = DiveLog(
                id: logData.id,
                siteId: logData.siteId,
                date: dateFormatter.date(from: logData.date) ?? Date(),
                startTime: dateFormatter.date(from: logData.startTime) ?? Date(),
                endTime: logData.endTime.flatMap { dateFormatter.date(from: $0) },
                maxDepth: logData.maxDepth,
                averageDepth: logData.averageDepth,
                bottomTime: logData.bottomTime,
                startPressure: logData.startPressure,
                endPressure: logData.endPressure,
                temperature: logData.temperature,
                visibility: logData.visibility,
                current: DiveLog.Current(rawValue: logData.current) ?? .none,
                conditions: DiveLog.Conditions(rawValue: logData.conditions) ?? .good,
                notes: logData.notes,
                instructorName: logData.instructorName,
                instructorNumber: logData.instructorNumber,
                signed: logData.signed,
                createdAt: dateFormatter.date(from: logData.createdAt) ?? Date(),
                updatedAt: dateFormatter.date(from: logData.updatedAt) ?? Date()
            )
            
            try db.diveRepository.create(dive)
        }
        
        Self.logger.log("  ✅ Loaded \\(logsFile.dives.count, privacy: .public) dive logs")
    }
    
    // MARK: - Sighting Seeding
    
    private static func seedSightings() throws {
        Self.logger.log("  👁️ Loading wildlife sightings...")
        
        let sightingsFile = try loadJSON("sightings_mock", as: SightingsSeedFile.self)
        
        let db = AppDatabase.shared
        let dateFormatter = ISO8601DateFormatter()
        
        for sightingData in sightingsFile.sightings {
            let sighting = WildlifeSighting(
                id: sightingData.id,
                diveId: sightingData.diveId,
                speciesId: sightingData.speciesId,
                count: sightingData.count,
                notes: sightingData.notes,
                createdAt: dateFormatter.date(from: sightingData.createdAt) ?? Date()
            )
            
            try db.write { db in
                try sighting.insert(db)
            }
        }
        
        Self.logger.log("  ✅ Loaded \\(sightingsFile.sightings.count, privacy: .public) wildlife sightings")
    }
    
    // MARK: - JSON Loading
    
    private static func loadJSON<T: Decodable>(_ filename: String, as type: T.Type) throws -> T {
        // Try multiple paths to find the JSON files
        let possiblePaths: [URL?] = [
            // Most common: files are at the bundle root (as our logs show)
            Bundle.main.url(forResource: filename, withExtension: "json"),
            // Subdirectories we may have configured
            Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "SeedData"),
            Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Resources/SeedData"),
            Bundle.main.url(forResource: "Resources/SeedData/\(filename)", withExtension: "json")
        ]
        
        guard let url = possiblePaths.compactMap({ $0 }).first else {
            // Print available resources for debugging
            if let resourcePath = Bundle.main.resourcePath {
                Self.logger.error("  📂 Bundle resource path: \\(resourcePath, privacy: .public)")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                    Self.logger.error("  📂 Available resources sample: \\(String(describing: contents.prefix(50)), privacy: .public)")
                }
            }
            throw SeedError.fileNotFound(filename)
        }
        
        Self.logger.log("  ✅ Found file at: \\(url.lastPathComponent, privacy: .public)")
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Errors
    
    enum SeedError: LocalizedError {
        case fileNotFound(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "Seed data file not found: \(filename).json"
            }
        }
    }
    // Optional loader that returns nil if the file is not present
    private static func optionalJSON<T: Decodable>(_ filename: String, as type: T.Type) -> T? {
        do {
            return try loadJSON(filename, as: type)
        } catch {
            if case SeedError.fileNotFound = error {
                Self.logger.log("  ℹ️ Optional seed file not found: \\(filename, privacy: .public).json")
                return nil
            }
            Self.logger.error("  ❌ Error loading optional file: \\(filename, privacy: .public) – \\((error as NSError).localizedDescription, privacy: .public)")
            return nil
        }
    }
}

// MARK: - JSON Decodable Models

private struct SitesSeedFile: Decodable {
    let sites: [SiteSeedData]
}

private struct SiteSeedData: Decodable {
    let id: String
    let name: String
    let region: String
    let area: String
    let country: String
    let latitude: Double
    let longitude: Double
    let averageDepth: Double
    let maxDepth: Double
    let averageTemp: Double
    let averageVisibility: Double
    let difficulty: String
    let type: String
    let description: String
    let wishlist: Bool
    let visitedCount: Int
}

private struct SpeciesCatalogFile: Decodable {
    let species: [SpeciesSeedData]
}

private struct SpeciesSeedData: Decodable {
    let id: String
    let name: String
    let scientificName: String
    let category: String
    let rarity: String
    let regions: [String]
    let imageUrl: String?
}

private struct DiveLogsSeedFile: Decodable {
    let dives: [DiveLogSeedData]
}

private struct DiveLogSeedData: Decodable {
    let id: String
    let siteId: String
    let date: String
    let startTime: String
    let endTime: String?
    let maxDepth: Double
    let averageDepth: Double?
    let bottomTime: Int
    let startPressure: Int
    let endPressure: Int
    let temperature: Double
    let visibility: Double
    let current: String
    let conditions: String
    let notes: String
    let instructorName: String?
    let instructorNumber: String?
    let signed: Bool
    let createdAt: String
    let updatedAt: String
}

private struct SightingsSeedFile: Decodable {
    let sightings: [SightingSeedData]
}

private struct SightingSeedData: Decodable {
    let id: String
    let diveId: String
    let speciesId: String
    let count: Int
    let notes: String?
    let createdAt: String
}
