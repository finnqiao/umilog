import Foundation
import GRDB

/// Species family for simplified taxonomy (Category -> Family -> Species)
public struct SpeciesFamily: Codable, Identifiable, Hashable {
    public let id: String                    // e.g., "carcharhinidae"
    public let name: String                  // "Requiem Sharks"
    public let scientificName: String        // "Carcharhinidae"
    public let category: WildlifeSpecies.Category
    public let wormsAphiaId: Int?
    public let gbifKey: Int?

    public init(
        id: String,
        name: String,
        scientificName: String,
        category: WildlifeSpecies.Category,
        wormsAphiaId: Int? = nil,
        gbifKey: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.category = category
        self.wormsAphiaId = wormsAphiaId
        self.gbifKey = gbifKey
    }
}

// MARK: - GRDB
extension SpeciesFamily: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "species_families"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let scientificName = Column(CodingKeys.scientificName)
        static let category = Column(CodingKeys.category)
        static let wormsAphiaId = Column(CodingKeys.wormsAphiaId)
        static let gbifKey = Column(CodingKeys.gbifKey)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case scientificName = "scientific_name"
        case category
        case wormsAphiaId = "worms_aphia_id"
        case gbifKey = "gbif_key"
    }
}

// MARK: - Associations
extension SpeciesFamily {
    public static let species = hasMany(WildlifeSpecies.self)
}
