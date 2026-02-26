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
    public static let photos = hasMany(SightingPhoto.self)
}

/// Wildlife species catalog
public struct WildlifeSpecies: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let scientificName: String
    public let category: Category
    public let rarity: Rarity
    public let regions: [String]
    public let imageUrl: String?
    // v5: Taxonomy and external IDs
    public let familyId: String?
    public let conservationStatus: String?  // IUCN: LC, VU, EN, CR
    public let description: String?
    public let thumbnailUrl: String?
    public let wormsAphiaId: Int?
    public let gbifKey: Int?
    public let fishbaseId: Int?

    public init(
        id: String = UUID().uuidString,
        name: String,
        scientificName: String,
        category: Category,
        rarity: Rarity,
        regions: [String],
        imageUrl: String? = nil,
        familyId: String? = nil,
        conservationStatus: String? = nil,
        description: String? = nil,
        thumbnailUrl: String? = nil,
        wormsAphiaId: Int? = nil,
        gbifKey: Int? = nil,
        fishbaseId: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.category = category
        self.rarity = rarity
        self.regions = regions
        self.imageUrl = imageUrl
        self.familyId = familyId
        self.conservationStatus = conservationStatus
        self.description = description
        self.thumbnailUrl = thumbnailUrl
        self.wormsAphiaId = wormsAphiaId
        self.gbifKey = gbifKey
        self.fishbaseId = fishbaseId
    }

    public enum Category: String, Codable, CaseIterable {
        case fish = "Fish"
        case coral = "Coral"
        case mammal = "Mammal"
        case invertebrate = "Invertebrate"
        case reptile = "Reptile"
    }

    public enum Rarity: String, Codable, CaseIterable {
        case common = "Common"
        case uncommon = "Uncommon"
        case rare = "Rare"
        case veryRare = "Very Rare"
    }
}

// MARK: - GRDB
extension WildlifeSpecies: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "wildlife_species"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let scientificName = Column(CodingKeys.scientificName)
        static let category = Column(CodingKeys.category)
        static let rarity = Column(CodingKeys.rarity)
        static let regions = Column(CodingKeys.regions)
        static let imageUrl = Column(CodingKeys.imageUrl)
        static let familyId = Column(CodingKeys.familyId)
        static let conservationStatus = Column(CodingKeys.conservationStatus)
        static let description = Column(CodingKeys.description)
        static let thumbnailUrl = Column(CodingKeys.thumbnailUrl)
        static let wormsAphiaId = Column(CodingKeys.wormsAphiaId)
        static let gbifKey = Column(CodingKeys.gbifKey)
        static let fishbaseId = Column(CodingKeys.fishbaseId)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, scientificName, category, rarity, regions, imageUrl
        case familyId = "family_id"
        case conservationStatus = "conservation_status"
        case description
        case thumbnailUrl = "thumbnail_url"
        case wormsAphiaId = "worms_aphia_id"
        case gbifKey = "gbif_key"
        case fishbaseId = "fishbase_id"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[CodingKeys.id.rawValue] = id
        container[CodingKeys.name.rawValue] = name
        container[CodingKeys.scientificName.rawValue] = scientificName
        container[CodingKeys.category.rawValue] = category.rawValue
        container[CodingKeys.rarity.rawValue] = rarity.rawValue
        container[CodingKeys.regions.rawValue] = regions.joined(separator: ",")
        container[CodingKeys.imageUrl.rawValue] = imageUrl
        container[CodingKeys.familyId.rawValue] = familyId
        container[CodingKeys.conservationStatus.rawValue] = conservationStatus
        container[CodingKeys.description.rawValue] = description
        container[CodingKeys.thumbnailUrl.rawValue] = thumbnailUrl
        container[CodingKeys.wormsAphiaId.rawValue] = wormsAphiaId
        container[CodingKeys.gbifKey.rawValue] = gbifKey
        container[CodingKeys.fishbaseId.rawValue] = fishbaseId
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
        try container.encodeIfPresent(familyId, forKey: .familyId)
        try container.encodeIfPresent(conservationStatus, forKey: .conservationStatus)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(wormsAphiaId, forKey: .wormsAphiaId)
        try container.encodeIfPresent(gbifKey, forKey: .gbifKey)
        try container.encodeIfPresent(fishbaseId, forKey: .fishbaseId)
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
        familyId = try container.decodeIfPresent(String.self, forKey: .familyId)
        conservationStatus = try container.decodeIfPresent(String.self, forKey: .conservationStatus)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        wormsAphiaId = try container.decodeIfPresent(Int.self, forKey: .wormsAphiaId)
        gbifKey = try container.decodeIfPresent(Int.self, forKey: .gbifKey)
        fishbaseId = try container.decodeIfPresent(Int.self, forKey: .fishbaseId)
    }
}

// MARK: - Associations
extension WildlifeSpecies {
    public static let family = belongsTo(SpeciesFamily.self)
    public static let siteLinks = hasMany(SiteSpeciesLink.self)
}
