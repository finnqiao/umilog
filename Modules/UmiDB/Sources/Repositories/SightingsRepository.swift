import Foundation
import GRDB

public final class SightingsRepository {
    private let database: AppDatabase
    
    public init(database: AppDatabase) { self.database = database }
    
    public func fetchAll() throws -> [WildlifeSighting] {
        try database.read { db in
            try WildlifeSighting.fetchAll(db)
        }
    }
    
    public func fetchByDive(_ diveId: String) throws -> [WildlifeSighting] {
        try database.read { db in
            try WildlifeSighting
                .filter(WildlifeSighting.Columns.diveId == diveId)
                .fetchAll(db)
        }
    }
    
    public func create(_ sighting: WildlifeSighting) throws {
        try database.write { db in
            try sighting.insert(db)
        }
    }

    public func fetchDetailedByDive(_ diveId: String) throws -> [DiveSightingDetail] {
        try database.read { db in
            let sightings = try WildlifeSighting
                .filter(WildlifeSighting.Columns.diveId == diveId)
                .order(WildlifeSighting.Columns.createdAt.asc)
                .fetchAll(db)

            guard !sightings.isEmpty else { return [] }

            let speciesIds = Array(Set(sightings.map(\.speciesId)))
            let species = try WildlifeSpecies.fetchAll(db, keys: speciesIds)
            let speciesMap = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })

            let sightingIds = sightings.map(\.id)
            let photos = try SightingPhoto
                .filter(sightingIds.contains(SightingPhoto.Columns.sightingId))
                .order(SightingPhoto.Columns.sortOrder.asc)
                .order(SightingPhoto.Columns.createdAt.asc)
                .fetchAll(db)
            let photosBySighting = Dictionary(grouping: photos, by: \.sightingId)

            return sightings.map { sighting in
                let species = speciesMap[sighting.speciesId]
                return DiveSightingDetail(
                    sighting: sighting,
                    speciesName: species?.name ?? sighting.speciesId,
                    speciesScientificName: species?.scientificName,
                    photos: photosBySighting[sighting.id] ?? []
                )
            }
        }
    }
    
    public func getUniqueSpeciesCount() throws -> Int {
        try database.read { db in
            let count = try WildlifeSighting
                .select(WildlifeSighting.Columns.speciesId)
                .distinct()
                .fetchCount(db)
            return count
        }
    }
}

public struct DiveSightingDetail: Identifiable {
    public let sighting: WildlifeSighting
    public let speciesName: String
    public let speciesScientificName: String?
    public let photos: [SightingPhoto]

    public var id: String { sighting.id }

    public init(
        sighting: WildlifeSighting,
        speciesName: String,
        speciesScientificName: String?,
        photos: [SightingPhoto]
    ) {
        self.sighting = sighting
        self.speciesName = speciesName
        self.speciesScientificName = speciesScientificName
        self.photos = photos
    }
}
