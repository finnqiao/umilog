import Foundation

public enum DatabaseSeeder {
    
    // MARK: - Main Seeding Entry Point
    
    /// Seeds the database with comprehensive test data from JSON files
    public static func seedIfNeeded() throws {
        let db = AppDatabase.shared
        
        // Check if database is already seeded
        let siteCount = try db.siteRepository.fetchAll().count
        if siteCount > 0 {
            print("📊 Database already seeded (\(siteCount) sites found)")
            return
        }
        
        print("🌱 Starting database seed...")
        
        // 1. Load and seed dive sites
        try seedSites()
        
        // 2. Load and seed wildlife species
        try seedSpecies()
        
        // 3. Load and seed dive logs
        try seedDives()
        
        // 4. Load and seed wildlife sightings
        try seedSightings()
        
        print("✅ Database seeding complete!")
    }
    
    // MARK: - Site Seeding
    
    private static func seedSites() throws {
        print("  📍 Loading dive sites...")
        
        // Load both seed files
        let seedSites = try loadJSON("sites_seed", as: SitesSeedFile.self)
        let extendedSites = try loadJSON("sites_extended", as: SitesSeedFile.self)
        
        let allSiteData = seedSites.sites + extendedSites.sites
        let sites = allSiteData.map { convertToSite($0) }
        
        let db = AppDatabase.shared
        try db.siteRepository.createMany(sites)
        
        print("  ✅ Loaded \(sites.count) dive sites")
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
        print("  🐠 Loading wildlife species...")
        
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
        
        print("  ✅ Loaded \(catalog.species.count) wildlife species")
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
        print("  📝 Loading dive logs...")
        
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
        
        print("  ✅ Loaded \(logsFile.dives.count) dive logs")
    }
    
    // MARK: - Sighting Seeding
    
    private static func seedSightings() throws {
        print("  👁️ Loading wildlife sightings...")
        
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
        
        print("  ✅ Loaded \(sightingsFile.sightings.count) wildlife sightings")
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
                print("  📂 Bundle resource path: \(resourcePath)")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                    print("  📂 Available resources: \(contents.prefix(50))")
                }
            }
            throw SeedError.fileNotFound(filename)
        }
        
        print("  ✅ Found file at: \(url.lastPathComponent)")
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
