import Foundation
import os

public enum DatabaseSeeder {
    static let logger = Logger(subsystem: "app.umilog", category: "DatabaseSeeder")
    private static let seedDataVersionKey = "app.umilog.seedDataVersion"
    private static let seedRefreshPipelineVersionKey = "app.umilog.seedRefresh.pipelineVersion"
    private static let seedRefreshLastStepKey = "app.umilog.seedRefresh.lastStep"
    private static let seedRefreshLastErrorKey = "app.umilog.seedRefresh.lastError"
    private static let seedRefreshLastRunAtKey = "app.umilog.seedRefresh.lastRunAt"
    public static let seedDataVersion = "2026-02-05-llm-enrichment-v5"
    
    // MARK: - Main Seeding Entry Point

    /// Seeds only critical data needed to render the initial UI (sites + geography).
    /// Fast path: If pre-bundled database was copied, this returns immediately.
    public static func seedCriticalDataIfNeeded() throws {
        let db = AppDatabase.shared

        // Fast path: Check if database is pre-seeded (from bundled umilog_seed.db)
        let siteCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
        }

        if siteCount > 0 {
            Self.logger.log("✅ Database pre-seeded with \\(siteCount, privacy: .public) sites - skipping JSON seeding")
            return
        }

        Self.logger.log("🌱 Starting critical seed from JSON...")
        var seededSomething = false

        // Geographic hierarchy
        let geoRepo = GeographyRepository(database: db)
        let countryCount = try geoRepo.countCountries()
        if countryCount == 0 {
            try seedGeographicHierarchy(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Geographic hierarchy already present (\\(countryCount, privacy: .public) countries)")
        }

        // Sites
        if siteCount == 0 {
            try seedSites(); seededSomething = true
        }

        if seededSomething {
            Self.logger.log("✅ Critical seed complete!")
        } else {
            Self.logger.log("✅ Critical seed already satisfied; nothing to do")
        }
    }

    /// Seeds the database with comprehensive test data from JSON files.
    /// Fast path: If pre-bundled database was copied, this returns immediately.
    public static func seedIfNeeded() throws {
        let db = AppDatabase.shared
        let speciesRepo = SpeciesRepository(database: db)

        // Fast path: Check if database is pre-seeded (from bundled umilog_seed.db)
        // Pre-seeded DBs have sites, species, AND site-species links
        let siteCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
        }
        let speciesCount = try speciesRepo.count()
        let linksCount = try speciesRepo.countSiteLinks()

        if siteCount > 0 && speciesCount > 0 && linksCount > 0 {
            Self.logger.log("✅ Database pre-seeded - skipping JSON seeding")
            Self.logger.log("  Sites: \\(siteCount, privacy: .public), Species: \\(speciesCount, privacy: .public), Links: \\(linksCount, privacy: .public)")
            return
        }

        Self.logger.log("🌱 Starting database seed from JSON...")
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
        let familyCount = try speciesRepo.countFamilies()
        if familyCount == 0 {
            try seedSpeciesFamilies(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Species families already present (\\(familyCount, privacy: .public))")
        }

        // Sites
        var currentSiteCount = siteCount
        if currentSiteCount == 0 {
            try seedSites(); seededSomething = true
            currentSiteCount = try db.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
            }
        } else {
            Self.logger.log("  ℹ️ Sites already present (\\(currentSiteCount, privacy: .public))")
        }

        // Species
        let expectedSpeciesCount = loadSpeciesCatalogCount() ?? 0
        var currentSpeciesCount = speciesCount
        if currentSpeciesCount == 0 {
            try seedSpecies(); seededSomething = true
            currentSpeciesCount = try speciesRepo.count()
        } else if expectedSpeciesCount > 0 && currentSpeciesCount < expectedSpeciesCount {
            Self.logger.log("  ⚠️ Species catalog incomplete (\\(currentSpeciesCount, privacy: .public)/\\(expectedSpeciesCount, privacy: .public)); refreshing")
            try seedSpecies(); seededSomething = true
            currentSpeciesCount = try speciesRepo.count()
        } else {
            Self.logger.log("  ℹ️ Species already present (\\(currentSpeciesCount, privacy: .public))")
        }

        // v5: Site-species links
        let currentLinksCount = linksCount
        let canSeedLinks = currentSpeciesCount > 0
            && currentSiteCount > 0
            && (expectedSpeciesCount == 0 || currentSpeciesCount >= expectedSpeciesCount)
        if currentLinksCount == 0 && canSeedLinks {
            do {
                try seedSiteSpeciesLinks(); seededSomething = true
            } catch {
                Self.logger.error("  ❌ Site-species seeding failed: \(error.localizedDescription, privacy: .public)")
            }
        } else if currentLinksCount > 0 {
            Self.logger.log("  ℹ️ Site-species links already present (\\(currentLinksCount, privacy: .public))")
        } else if !canSeedLinks {
            Self.logger.log("  ℹ️ Skipping site-species links (species=\\(currentSpeciesCount, privacy: .public), expected=\\(expectedSpeciesCount, privacy: .public))")
        }

        // Dives (skip for pre-bundled - these are mock data)
        let diveCount = try db.diveRepository.fetchAll().count
        if diveCount == 0 {
            try seedDives(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Dives already present (\\(diveCount, privacy: .public))")
        }

        // Sightings (skip for pre-bundled - these are mock data)
        let sightingsCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sightings") ?? 0
        }
        if sightingsCount == 0 {
            try seedSightings(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Sightings already present (\\(sightingsCount, privacy: .public))")
        }

        // Site media
        let mediaCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM site_media") ?? 0
        }
        if mediaCount == 0 {
            try seedSiteMedia(); seededSomething = true
        } else {
            Self.logger.log("  ℹ️ Site media already present (\\(mediaCount, privacy: .public))")
        }

