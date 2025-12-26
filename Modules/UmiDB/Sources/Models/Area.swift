import Foundation
import GRDB
import CoreLocation

/// Diving area within a region (e.g., "Dahab", "Koh Tao")
public struct Area: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let regionId: String?
    public let countryId: String?
    public let latitude: Double?
    public let longitude: Double?
    public let wikidataId: String?

    /// Computed property for MapKit compatibility
    public var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public init(
        id: String,
        name: String,
        regionId: String? = nil,
        countryId: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        wikidataId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.regionId = regionId
        self.countryId = countryId
        self.latitude = latitude
        self.longitude = longitude
        self.wikidataId = wikidataId
    }
}

// MARK: - GRDB
extension Area: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "areas"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let regionId = Column(CodingKeys.regionId)
        static let countryId = Column(CodingKeys.countryId)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
        static let wikidataId = Column(CodingKeys.wikidataId)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case regionId = "region_id"
        case countryId = "country_id"
        case latitude
        case longitude
        case wikidataId = "wikidata_id"
    }
}

// MARK: - Associations
extension Area {
    public static let region = belongsTo(Region.self)
    public static let country = belongsTo(Country.self)
    public static let sites = hasMany(DiveSite.self)
}
