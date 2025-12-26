import Foundation
import os

public enum DatabaseSeeder {
    static let logger = Logger(subsystem: "app.umilog", category: "DatabaseSeeder")
    
    // MARK: - Main Seeding Entry Point

    /// Seeds the database with comprehensive test data from JSON files
    public static func seedIfNeeded() throws {
        let db = AppDatabase.shared

        Self.logger.log("🌱 Starting database seed...")
        var seededSomething = false

        // v5: Geographic hierarchy (countries, regions, areas)
        let geoRepo = GeographyRepository(database: db)
        let countryCount = try geoRepo.countCountries()
        if countryCount == 0 {
            try seedGeographicHierarchy(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Geographic hierarchy already present (\\(countryCount, privacy: .public) countries)")
        }

        // v5: Species families
        let speciesRepo = SpeciesRepository(database: db)
        let familyCount = try speciesRepo.countFamilies()
        if familyCount == 0 {
            try seedSpeciesFamilies(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Species families already present (\\(familyCount, privacy: .public))")
        }

        // Sites
        let siteCount = try db.siteRepository.fetchAll().count
        if siteCount == 0 {
            try seedSites(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Sites already present (\\(siteCount, privacy: .public))")
        }

        // Species
        let speciesCount = try speciesRepo.fetchAll().count
        if speciesCount == 0 {
            try seedSpecies(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Species already present (\\(speciesCount, privacy: .public))")
        }

        // v5: Site-species links
        let linksCount = try speciesRepo.countSiteLinks()
        if linksCount == 0 && speciesCount > 0 && siteCount > 0 {
            try seedSiteSpeciesLinks(); seededSomething = true
        } else if linksCount > 0 {
            Self.logger.log("  ℹ️ Site-species links already present (\\(linksCount, privacy: .public))")
        }

        // Dives
        let diveCount = try db.diveRepository.fetchAll().count
        if diveCount == 0 {
            try seedDives(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Dives already present (\\(diveCount, privacy: .public))")
        }

        // Sightings
        let sightingsCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sightings") ?? 0
        }
        if sightingsCount == 0 {
            try seedSightings(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Sightings already present (\\(sightingsCount, privacy: .public))")
        }

        if seededSomething {
            Self.logger.log("✅ Database seeding complete!")
        } else {
            Self.logger.log("✅ Database already seeded; nothing to do")
        }
    }

    // MARK: - v5: Geographic Hierarchy Seeding

    private static func seedGeographicHierarchy() throws {
        Self.logger.log("  🌍 Loading geographic hierarchy...")

        let db = AppDatabase.shared
        let geoRepo = GeographyRepository(database: db)

        // Load countries
        if let countriesFile = optionalJSON("countries", as: CountriesSeedFile.self) {
            let countries = countriesFile.countries.map { data in
                Country(
                    id: data.id,
                    name: data.name,
                    nameLocal: data.name_local,
                    continent: data.continent,
                    wikidataId: data.wikidata_id
                )
            }
            try geoRepo.createCountries(countries)
            Self.logger.log("  ✅ Loaded \\(countries.count, privacy: .public) countries")
        }

        // Load regions
        if let regionsFile = optionalJSON("regions", as: RegionsSeedFile.self) {
            let regions = regionsFile.regions.map { data in
                Region(
                    id: data.id,
                    name: data.name,
                    countryId: data.country_id,
                    latitude: data.latitude,
                    longitude: data.longitude,
                    wikidataId: data.wikidata_id
                )
            }
            try geoRepo.createRegions(regions)
            Self.logger.log("  ✅ Loaded \\(regions.count, privacy: .public) regions")
        }

        // Load areas
        if let areasFile = optionalJSON("areas", as: AreasSeedFile.self) {
            let areas = areasFile.areas.map { data in
                Area(
                    id: data.id,
                    name: data.name,
                    regionId: data.region_id,
                    countryId: data.country_id,
                    latitude: data.latitude,
                    longitude: data.longitude,
                    wikidataId: data.wikidata_id
                )
            }
            try geoRepo.createAreas(areas)
            Self.logger.log("  ✅ Loaded \\(areas.count, privacy: .public) areas")
        }
    }

    // MARK: - v5: Species Families Seeding

    private static func seedSpeciesFamilies() throws {
        Self.logger.log("  🐠 Loading species families...")

        guard let familiesFile = optionalJSON("families_catalog", as: FamiliesSeedFile.self) else {
            Self.logger.log("  ℹ️ No families_catalog.json found")
            return
        }

        let db = AppDatabase.shared
        let speciesRepo = SpeciesRepository(database: db)

        let families = familiesFile.families.map { data in
            SpeciesFamily(
                id: data.id,
                name: data.name,
                scientificName: data.scientific_name,
                category: WildlifeSpecies.Category(rawValue: data.category) ?? .fish,
                wormsAphiaId: data.worms_aphia_id,
                gbifKey: data.gbif_key
            )
        }

        try speciesRepo.createFamilies(families)
        Self.logger.log("  ✅ Loaded \\(families.count, privacy: .public) species families")
    }

    // MARK: - v5: Site-Species Links Seeding

    private static func seedSiteSpeciesLinks() throws {
        Self.logger.log("  🔗 Loading site-species links...")

        guard let linksFile = optionalJSON("site_species", as: SiteSpeciesSeedFile.self) else {
            Self.logger.log("  ℹ️ No site_species.json found")
            return
        }

        let db = AppDatabase.shared
        let speciesRepo = SpeciesRepository(database: db)
        let dateFormatter = ISO8601DateFormatter()

        let links = linksFile.site_species.compactMap { data -> SiteSpeciesLink? in
            guard let likelihood = SiteSpeciesLink.Likelihood(rawValue: data.likelihood) else {
                return nil
            }
            return SiteSpeciesLink(
                siteId: data.site_id,
                speciesId: data.species_id,
                likelihood: likelihood,
                seasonMonths: data.season_months,
                depthMinM: data.depth_min_m,
                depthMaxM: data.depth_max_m,
                source: data.source,
                sourceRecordCount: data.source_record_count,
                lastUpdated: dateFormatter.date(from: data.last_updated) ?? Date()
            )
        }

        try speciesRepo.createSiteLinks(links)
        Self.logger.log("  ✅ Loaded \\(links.count, privacy: .public) site-species links")
    }
    
    // MARK: - Site Seeding
    
    private static func seedSites() throws {
        Self.logger.log("  📍 Loading dive sites...")
        
        // Try to load from optimized regional tiles first
        do {
            if try loadOptimizedTiles() {
                return  // Successfully loaded from tiles
            }
        } catch {
            Self.logger.warning("  ⚠️ Optimized tiles load failed: \\(error.localizedDescription, privacy: .public)")
        }
        
        // Fall back to legacy multi-file loading
        Self.logger.log("  ℹ️ Falling back to legacy seed files")
        var allSites: [SiteSeedData] = []
        
        let seedFiles = ["sites_seed", "sites_extended", "sites_extended2", "sites_wikidata"]
        for fileName in seedFiles {
            if let file = optionalJSON(fileName, as: SitesSeedFile.self) {
                Self.logger.log("  ℹ️ Loaded \\(file.sites.count, privacy: .public) from \\(fileName, privacy: .public)")
                allSites.append(contentsOf: file.sites)
            }
        }
        
        guard !allSites.isEmpty else {
            Self.logger.error("  ❌ No seed files loaded")
            return
        }
        
        // Deduplicate by id to avoid primary key insert failures when sources overlap
        var unique: [String: SiteSeedData] = [:]
        for s in allSites {
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
    
    /// Loads optimized regional tiles from manifest
    private static func loadOptimizedTiles() throws -> Bool {
        Self.logger.log("  🗂️ Attempting to load optimized regional tiles...")
        
        guard let manifestUrl = Bundle.main.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: "optimized/tiles"
        ) else {
            Self.logger.log("  ℹ️ No manifest found in optimized/tiles")
            return false
        }
        
        let manifestData = try Data(contentsOf: manifestUrl)
        let manifest = try JSONDecoder().decode(TileManifest.self, from: manifestData)
        
        let db = AppDatabase.shared
        var totalSites = 0
        var loadedRegions = 0
        
        // Load each regional tile
        for tile in manifest.tiles {
            guard let tileUrl = Bundle.main.url(
                forResource: tile.name.replacingOccurrences(of: ".json", with: ""),
                withExtension: "json",
                subdirectory: "optimized/tiles"
            ) else {
                Self.logger.warning("  ⚠️ Tile not found: \\(tile.name, privacy: .public)")
                continue
            }
            
            let tileData = try Data(contentsOf: tileUrl)
            let tileFile = try JSONDecoder().decode(RegionalTile.self, from: tileData)
            
            // Convert and insert sites from this tile
            let sites = tileFile.sites.map { convertOptimizedSiteToModel($0) }
            try db.siteRepository.createMany(sites)
            
            totalSites += sites.count
            loadedRegions += 1
            
            Self.logger.log("  ✅ Loaded tile \\(tile.region, privacy: .public): \\(sites.count, privacy: .public) sites")
        }
        
        if totalSites > 0 {
            Self.logger.log("  ✅ Loaded \\(totalSites, privacy: .public) sites from \\(loadedRegions, privacy: .public) regional tiles")
            return true
        }
        
        return false
    }
    
    /// Convert optimized site format to DiveSite model
    private static func convertOptimizedSiteToModel(_ optimized: OptimizedSite) -> DiveSite {
        return DiveSite(
            id: optimized.id,
            name: optimized.name,
            location: [optimized.country].compactMap { $0 }.joined(separator: ", "),
            latitude: optimized.latitude,
            longitude: optimized.longitude,
            region: optimized.region,
            averageDepth: Double(optimized.maxDepth) * 0.7,  // Estimate average as 70% of max
            maxDepth: Double(optimized.maxDepth),
            averageTemp: 0,  // Not available in optimized format
            averageVisibility: 0,  // Not available in optimized format
            difficulty: .intermediate,  // Default; can be enhanced later
            type: .reef,  // Default; can be inferred from description
            description: optimized.description ?? "",
            wishlist: optimized.wishlist,
            visitedCount: optimized.visitedCount,
            createdAt: Date()
        )
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

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let legacy = try? container.decode([String: [SiteSeedData]].self), let legacySites = legacy["sites"] {
            self.sites = legacySites
            return
        }

        if let featureCollection = try? container.decode(GeoJSONFeatureCollection.self) {
            self.sites = featureCollection.features.compactMap { SiteSeedData(feature: $0) }
            return
        }

        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported sites seed format"))
    }
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

private struct GeoJSONFeatureCollection: Decodable {
    let type: String
    let features: [GeoJSONFeature]
}

private struct GeoJSONFeature: Decodable {
    let type: String
    let properties: GeoJSONProperties
    let geometry: GeoJSONGeometry
}

private struct GeoJSONGeometry: Decodable {
    let type: String
    let coordinates: [Double]
}

private struct GeoJSONProperties: Decodable {
    let id: String?
    let name: String?
    let kind: String?
    let country: String?
    let region: String?
    let area: String?
    let source: String?
    let quality: Int?
    let depthMin: Int?
    let depthMax: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case country
        case region
        case area
        case source
        case quality
        case depthMin = "depth_min_m"
        case depthMax = "depth_max_m"
    }
}

private extension SiteSeedData {
    init?(feature: GeoJSONFeature) {
        guard feature.geometry.type == "Point" else { return nil }
        guard feature.geometry.coordinates.count >= 2 else { return nil }
        guard
            let id = feature.properties.id,
            let name = feature.properties.name,
            let region = feature.properties.region,
            let area = feature.properties.area,
            let country = feature.properties.country
        else {
            return nil
        }

        let longitude = feature.geometry.coordinates[0]
        let latitude = feature.geometry.coordinates[1]
        let depthMin = Double(feature.properties.depthMin ?? 0)
        let depthMax = Double(feature.properties.depthMax ?? feature.properties.depthMin ?? 0)

        let typeString: String
        switch feature.properties.kind?.lowercased() {
        case "wreck":
            typeString = "Wreck"
        case "site":
            typeString = "Reef"
        default:
            typeString = "Reef"
        }

        self.init(
            id: id,
            name: name,
            region: region,
            area: area,
            country: country,
            latitude: latitude,
            longitude: longitude,
            averageDepth: depthMin > 0 ? depthMin : depthMax,
            maxDepth: depthMax,
            averageTemp: 0,
            averageVisibility: 0,
            difficulty: "Intermediate",
            type: typeString,
            description: feature.properties.source ?? "",
            wishlist: false,
            visitedCount: 0
        )
    }
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

// MARK: - Optimized Tile Structures

private struct TileManifest: Decodable {
    let version: String
    let generated_at: String
    let tiles: [TileMetadata]
    let summary: TileSummary
}

private struct TileMetadata: Decodable {
    let name: String
    let region: String
    let count: Int
    let size_uncompressed_kb: Double
    let size_compressed_kb: Double
    let bounds: GeographicBounds?
}

private struct GeographicBounds: Decodable {
    let min_lat: Double
    let max_lat: Double
    let min_lon: Double
    let max_lon: Double
    let center_lat: Double
    let center_lon: Double
}

private struct TileSummary: Decodable {
    let total_sites: Int
    let total_regions: Int
    let total_size_uncompressed_mb: Double
    let total_size_compressed_mb: Double
}

private struct RegionalTile: Decodable {
    let region: String
    let sites: [OptimizedSite]
    let metadata: TileMetadata?
}

private struct OptimizedSite: Decodable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let region: String
    let description: String?
    let maxDepth: Int
    let source: String
    let license: String
    let verified: Bool
    let createdAt: String
    let wishlist: Bool
    let visitedCount: Int
}

private func resolveAreaAndCountry(for shop: ShopSeed, siteIndex: [String: DiveSite]) -> (String, String) {
    for nearby in shop.nearbyDiveSites {
        if let site = siteIndex[nearby.id] {
            let (area, country) = splitLocationComponents(site.location)
            return (area, country)
        }
    }
    return ("", shop.region ?? "")
}

private func splitLocationComponents(_ location: String) -> (String, String) {
    let parts = location
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    if parts.count >= 2 {
        return (String(parts[0]), String(parts[1]))
    } else if let first = parts.first {
        return (String(first), "")
    } else {
        return ("", "")
    }
}

private struct ComprehensiveDataset: Decodable {
    let shops: [ShopSeed]
}

private struct ShopSeed: Decodable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let type: String?
    let phone: String?
    let website: String?
    let email: String?
    let hours: String?
    let description: String?
    let source: String?
    let region: String?
    let nearbyDiveSites: [NearbySite]

    struct NearbySite: Decodable {
        let id: String
        let name: String
        let distanceApprox: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case distanceApprox = "distance_approx"
        }

        var distanceKm: Double? {
            guard let distanceApprox = distanceApprox?.trimmingCharacters(in: .whitespacesAndNewlines), !distanceApprox.isEmpty else {
                return nil
            }
            let cleaned = distanceApprox.replacingOccurrences(of: "[^0-9\\.]", with: "", options: .regularExpression)
            guard !cleaned.isEmpty else { return nil }
            return Double(cleaned)
        }
    }

    var normalizedServices: [String] {
        var services: [String] = []
        if let type = type?.trimmingCharacters(in: .whitespacesAndNewlines), !type.isEmpty {
            let formatted = type.replacingOccurrences(of: "_", with: " ").capitalized
            services.append(formatted)
        }
        if let hours = hours?.trimmingCharacters(in: .whitespacesAndNewlines), !hours.isEmpty {
            services.append("Hours: \(hours)")
        }
        return services
    }
}

// MARK: - v5: Geographic Hierarchy Seed Structures

private struct CountriesSeedFile: Decodable {
    let countries: [CountrySeedData]
}

private struct CountrySeedData: Decodable {
    let id: String
    let name: String
    let name_local: String?
    let continent: String
    let wikidata_id: String?
}

private struct RegionsSeedFile: Decodable {
    let regions: [RegionSeedData]
}

private struct RegionSeedData: Decodable {
    let id: String
    let name: String
    let country_id: String?
    let latitude: Double?
    let longitude: Double?
    let wikidata_id: String?
}

private struct AreasSeedFile: Decodable {
    let areas: [AreaSeedData]
}

private struct AreaSeedData: Decodable {
    let id: String
    let name: String
    let region_id: String?
    let country_id: String?
    let latitude: Double?
    let longitude: Double?
    let wikidata_id: String?
}

// MARK: - v5: Species Taxonomy Seed Structures

private struct FamiliesSeedFile: Decodable {
    let families: [FamilySeedData]
}

private struct FamilySeedData: Decodable {
    let id: String
    let name: String
    let scientific_name: String
    let category: String
    let worms_aphia_id: Int?
    let gbif_key: Int?
}

// MARK: - v5: Site-Species Links Seed Structures

private struct SiteSpeciesSeedFile: Decodable {
    let site_species: [SiteSpeciesSeedData]
}

private struct SiteSpeciesSeedData: Decodable {
    let site_id: String
    let species_id: String
    let likelihood: String
    let season_months: [String]?
    let depth_min_m: Int?
    let depth_max_m: Int?
    let source: String?
    let source_record_count: Int?
    let last_updated: String
}
