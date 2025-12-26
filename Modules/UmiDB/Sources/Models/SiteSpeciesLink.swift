import Foundation
import GRDB

/// Junction table linking dive sites to species with likelihood and metadata
public struct SiteSpeciesLink: Codable, Hashable {
    public let siteId: String
    public let speciesId: String
    public let likelihood: Likelihood
    public let seasonMonths: [String]?
    public let depthMinM: Int?
    public let depthMaxM: Int?
    public let source: String?
    public let sourceRecordCount: Int?
    public let lastUpdated: Date

    public init(
        siteId: String,
        speciesId: String,
        likelihood: Likelihood = .occasional,
        seasonMonths: [String]? = nil,
        depthMinM: Int? = nil,
        depthMaxM: Int? = nil,
        source: String? = nil,
        sourceRecordCount: Int? = nil,
        lastUpdated: Date = Date()
    ) {
        self.siteId = siteId
        self.speciesId = speciesId
        self.likelihood = likelihood
        self.seasonMonths = seasonMonths
        self.depthMinM = depthMinM
        self.depthMaxM = depthMaxM
        self.source = source
        self.sourceRecordCount = sourceRecordCount
        self.lastUpdated = lastUpdated
    }

    public enum Likelihood: String, Codable, CaseIterable {
        case common = "common"
        case occasional = "occasional"
        case rare = "rare"

        public var displayName: String {
            switch self {
            case .common: return "Common"
            case .occasional: return "Occasional"
            case .rare: return "Rare"
            }
        }
    }
}

// MARK: - GRDB
extension SiteSpeciesLink: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "site_species"

    public enum Columns {
        static let siteId = Column(CodingKeys.siteId)
        static let speciesId = Column(CodingKeys.speciesId)
        static let likelihood = Column(CodingKeys.likelihood)
        static let seasonMonths = Column(CodingKeys.seasonMonths)
        static let depthMinM = Column(CodingKeys.depthMinM)
        static let depthMaxM = Column(CodingKeys.depthMaxM)
        static let source = Column(CodingKeys.source)
        static let sourceRecordCount = Column(CodingKeys.sourceRecordCount)
        static let lastUpdated = Column(CodingKeys.lastUpdated)
    }

    enum CodingKeys: String, CodingKey {
        case siteId = "site_id"
        case speciesId = "species_id"
        case likelihood
        case seasonMonths = "season_months"
        case depthMinM = "depth_min_m"
        case depthMaxM = "depth_max_m"
        case source
        case sourceRecordCount = "source_record_count"
        case lastUpdated = "last_updated"
    }

    // Custom encoding/decoding for seasonMonths JSON array
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(siteId, forKey: .siteId)
        try container.encode(speciesId, forKey: .speciesId)
        try container.encode(likelihood, forKey: .likelihood)
        if let months = seasonMonths {
            let json = try JSONEncoder().encode(months)
            try container.encode(String(data: json, encoding: .utf8), forKey: .seasonMonths)
        }
        try container.encodeIfPresent(depthMinM, forKey: .depthMinM)
        try container.encodeIfPresent(depthMaxM, forKey: .depthMaxM)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(sourceRecordCount, forKey: .sourceRecordCount)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        siteId = try container.decode(String.self, forKey: .siteId)
        speciesId = try container.decode(String.self, forKey: .speciesId)
        likelihood = try container.decode(Likelihood.self, forKey: .likelihood)
        if let monthsJson = try container.decodeIfPresent(String.self, forKey: .seasonMonths),
           let data = monthsJson.data(using: .utf8) {
            seasonMonths = try? JSONDecoder().decode([String].self, from: data)
        } else {
            seasonMonths = nil
        }
        depthMinM = try container.decodeIfPresent(Int.self, forKey: .depthMinM)
        depthMaxM = try container.decodeIfPresent(Int.self, forKey: .depthMaxM)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        sourceRecordCount = try container.decodeIfPresent(Int.self, forKey: .sourceRecordCount)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }
}

// MARK: - Associations
extension SiteSpeciesLink {
    public static let site = belongsTo(DiveSite.self)
    public static let species = belongsTo(WildlifeSpecies.self)
}
