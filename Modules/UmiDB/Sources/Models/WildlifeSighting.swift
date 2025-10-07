import Foundation
import GRDB

/// Wildlife sighting during a dive
public struct WildlifeSighting: Codable, Identifiable {
    public let id: String
    public let diveId: String
    public let speciesId: String
    public let count: Int
    public let notes: String?
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        diveId: String,
        speciesId: String,
        count: Int = 1,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.diveId = diveId
        self.speciesId = speciesId
        self.count = count
        self.notes = notes
        self.createdAt = createdAt
    }
}

// MARK: - GRDB
extension WildlifeSighting: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "sightings"
    
    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let diveId = Column(CodingKeys.diveId)
        static let speciesId = Column(CodingKeys.speciesId)
        static let count = Column(CodingKeys.count)
        static let notes = Column(CodingKeys.notes)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}

// MARK: - Associations
extension WildlifeSighting {
    public static let dive = belongsTo(DiveLog.self)
    public static let species = belongsTo(WildlifeSpecies.self)
}

/// Wildlife species catalog
public struct WildlifeSpecies: Codable, Identifiable {
    public let id: String
    public let name: String
    public let scientificName: String
    public let category: Category
    public let rarity: Rarity
    public let regions: [String]
    public let imageUrl: String?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        scientificName: String,
        category: Category,
        rarity: Rarity,
        regions: [String],
        imageUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.category = category
        self.rarity = rarity
        self.regions = regions
        self.imageUrl = imageUrl
    }
    
    public enum Category: String, Codable {
        case fish = "Fish"
        case coral = "Coral"
        case mammal = "Mammal"
        case invertebrate = "Invertebrate"
        case reptile = "Reptile"
    }
    
    public enum Rarity: String, Codable {
        case common = "Common"
        case uncommon = "Uncommon"
        case rare = "Rare"
        case veryRare = "Very Rare"
    }
}

// MARK: - GRDB
extension WildlifeSpecies: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "wildlife_species"
    
    enum CodingKeys: String, CodingKey {
        case id, name, scientificName, category, rarity, regions, imageUrl
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(scientificName, forKey: .scientificName)
        try container.encode(category, forKey: .category)
        try container.encode(rarity, forKey: .rarity)
        try container.encode(regions.joined(separator: ","), forKey: .regions)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        scientificName = try container.decode(String.self, forKey: .scientificName)
        category = try container.decode(Category.self, forKey: .category)
        rarity = try container.decode(Rarity.self, forKey: .rarity)
        let regionsString = try container.decode(String.self, forKey: .regions)
        regions = regionsString.split(separator: ",").map(String.init)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
    }
}
