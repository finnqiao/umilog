import Foundation
import GRDB

/// Country with dive sites (ISO 3166-1 alpha-2 codes)
public struct Country: Codable, Identifiable, Hashable {
    public let id: String        // ISO code: "EG", "TH", "JP"
    public let name: String
    public let nameLocal: String?
    public let continent: String
    public let wikidataId: String?

    public init(
        id: String,
        name: String,
        nameLocal: String? = nil,
        continent: String,
        wikidataId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameLocal = nameLocal
        self.continent = continent
        self.wikidataId = wikidataId
    }
}

// MARK: - GRDB
extension Country: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "countries"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let nameLocal = Column(CodingKeys.nameLocal)
        static let continent = Column(CodingKeys.continent)
        static let wikidataId = Column(CodingKeys.wikidataId)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameLocal = "name_local"
        case continent
        case wikidataId = "wikidata_id"
    }
}

// MARK: - Associations
extension Country {
    public static let regions = hasMany(Region.self)
    public static let areas = hasMany(Area.self)
    public static let sites = hasMany(DiveSite.self)
}