        if seededSomething {
            Self.logger.log("✅ Database seeding complete!")
        } else {
            Self.logger.log("✅ Database already seeded; nothing to do")
        }
    }

    /// Seeds (if empty) and refreshes seed data when the version changes.
    /// Fast path: If pre-bundled database at current version, returns immediately.
    public static func seedOrRefreshIfNeeded() throws {
        let defaults = UserDefaults.standard
        let currentVersion = defaults.string(forKey: seedDataVersionKey)
        let db = AppDatabase.shared

        let siteCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
        }

        // Fast path: Database is pre-seeded and at current version
        if siteCount > 0 && currentVersion == seedDataVersion {
            Self.logger.log("✅ Database at current version (\\(seedDataVersion, privacy: .public)) - skipping refresh")
            return
        }

        // Fast path: Pre-bundled database on first launch (version not set yet)
        // Assume pre-bundled DB is at current version
        if siteCount > 0 && currentVersion == nil {
            let speciesCount = try SpeciesRepository(database: db).count()
            let linksCount = try SpeciesRepository(database: db).countSiteLinks()

            // Pre-bundled DB has sites, species, AND links
            if speciesCount > 0 && linksCount > 0 {
                Self.logger.log("✅ Pre-bundled database detected on first launch - setting version")
                defaults.set(seedDataVersion, forKey: seedDataVersionKey)
                return
            }
        }

        try seedIfNeeded()
        try refreshSeedDataIfNeeded()
        try ensureEnrichedSeedData()
    }

    /// Check if database needs seeding or refresh (for UI progress indication)
    public static func needsSeedingOrRefresh() -> Bool {
        let defaults = UserDefaults.standard
        let currentVersion = defaults.string(forKey: seedDataVersionKey)

        // If version mismatch, needs refresh
        if currentVersion != seedDataVersion {
            return true
        }

        // If no sites, needs seeding
        do {
            let db = AppDatabase.shared
            let siteCount = try db.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
            }
            return siteCount == 0
        } catch {
            return true
        }
    }

    /// Refreshes seed data without wiping user data.
    public static func refreshSeedDataIfNeeded(force: Bool = false) throws {
        let defaults = UserDefaults.standard
        let currentVersion = defaults.string(forKey: seedDataVersionKey)
        guard force || currentVersion != seedDataVersion else {
            return
        }

        try refreshSeedData()
        defaults.set(seedDataVersion, forKey: seedDataVersionKey)
    }

    // MARK: - v5: Geographic Hierarchy Seeding

    private static func seedGeographicHierarchy() throws {
        Self.logger.log("  🌍 Loading geographic hierarchy...")

        let db = AppDatabase.shared
        let geoRepo = GeographyRepository(database: db)
        let regionEnrichments = loadRegionEnrichments()

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
                let enrichment = regionEnrichments[data.id]
                return Region(
                    id: data.id,
                    name: data.name,
                    countryId: data.country_id,
                    latitude: data.latitude,
                    longitude: data.longitude,
                    wikidataId: data.wikidata_id,
                    tagline: enrichment?.tagline,
                    description: enrichment?.description
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

    // MARK: - Seed Data Refresh

    private enum RefreshStep: String, CaseIterable {
        case disableLegacyFTSTriggers
        case refreshRegionDescriptions
        case refreshSpeciesCatalog
        case refreshSitesCatalog
        case refreshSiteDescriptions
        case refreshSiteSearchIndex
    }

    private static var refreshPipelineVersion: String {
        "\(seedDataVersion)-refresh-v2"
    }

    private static func refreshSeedData() throws {
        Self.logger.log("  🔄 Refreshing seed data (non-destructive)...")

        let defaults = UserDefaults.standard
        let storedPipelineVersion = defaults.string(forKey: seedRefreshPipelineVersionKey)
        if storedPipelineVersion != refreshPipelineVersion {
            defaults.set(refreshPipelineVersion, forKey: seedRefreshPipelineVersionKey)
            defaults.removeObject(forKey: seedRefreshLastStepKey)
            defaults.removeObject(forKey: seedRefreshLastErrorKey)
        }

        let lastStep = defaults.string(forKey: seedRefreshLastStepKey)
        let lastStepIndex = RefreshStep.allCases.firstIndex(where: { $0.rawValue == lastStep }) ?? -1
        let remainingSteps = RefreshStep.allCases.suffix(from: max(0, lastStepIndex + 1))

        if !remainingSteps.isEmpty {
            Self.logger.log("  ℹ️ Resuming refresh pipeline at step index \(lastStepIndex + 1, privacy: .public)")
        }

        for step in remainingSteps {
            let stepStart = Date()
            do {
                try runRefreshStep(step)
                let elapsed = Date().timeIntervalSince(stepStart)
                defaults.set(step.rawValue, forKey: seedRefreshLastStepKey)
                defaults.removeObject(forKey: seedRefreshLastErrorKey)
                defaults.set(Date().timeIntervalSince1970, forKey: seedRefreshLastRunAtKey)
                Self.logger.log("  ✅ Refresh step \(step.rawValue, privacy: .public) completed in \(elapsed, privacy: .public)s")
            } catch {
                defaults.set(step.rawValue, forKey: seedRefreshLastStepKey)
                defaults.set(error.localizedDescription, forKey: seedRefreshLastErrorKey)
                defaults.set(Date().timeIntervalSince1970, forKey: seedRefreshLastRunAtKey)
                Self.logger.error("  ❌ Refresh step \(step.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }

        defaults.removeObject(forKey: seedRefreshLastStepKey)
        defaults.removeObject(forKey: seedRefreshLastErrorKey)

        Self.logger.log("  ✅ Seed data refresh complete")
    }

    private static func runRefreshStep(_ step: RefreshStep) throws {
        switch step {
        case .disableLegacyFTSTriggers:
            try disableLegacySiteFTSTriggers()
        case .refreshRegionDescriptions:
            try refreshRegionDescriptions()
        case .refreshSpeciesCatalog:
            try refreshSpeciesCatalog()
        case .refreshSitesCatalog:
            try refreshSitesCatalog()
        case .refreshSiteDescriptions:
            try refreshSiteDescriptions()
        case .refreshSiteSearchIndex:
            try refreshSiteSearchIndex()
        }
    }

    private static func ensureEnrichedSeedData() throws {
        let db = AppDatabase.shared
        let speciesRepo = SpeciesRepository(database: db)

        let siteCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
        }
        let describedCount = try db.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM sites WHERE description IS NOT NULL AND description != ''"
            ) ?? 0
        }
        let speciesCount = try speciesRepo.count()
        let expectedSpeciesCount = loadSpeciesCatalogCount() ?? 0
        let speciesWithImages = try db.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM wildlife_species
                WHERE (thumbnail_url IS NOT NULL AND thumbnail_url != '')
                   OR (imageUrl IS NOT NULL AND imageUrl != '')
                """
            ) ?? 0
        }

        let needsSpecies = expectedSpeciesCount > 0 ? speciesCount < expectedSpeciesCount : speciesCount < 100
        let needsDescriptions = siteCount > 0 && describedCount == 0
        let needsImages = speciesCount > 0 && speciesWithImages < 100

        if needsSpecies || needsDescriptions || needsImages {
            Self.logger.log("  ⚠️ Enriched seed data missing (species=\(speciesCount, privacy: .public), describedSites=\(describedCount, privacy: .public), speciesWithImages=\(speciesWithImages, privacy: .public)); forcing refresh")
            try refreshSeedDataIfNeeded(force: true)
        }

        var refreshedSpeciesCount = try speciesRepo.count()
        if refreshedSpeciesCount < 100 {
            Self.logger.log("  ⚠️ Species catalog still missing after refresh (species=\(refreshedSpeciesCount, privacy: .public)); reloading catalog directly")
            do {
                try refreshSpeciesCatalog()
                refreshedSpeciesCount = try speciesRepo.count()
            } catch {
                Self.logger.error("  ❌ Species catalog refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let linksCount = try speciesRepo.countSiteLinks()
        let refreshedSiteCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
        }
        let expectedLinks = loadSiteSpeciesLinkCountFromCatalog() ?? 0
        let canSeedLinks = refreshedSpeciesCount > 0
            && refreshedSiteCount > 0
            && (expectedSpeciesCount == 0 || refreshedSpeciesCount >= expectedSpeciesCount)
        if canSeedLinks,
           (linksCount == 0 || (expectedLinks > 0 && linksCount < expectedLinks)) {
            try seedSiteSpeciesLinks()
        } else if !canSeedLinks {
            Self.logger.log("  ℹ️ Skipping site-species refresh (species=\(refreshedSpeciesCount, privacy: .public), expected=\(expectedSpeciesCount, privacy: .public))")
        }
    }

    private static func refreshRegionDescriptions() throws {
        let enrichments = loadRegionEnrichments()
        guard !enrichments.isEmpty else { return }

        let db = AppDatabase.shared
        try db.write { db in
            for enrichment in enrichments.values {
                guard enrichment.tagline != nil || enrichment.description != nil else { continue }
                try db.execute(
                    sql: """
                    UPDATE regions
                    SET tagline = ?, description = ?
                    WHERE id = ?
                    """,
                    arguments: [enrichment.tagline, enrichment.description, enrichment.id]
                )
            }
        }
    }

    private static func refreshSpeciesCatalog() throws {
        let catalog = try loadSpeciesCatalog()
        let descriptionLookup = loadSpeciesDescriptionLookup()
        let imageLookup = loadSpeciesImageLookup()
        let db = AppDatabase.shared

        try db.write { db in
            for speciesData in catalog.species {
                let description = descriptionLookup.description(
                    id: speciesData.id,
                    commonName: speciesData.name,
                    scientificName: speciesData.scientificName
                ) ?? speciesData.description
                let lookupUrl = imageLookup.url(for: speciesData.id)
                let (imageUrl, thumbnailUrl) = resolveSpeciesImageUrls(
                    imageUrl: speciesData.imageUrl,
                    thumbnailUrl: speciesData.thumbnailUrl,
                    lookupUrl: lookupUrl
                )
                let species = WildlifeSpecies(
                    id: speciesData.id,
                    name: speciesData.name,
                    scientificName: speciesData.scientificName,
                    category: WildlifeSpecies.Category(rawValue: speciesData.resolvedCategory) ?? .fish,
                    rarity: convertRarity(speciesData.resolvedRarity),
                    regions: speciesData.regions,
                    imageUrl: imageUrl,
                    familyId: speciesData.familyId,
                    conservationStatus: speciesData.conservationStatus,
                    description: description,
                    thumbnailUrl: thumbnailUrl,
                    wormsAphiaId: speciesData.wormsAphiaId,
                    gbifKey: speciesData.gbifKey,
                    fishbaseId: speciesData.fishbaseId
                )
                try species.save(db)
            }
        }
    }

    private static func refreshSitesCatalog() throws {
        guard let enrichedFile = optionalJSON("sites_enriched", as: EnrichedSitesSeedFile.self) else {
            return
        }

        let db = AppDatabase.shared
        try db.write { db in
            let existingSites = try DiveSite.fetchAll(db)
            var existingById: [String: DiveSite] = [:]
            existingById.reserveCapacity(existingSites.count)
            for site in existingSites {
                existingById[site.id] = site
            }

            for siteData in enrichedFile.sites {
                let updated = convertEnrichedSiteToModel(siteData)
                if let existing = existingById[updated.id] {
                    let merged = mergeExistingSite(existing, updated: updated)
                    try merged.save(db)
                } else {
                    try updated.insert(db)
                }
            }
        }
    }

    private static func refreshSiteDescriptions() throws {
        let enrichedLookup = loadEnrichedSiteDescriptions()
        let optimizedDescriptions = loadOptimizedSiteDescriptions()

        guard !enrichedLookup.isEmpty || !optimizedDescriptions.isEmpty else { return }

        let db = AppDatabase.shared
        try db.write { db in
            let sites = try DiveSite.fetchAll(db)
            for site in sites {
                let country = resolveCountry(from: site.location)
                let enrichedDescription = enrichedLookup.description(
                    siteId: site.id,
                    name: site.name,
                    country: country
                )

                if let enrichedDescription {
                    try db.execute(
                        sql: "UPDATE sites SET description = ? WHERE id = ?",
                        arguments: [enrichedDescription, site.id]
                    )
                    continue
                }

                if let fallback = optimizedDescriptions[site.id] {
                    try db.execute(
                        sql: """
                        UPDATE sites
                        SET description = ?
                        WHERE id = ? AND (description IS NULL OR description = '')
                        """,
                        arguments: [fallback, site.id]
                    )
                }
            }
        }
    }

    private static func disableLegacySiteFTSTriggers() throws {
        let db = AppDatabase.shared
        try db.write { db in
            try db.execute(sql: "DROP TRIGGER IF EXISTS __sites_fts_ai")
            try db.execute(sql: "DROP TRIGGER IF EXISTS __sites_fts_ad")
            try db.execute(sql: "DROP TRIGGER IF EXISTS __sites_fts_au")
        }
    }

    private static func refreshSiteSearchIndex() throws {
        // v9 migration adds incremental FTS triggers, so full rebuild is no longer needed
        // for normal operations. Only rebuild if FTS is out of sync (legacy upgrade path).
        let db = AppDatabase.shared

        let sitesCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
        }
        let ftsCount = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites_fts") ?? 0
        }

        // Only rebuild if counts don't match (indicates migration from pre-trigger version)
        guard ftsCount != sitesCount else {
            Self.logger.log("  ℹ️ FTS index in sync (\\(ftsCount, privacy: .public) entries), skipping rebuild")
            return
        }

        Self.logger.log("  🔄 FTS index out of sync (\\(ftsCount, privacy: .public) vs \\(sitesCount, privacy: .public)), rebuilding...")
        try db.write { db in
            try db.execute(sql: "INSERT INTO sites_fts(sites_fts) VALUES('rebuild')")
        }
        Self.logger.log("  ✅ FTS index rebuilt")
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

        let db = AppDatabase.shared
        let speciesRepo = SpeciesRepository(database: db)
        let validSpeciesIds = try db.read { db in
            Set(try String.fetchAll(db, sql: "SELECT id FROM wildlife_species"))
        }
        let validSiteIds = try db.read { db in
            Set(try String.fetchAll(db, sql: "SELECT id FROM sites"))
        }

        guard !validSpeciesIds.isEmpty, !validSiteIds.isEmpty else {
            Self.logger.log("  ℹ️ Skipping site-species links (missing species or sites)")
            return
        }

        if let catalogLinks = try loadSiteSpeciesLinksFromCatalog() {
            let filtered = catalogLinks.filter { validSpeciesIds.contains($0.speciesId) && validSiteIds.contains($0.siteId) }
            if filtered.count != catalogLinks.count {
                Self.logger.log("  ℹ️ Filtered \\(catalogLinks.count - filtered.count, privacy: .public) invalid catalog links")
            }
            guard !filtered.isEmpty else {
                Self.logger.log("  ℹ️ No valid catalog links to load")
                return
            }
            try speciesRepo.createSiteLinks(filtered)
            Self.logger.log("  ✅ Loaded \\(filtered.count, privacy: .public) site-species links (catalog)")
            return
        }

        guard let linksFile = optionalJSON("site_species", as: SiteSpeciesSeedFile.self) else {
            Self.logger.log("  ℹ️ No site_species.json found")
            return
        }

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

        let filtered = links.filter { validSpeciesIds.contains($0.speciesId) && validSiteIds.contains($0.siteId) }
        if filtered.count != links.count {
            Self.logger.log("  ℹ️ Filtered \\(links.count - filtered.count, privacy: .public) invalid site_species links")
        }
        guard !filtered.isEmpty else {
            Self.logger.log("  ℹ️ No valid site_species links to load")
            return
        }
        try speciesRepo.createSiteLinks(filtered)
        Self.logger.log("  ✅ Loaded \\(filtered.count, privacy: .public) site-species links")
    }

    private static func loadSiteSpeciesLinksFromCatalog() throws -> [SiteSpeciesLink]? {
        guard let catalog = optionalJSON("species_catalog_full", as: SpeciesCatalogFile.self) else {
            return nil
        }

        var links: [SiteSpeciesLink] = []
        links.reserveCapacity(5_000)
        var seen: Set<String> = []
        let lastUpdated = Date()

        for species in catalog.species {
            guard !species.sites.isEmpty else { continue }
            for site in species.sites {
                guard let siteId = normalizedValue(site.id) else { continue }
                let key = "\(siteId)|\(species.id)"
                if seen.contains(key) { continue }
                seen.insert(key)
                let likelihood = SiteSpeciesLink.Likelihood(rawValue: site.likelihood ?? "") ?? .occasional
                links.append(
                    SiteSpeciesLink(
                        siteId: siteId,
                        speciesId: species.id,
                        likelihood: likelihood,
                        seasonMonths: nil,
                        depthMinM: nil,
                        depthMaxM: nil,
                        source: "catalog_full",
                        sourceRecordCount: nil,
                        lastUpdated: lastUpdated
                    )
                )
            }
        }

        return links.isEmpty ? nil : links
    }

    private static func loadSiteSpeciesLinkCountFromCatalog() -> Int? {
        guard let catalog = optionalJSON("species_catalog_full", as: SpeciesCatalogFile.self) else {
            return nil
        }
        let count = catalog.species.reduce(0) { $0 + $1.sites.count }
        return count > 0 ? count : nil
    }
    
    // MARK: - Site Seeding
    
    private static func seedSites() throws {
        Self.logger.log("  📍 Loading dive sites...")

        if let enrichedFile = optionalJSON("sites_enriched", as: EnrichedSitesSeedFile.self) {
            let sites = enrichedFile.sites.map { convertEnrichedSiteToModel($0) }

            let db = AppDatabase.shared
            try db.siteRepository.createMany(sites)

            Self.logger.log("  ✅ Loaded \\(sites.count, privacy: .public) sites across \\(Set(sites.map { $0.region }).count, privacy: .public) regions (enriched)")
            return
        }
        
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
        let enrichedLookup = loadEnrichedSiteDescriptions()
        let optimizedDescriptions = loadOptimizedSiteDescriptions()
        let sites = unique.values.map { site in
            let enrichedDescription = enrichedLookup.description(
                siteId: site.id,
                name: site.name,
                country: site.country
            )
            let override = enrichedDescription ?? optimizedDescriptions[site.id]
            return convertToSite(site, descriptionOverride: override)
        }
        
        let db = AppDatabase.shared
        try db.siteRepository.createMany(sites)
        
        Self.logger.log("  ✅ Loaded \\(sites.count, privacy: .public) sites across \\(Set(sites.map { $0.region }).count, privacy: .public) regions")
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
        let enrichedLookup = loadEnrichedSiteDescriptions()
        let descriptionOverrides = loadOptimizedSiteDescriptions()
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
            let sites = tileFile.sites.map { site in
                let enrichedDescription = enrichedLookup.description(
                    siteId: site.id,
                    name: site.name,
                    country: site.country
                )
                let override = enrichedDescription ?? descriptionOverrides[site.id]
                return convertOptimizedSiteToModel(site, descriptionOverride: override)
            }
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
    private static func convertOptimizedSiteToModel(
        _ optimized: OptimizedSite,
        descriptionOverride: String? = nil
    ) -> DiveSite {
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
            description: preferredDescription(primary: optimized.description, fallback: descriptionOverride),
            wishlist: optimized.wishlist,
            visitedCount: optimized.visitedCount,
            createdAt: Date()
        )
    }
    
    private static func convertToSite(
        _ json: SiteSeedData,
        descriptionOverride: String? = nil
    ) -> DiveSite {
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
            difficulty: convertDifficulty(json.difficulty),
            type: convertSiteType(json.type),
            description: preferredDescription(primary: descriptionOverride, fallback: json.description),
            wishlist: json.wishlist,
            visitedCount: json.visitedCount,
            createdAt: Date()
        )
    }

    private static func convertEnrichedSiteToModel(_ json: EnrichedSiteSeedData) -> DiveSite {
        let area = json.area?.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = json.country?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts: [String] = [area, country].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        let location = parts.isEmpty ? json.region : parts.joined(separator: ", ")

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
            difficulty: convertDifficulty(json.difficulty),
            type: convertSiteType(json.type),
            description: normalizedDescription(json.description),
            wishlist: json.wishlist ?? false,
            visitedCount: json.visitedCount ?? 0,
            createdAt: Date()
        )
    }

    private static func mergeExistingSite(_ existing: DiveSite, updated: DiveSite) -> DiveSite {
        DiveSite(
            id: updated.id,
            name: updated.name,
            location: updated.location,
            latitude: updated.latitude,
            longitude: updated.longitude,
            region: updated.region,
            averageDepth: updated.averageDepth,
            maxDepth: updated.maxDepth,
            averageTemp: updated.averageTemp,
            averageVisibility: updated.averageVisibility,
            difficulty: updated.difficulty,
            type: updated.type,
            description: preferredDescription(primary: updated.description, fallback: existing.description),
            wishlist: existing.wishlist,
            isPlanned: existing.isPlanned,
            visitedCount: existing.visitedCount,
            tags: existing.tags,
            createdAt: existing.createdAt,
            countryId: existing.countryId,
            regionId: existing.regionId,
            areaId: existing.areaId,
            wikidataId: existing.wikidataId,
            osmId: existing.osmId
        )
    }

    private static func convertSiteType(_ typeString: String) -> DiveSite.SiteType {
        let normalized = typeString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "reef":
            return .reef
        case "wreck":
            return .wreck
        case "wall", "pinnacle", "seamount", "chimney", "bay", "cenote", "sinkhole":
            return .wall
        case "cave":
            return .cave
        case "shore":
            return .shore
        case "drift":
            return .drift
        default:
            return .reef
        }
    }

    private static func convertDifficulty(_ difficultyString: String) -> DiveSite.Difficulty {
        let normalized = difficultyString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "beginner", "easy":
            return .beginner
        case "advanced":
            return .advanced
        case "intermediate", "moderate":
            return .intermediate
        default:
            return DiveSite.Difficulty(rawValue: difficultyString) ?? .intermediate
        }
    }
    
    // MARK: - Species Seeding
    
    private static func seedSpecies() throws {
        Self.logger.log("  🐠 Loading wildlife species...")
        
        let catalog = try loadSpeciesCatalog()
        let descriptionLookup = loadSpeciesDescriptionLookup()
        let imageLookup = loadSpeciesImageLookup()
        
        let db = AppDatabase.shared

        var unique: [String: SpeciesSeedData] = [:]
        for speciesData in catalog.species where unique[speciesData.id] == nil {
            unique[speciesData.id] = speciesData
        }
        let speciesList = Array(unique.values)

        try db.write { db in
            for speciesData in speciesList {
                let description = descriptionLookup.description(
                    id: speciesData.id,
                    commonName: speciesData.name,
                    scientificName: speciesData.scientificName
                ) ?? speciesData.description
                let lookupUrl = imageLookup.url(for: speciesData.id)
                let (imageUrl, thumbnailUrl) = resolveSpeciesImageUrls(
                    imageUrl: speciesData.imageUrl,
                    thumbnailUrl: speciesData.thumbnailUrl,
                    lookupUrl: lookupUrl
                )
                let species = WildlifeSpecies(
                    id: speciesData.id,
                    name: speciesData.name,
                    scientificName: speciesData.scientificName,
                    category: WildlifeSpecies.Category(rawValue: speciesData.resolvedCategory) ?? .fish,
                    rarity: convertRarity(speciesData.resolvedRarity),
                    regions: speciesData.regions,
                    imageUrl: imageUrl,
                    familyId: speciesData.familyId,
                    conservationStatus: speciesData.conservationStatus,
                    description: description,
                    thumbnailUrl: thumbnailUrl,
                    wormsAphiaId: speciesData.wormsAphiaId,
                    gbifKey: speciesData.gbifKey,
                    fishbaseId: speciesData.fishbaseId
                )
                try species.save(db)
            }
        }
        
        Self.logger.log("  ✅ Loaded \\(speciesList.count, privacy: .public) wildlife species")
    }
    
    private static func convertRarity(_ rarityString: String) -> WildlifeSpecies.Rarity {
        switch rarityString.replacingOccurrences(of: " ", with: "") {
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

        let validSiteIds = try db.read { db in
            Set(try String.fetchAll(db, sql: "SELECT id FROM sites"))
        }
        guard !validSiteIds.isEmpty else {
            Self.logger.log("  ℹ️ Skipping dive logs (no sites present)")
            return
        }

        let validLogs = logsFile.dives.filter { validSiteIds.contains($0.siteId) }
        guard !validLogs.isEmpty else {
            Self.logger.log("  ℹ️ No valid dive logs to load")
            return
        }
        
        for logData in validLogs {
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
        
        Self.logger.log("  ✅ Loaded \\(validLogs.count, privacy: .public) dive logs")
    }
    
    // MARK: - Sighting Seeding
    
    private static func seedSightings() throws {
        Self.logger.log("  👁️ Loading wildlife sightings...")
        
        let sightingsFile = try loadJSON("sightings_mock", as: SightingsSeedFile.self)
        
        let db = AppDatabase.shared
        let dateFormatter = ISO8601DateFormatter()

        let validDiveIds = try db.read { db in
            Set(try String.fetchAll(db, sql: "SELECT id FROM dives"))
        }
        let validSpeciesIds = try db.read { db in
            Set(try String.fetchAll(db, sql: "SELECT id FROM wildlife_species"))
        }
        guard !validDiveIds.isEmpty, !validSpeciesIds.isEmpty else {
            Self.logger.log("  ℹ️ Skipping sightings (missing dives or species)")
            return
        }

        let validSightings = sightingsFile.sightings.filter {
            validDiveIds.contains($0.diveId) && validSpeciesIds.contains($0.speciesId)
        }
        guard !validSightings.isEmpty else {
            Self.logger.log("  ℹ️ No valid sightings to load")
            return
        }
        
        for sightingData in validSightings {
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
        
        Self.logger.log("  ✅ Loaded \\(validSightings.count, privacy: .public) wildlife sightings")
    }

    // MARK: - Site Media Seeding

    private static func seedSiteMedia() throws {
        Self.logger.log("  📷 Loading site media...")

        guard let mediaFile = optionalJSON("site_media", as: SiteMediaSeedFile.self) else {
            Self.logger.log("  ℹ️ No site_media.json found")
            return
        }

        let db = AppDatabase.shared
        let mediaRepo = SiteMediaRepository(database: db)
        let validSiteIds = try db.read { db in
            Set(try String.fetchAll(db, sql: "SELECT id FROM sites"))
        }

        guard !validSiteIds.isEmpty else {
            Self.logger.log("  ℹ️ Skipping site media (no sites present)")
            return
        }

        let media = mediaFile.media.map { data in
            SiteMedia(
                id: data.id,
                siteId: data.siteId,
                kind: SiteMedia.MediaKind(rawValue: data.kind) ?? .photo,
                url: data.url,
                width: data.width,
                height: data.height,
                license: data.license,
                attribution: data.attribution,
                sourceUrl: data.sourceUrl,
                sha256: data.sha256,
                isRedistributable: data.isRedistributable ?? true
            )
        }

        let filtered = media.filter { validSiteIds.contains($0.siteId) }
        if filtered.count != media.count {
            Self.logger.log("  ℹ️ Filtered \\(media.count - filtered.count, privacy: .public) invalid site media rows")
        }
        guard !filtered.isEmpty else {
            Self.logger.log("  ℹ️ No valid site media rows to load")
            return
        }

        try mediaRepo.upsertMany(filtered)
        Self.logger.log("  ✅ Loaded \\(filtered.count, privacy: .public) site media records")
    }

    // MARK: - Description Enrichment

    private static func preferredDescription(primary: String?, fallback: String?) -> String? {
        if let normalized = normalizedDescription(primary) {
            return normalized
        }
        return normalizedDescription(fallback)
    }

    private static func normalizedDescription(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func resolveSpeciesImageUrls(
        imageUrl: String?,
        thumbnailUrl: String?,
        lookupUrl: String?
    ) -> (String?, String?) {
        let normalizedImage = normalizedValue(imageUrl)
        let normalizedThumb = normalizedValue(thumbnailUrl)
        let normalizedLookup = normalizedValue(lookupUrl)

        let resolvedImage = normalizedImage ?? normalizedLookup ?? normalizedThumb
        let resolvedThumb = normalizedThumb ?? normalizedLookup ?? normalizedImage
        return (resolvedImage, resolvedThumb)
    }

    fileprivate static func normalizedSiteKey(name: String, country: String?) -> String {
        let base = [name, country].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !base.isEmpty else { return "" }
        return base
            .joined(separator: "|")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func resolveCountry(from location: String) -> String? {
        let parts = location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let last = parts.last, !last.isEmpty else { return nil }
        return String(last)
    }

    fileprivate static func inferSpeciesCategory(from name: String) -> String {
        let normalized = name.lowercased()
        let mammalKeywords = ["whale", "dolphin", "porpoise", "seal", "sea lion", "manatee", "dugong", "otter"]
        if mammalKeywords.contains(where: { normalized.contains($0) }) { return "Mammal" }

        let reptileKeywords = ["turtle", "sea snake", "crocodile", "alligator"]
        if reptileKeywords.contains(where: { normalized.contains($0) }) { return "Reptile" }

        let coralKeywords = ["coral", "anemone", "sea fan"]
        if coralKeywords.contains(where: { normalized.contains($0) }) { return "Coral" }

        let invertebrateKeywords = [
            "octopus", "squid", "cuttlefish", "nautilus", "jellyfish", "crab",
            "lobster", "shrimp", "prawn", "nudibranch", "starfish", "urchin", "sponge"
        ]
        if invertebrateKeywords.contains(where: { normalized.contains($0) }) { return "Invertebrate" }

        return "Fish"
    }

    private static func loadOptimizedSiteDescriptions() -> [String: String] {
        let possibleUrls: [URL?] = [
            Bundle.main.url(forResource: "cleaned_sites", withExtension: "json", subdirectory: "optimized"),
            Bundle.main.url(forResource: "cleaned_sites", withExtension: "json", subdirectory: "SeedData/optimized"),
            Bundle.main.url(forResource: "cleaned_sites", withExtension: "json", subdirectory: "Resources/SeedData/optimized")
        ]
        guard let url = possibleUrls.compactMap({ $0 }).first else { return [:] }

        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(OptimizedSiteDescriptionsFile.self, from: data)
            return file.sites.reduce(into: [:]) { acc, site in
                if let description = normalizedDescription(site.description) {
                    acc[site.id] = description
                }
            }
        } catch {
            return [:]
        }
    }

    private static func loadEnrichedSiteDescriptions() -> EnrichedSiteLookup {
        guard let file = optionalJSON("sites_enriched", as: EnrichedSitesSeedFile.self) else {
            return EnrichedSiteLookup(byId: [:], byNameCountry: [:], byNameOnly: [:])
        }

        var byId: [String: String] = [:]
        var byNameCountry: [String: String] = [:]
        var nameCounts: [String: Int] = [:]
        var nameDescriptions: [String: String] = [:]

        for site in file.sites {
            guard let description = normalizedDescription(site.description) else { continue }
            byId[site.id] = description

            let countryKey = normalizedSiteKey(name: site.name, country: site.country)
            if !countryKey.isEmpty {
                byNameCountry[countryKey] = description
            }

            let nameKey = normalizedSiteKey(name: site.name, country: nil)
            if !nameKey.isEmpty {
                nameCounts[nameKey, default: 0] += 1
                if nameDescriptions[nameKey] == nil {
                    nameDescriptions[nameKey] = description
                }
            }
        }

        var byNameOnly: [String: String] = [:]
        for (key, count) in nameCounts where count == 1 {
            if let description = nameDescriptions[key] {
                byNameOnly[key] = description
            }
        }

        return EnrichedSiteLookup(byId: byId, byNameCountry: byNameCountry, byNameOnly: byNameOnly)
    }

    private static func loadRegionEnrichments() -> [String: RegionEnrichment] {
        guard let file = optionalJSON("regions_enriched", as: RegionsEnrichedFile.self) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: file.regions.map { ($0.id, $0) })
    }

    private static func loadSpeciesCatalog() throws -> SpeciesCatalogFile {
        if let full = optionalJSON("species_catalog_full", as: SpeciesCatalogFile.self) {
            return full
        }
        if let v2 = optionalJSON("species_catalog_v2", as: SpeciesCatalogFile.self) {
            return v2
        }
        return try loadJSON("species_catalog", as: SpeciesCatalogFile.self)
    }

    private static func loadSpeciesCatalogCount() -> Int? {
        if let full = optionalJSON("species_catalog_full", as: SpeciesCatalogFile.self) {
            return full.species.count
        }
        if let v2 = optionalJSON("species_catalog_v2", as: SpeciesCatalogFile.self) {
            return v2.species.count
        }
        if let base = optionalJSON("species_catalog", as: SpeciesCatalogFile.self) {
            return base.species.count
        }
        return nil
    }

    private static func loadSpeciesDescriptionLookup() -> SpeciesDescriptionLookup {
        guard let file = optionalJSON("species_descriptions_enhanced", as: SpeciesDescriptionsFile.self) else {
            return SpeciesDescriptionLookup(byId: [:], byCommonName: [:], byScientificName: [:])
        }

        var byId: [String: String] = [:]
        var byCommonName: [String: String] = [:]
        var byScientificName: [String: String] = [:]

        for (id, entry) in file.species {
            guard let description = buildSpeciesDescription(from: entry) else { continue }
            byId[id] = description
            if let common = entry.commonName {
                byCommonName[normalizeName(common)] = description
            }
            if let scientific = entry.scientificName {
                byScientificName[normalizeName(scientific)] = description
            }
        }

        return SpeciesDescriptionLookup(
            byId: byId,
            byCommonName: byCommonName,
            byScientificName: byScientificName
        )
    }

    private static func loadSpeciesImageLookup() -> SpeciesImageLookup {
        let inat = optionalJSON("species_images_inaturalist", as: SpeciesImagesFile.self)
        let wiki = optionalJSON("species_images_wikimedia", as: SpeciesImagesFile.self)
        return SpeciesImageLookup(
            primary: buildSpeciesImageLookup(from: inat),
            fallback: buildSpeciesImageLookup(from: wiki)
        )
    }

    private static func buildSpeciesImageLookup(from file: SpeciesImagesFile?) -> [String: String] {
        guard let file else { return [:] }
        var lookup: [String: String] = [:]
        lookup.reserveCapacity(file.species.count)
        for (id, entry) in file.species {
            guard let photo = entry.photos?.first,
                  let url = normalizedValue(photo.url)
            else {
                continue
            }
            lookup[id] = url
        }
        return lookup
    }

    private static func buildSpeciesDescription(from entry: SpeciesDescriptionEntry) -> String? {
        guard let visual = entry.visualDescription else { return nil }
        var parts: [String] = []

        if let bodyShape = visual.bodyShape {
            parts.append(formatSentence(bodyShape))
        }

        if let primary = visual.colors?.primary {
            var colorLine = primary
            if let accents = visual.colors?.accents {
                colorLine += " " + accents
            }
            parts.append(formatSentence(colorLine))
        }

        if let pattern = visual.patterns?.first {
            parts.append(formatSentence(pattern))
        }

        if let features = visual.distinctiveFeatures, !features.isEmpty {
            let list = features.prefix(2).joined(separator: "; ")
            parts.append("Distinctive features include \(list).")
        }

        if let size = visual.sizeCm {
            parts.append("Typically reaches around \(size) cm.")
        }

        if parts.isEmpty, let prompt = visual.promptAdditions {
            parts.append(formatSentence(prompt))
        }

        let combined = parts.joined(separator: " ")
        return normalizedDescription(combined)
    }

    private static func formatSentence(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return trimmed.hasSuffix(".") ? trimmed : trimmed + "."
    }

    private static func normalizeName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    // MARK: - JSON Loading
    
    private static func loadJSON<T: Decodable>(_ filename: String, as type: T.Type) throws -> T {
        let bundles: [Bundle] = [Bundle.main, Bundle(for: AppDatabase.self)]

        for bundle in bundles {
            // Try multiple paths to find the JSON files
            let possiblePaths: [URL?] = [
                // Most common: files are at the bundle root
                bundle.url(forResource: filename, withExtension: "json"),
                // Subdirectories we may have configured
                bundle.url(forResource: filename, withExtension: "json", subdirectory: "SeedData"),
                bundle.url(forResource: filename, withExtension: "json", subdirectory: "Resources/SeedData"),
                bundle.url(forResource: "Resources/SeedData/\(filename)", withExtension: "json")
            ]

            if let url = possiblePaths.compactMap({ $0 }).first {
                Self.logger.log("  ✅ Found file at: \\(url.lastPathComponent, privacy: .public)")
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            }
        }

        // Print available resources for debugging
        if let resourcePath = Bundle.main.resourcePath {
            Self.logger.error("  📂 Bundle resource path: \(resourcePath, privacy: .public)")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                Self.logger.error("  📂 Available resources sample: \(String(describing: contents.prefix(50)), privacy: .public)")
            }
        }
        throw SeedError.fileNotFound(filename)
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

private struct EnrichedSitesSeedFile: Decodable {
    let sites: [EnrichedSiteSeedData]
}

private struct EnrichedSiteSeedData: Decodable {
    let id: String
    let name: String
    let region: String
    let area: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let averageDepth: Double
    let maxDepth: Double
    let averageTemp: Double
    let averageVisibility: Double
    let difficulty: String
    let type: String
    let description: String?
    let wishlist: Bool?
    let visitedCount: Int?
}

private struct EnrichedSiteLookup {
    let byId: [String: String]
    let byNameCountry: [String: String]
    let byNameOnly: [String: String]

    var isEmpty: Bool {
        byId.isEmpty && byNameCountry.isEmpty && byNameOnly.isEmpty
    }

    func description(siteId: String, name: String, country: String?) -> String? {
        if let direct = byId[siteId] {
            return direct
        }
        let key = DatabaseSeeder.normalizedSiteKey(name: name, country: country)
        if !key.isEmpty, let description = byNameCountry[key] {
            return description
        }
        let nameKey = DatabaseSeeder.normalizedSiteKey(name: name, country: nil)
        guard !nameKey.isEmpty else { return nil }
        return byNameOnly[nameKey]
    }
}

private struct OptimizedSiteDescriptionsFile: Decodable {
    let sites: [OptimizedSiteDescription]
}

private struct OptimizedSiteDescription: Decodable {
    let id: String
    let description: String?
}

private struct RegionsEnrichedFile: Decodable {
    let regions: [RegionEnrichment]
}

private struct RegionEnrichment: Decodable {
    let id: String
    let tagline: String?
    let description: String?
}

private struct SpeciesDescriptionsFile: Decodable {
    let species: [String: SpeciesDescriptionEntry]
}

private struct SpeciesImagesFile: Decodable {
    let species: [String: SpeciesImageEntry]
}

private struct SpeciesImageEntry: Decodable {
    let speciesId: String?
    let photos: [SpeciesImagePhoto]?

    private enum CodingKeys: String, CodingKey {
        case speciesId = "species_id"
        case photos
    }
}

private struct SpeciesImagePhoto: Decodable {
    let url: String?
}

private struct SpeciesDescriptionEntry: Decodable {
    let commonName: String?
    let scientificName: String?
    let visualDescription: SpeciesVisualDescription?

    private enum CodingKeys: String, CodingKey {
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case visualDescription = "visual_description"
    }
}

private struct SpeciesVisualDescription: Decodable {
    let colors: SpeciesColorDescription?
    let patterns: [String]?
    let distinctiveFeatures: [String]?
    let sizeCm: Int?
    let bodyShape: String?
    let promptAdditions: String?

    private enum CodingKeys: String, CodingKey {
        case colors
        case patterns
        case distinctiveFeatures = "distinctive_features"
        case sizeCm = "size_cm"
        case bodyShape = "body_shape"
        case promptAdditions = "prompt_additions"
    }
}

private struct SpeciesColorDescription: Decodable {
    let primary: String?
    let secondary: String?
    let accents: String?
}

private struct SpeciesDescriptionLookup {
    let byId: [String: String]
    let byCommonName: [String: String]
    let byScientificName: [String: String]

    func description(id: String, commonName: String, scientificName: String) -> String? {
        if let description = byId[id] {
            return description
        }

        let normalizedCommon = normalizeKey(commonName)
        if !normalizedCommon.isEmpty, let description = byCommonName[normalizedCommon] {
            return description
        }

        let normalizedScientific = normalizeKey(scientificName)
        if !normalizedScientific.isEmpty, let description = byScientificName[normalizedScientific] {
            return description
        }

        return nil
    }

    private func normalizeKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct SpeciesImageLookup {
    let primary: [String: String]
    let fallback: [String: String]

    func url(for id: String) -> String? {
        primary[id] ?? fallback[id]
    }
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
    let category: String?
    let rarity: String?
    let regions: [String]
    let sites: [SpeciesSiteSeedData]
    let imageUrl: String?
    let familyId: String?
    let conservationStatus: String?
    let description: String?
    let thumbnailUrl: String?
    let wormsAphiaId: Int?
    let gbifKey: Int?
    let fishbaseId: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, scientificName, category, rarity, regions, sites, imageUrl
        case familyId = "family_id"
        case conservationStatus = "conservation_status"
        case description
        case thumbnailUrl = "thumbnail_url"
        case wormsAphiaId = "worms_aphia_id"
        case gbifKey = "gbif_key"
        case fishbaseId = "fishbase_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        scientificName = try container.decodeIfPresent(String.self, forKey: .scientificName) ?? name
        category = try container.decodeIfPresent(String.self, forKey: .category)
        rarity = try container.decodeIfPresent(String.self, forKey: .rarity)
        regions = try container.decodeIfPresent([String].self, forKey: .regions) ?? []
        sites = try container.decodeIfPresent([SpeciesSiteSeedData].self, forKey: .sites) ?? []
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        familyId = try container.decodeIfPresent(String.self, forKey: .familyId)
        conservationStatus = try container.decodeIfPresent(String.self, forKey: .conservationStatus)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        wormsAphiaId = try container.decodeIfPresent(Int.self, forKey: .wormsAphiaId)
        gbifKey = try container.decodeIfPresent(Int.self, forKey: .gbifKey)
        fishbaseId = try container.decodeIfPresent(Int.self, forKey: .fishbaseId)
    }

    var resolvedCategory: String {
        if let category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return category
        }
        return DatabaseSeeder.inferSpeciesCategory(from: name)
    }

    var resolvedRarity: String {
        rarity?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? rarity! : "Common"
    }
}

private struct SpeciesSiteSeedData: Decodable {
    let id: String
    let name: String?
    let regionId: String?
    let likelihood: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, likelihood
        case regionId = "region_id"
    }
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

// MARK: - Site Media Seed Structures

private struct SiteMediaSeedFile: Decodable {
    let media: [SiteMediaSeedData]
}

private struct SiteMediaSeedData: Decodable {
    let id: String
    let siteId: String
    let kind: String
    let url: String
    let width: Int?
    let height: Int?
    let license: String?
    let attribution: String?
    let sourceUrl: String?
    let sha256: String?
    let isRedistributable: Bool?
}
