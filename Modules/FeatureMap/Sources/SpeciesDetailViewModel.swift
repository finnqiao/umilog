import Foundation
import Combine
import UmiDB
import GRDB
import UmiCoreKit
import os

@MainActor
public final class SpeciesDetailViewModel: ObservableObject {
    // Species data
    let species: WildlifeSpecies

    // Loaded data
    @Published var referenceImages: [String] = []
    @Published var sightings: [SpeciesSightingInfo] = []
    @Published var habitats: [SpeciesHabitatInfo] = []
    @Published var sightingCount: Int = 0

    // State
    @Published var isLoading = false
    @Published var error: String?

    // Dependencies
    private let database = AppDatabase.shared
    private let speciesRepository: SpeciesRepository
    private let siteRepository: SiteRepository

    public init(species: WildlifeSpecies) {
        self.species = species
        self.speciesRepository = SpeciesRepository(database: database)
        self.siteRepository = SiteRepository(database: database)

        // Load reference images synchronously (just checking bundle assets)
        self.referenceImages = SpeciesAssets.referenceImages(for: species.id)
    }

    public func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Load sighting history
        await loadSightings()

        // Load habitats (sites where this species can be found)
        await loadHabitats()
    }

    private func loadSightings() async {
        do {
            let sightingsData = try database.read { db in
                // Get all sightings for this species with dive and site info
                let sql = """
                SELECT
                    s.id,
                    s.count,
                    d.startTime,
                    COALESCE(site.name, 'Unknown Site') as siteName
                FROM sightings s
                INNER JOIN dives d ON s.diveId = d.id
                LEFT JOIN sites site ON d.siteId = site.id
                WHERE s.speciesId = ?
                ORDER BY d.startTime DESC
                """

                return try Row.fetchAll(db, sql: sql, arguments: [species.id])
            }

            var infos: [SpeciesSightingInfo] = []
            var totalCount = 0

            for row in sightingsData {
                let id = row["id"] as? String ?? UUID().uuidString
                let count = row["count"] as? Int ?? 1
                let startTime = row["startTime"] as? Date ?? Date()
                let siteName = row["siteName"] as? String ?? "Unknown Site"

                infos.append(SpeciesSightingInfo(
                    id: id,
                    siteName: siteName,
                    date: startTime,
                    count: count
                ))

                totalCount += count
            }

            self.sightings = infos
            self.sightingCount = totalCount

        } catch {
            Log.wildlife.error("Error loading sightings: \(error.localizedDescription)")
            self.sightings = []
            self.sightingCount = 0
        }
    }

    private func loadHabitats() async {
        do {
            let habitatData = try database.read { db in
                let sql = """
                SELECT
                    ss.id,
                    ss.site_id as siteId,
                    ss.likelihood,
                    site.name as siteName,
                    site.location as siteLocation
                FROM site_species ss
                INNER JOIN sites site ON ss.site_id = site.id
                WHERE ss.species_id = ?
                ORDER BY
                    CASE ss.likelihood
                        WHEN 'common' THEN 1
                        WHEN 'occasional' THEN 2
                        ELSE 3
                    END,
                    site.name
                """

                return try Row.fetchAll(db, sql: sql, arguments: [species.id])
            }

            self.habitats = habitatData.compactMap { row in
                guard let id = row["id"] as? String,
                      let siteId = row["siteId"] as? String,
                      let likelihoodStr = row["likelihood"] as? String,
                      let likelihood = SiteSpeciesLink.Likelihood(rawValue: likelihoodStr),
                      let siteName = row["siteName"] as? String,
                      let siteLocation = row["siteLocation"] as? String else {
                    return nil
                }

                return SpeciesHabitatInfo(
                    id: id,
                    siteId: siteId,
                    siteName: siteName,
                    siteLocation: siteLocation,
                    likelihood: likelihood
                )
            }

        } catch {
            Log.wildlife.error("Error loading habitats: \(error.localizedDescription)")
            self.habitats = []
        }
    }
}
