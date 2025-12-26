import Foundation
import GRDB
import CoreLocation

/// Diving region (e.g., "Red Sea", "Coral Triangle")
public struct Region: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
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
        countryId: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        wikidataId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.countryId = countryId
        self.latitude = latitude
        self.longitude = longitude
        self.wikidataId = wikidataId
    }
}

// MARK: - GRDB
extension Region: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "regions"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let countryId = Column(CodingKeys.countryId)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
        static let wikidataId = Column(CodingKeys.wikidataId)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case countryId = "country_id"
        case latitude
        case longitude
        case wikidataId = "wikidata_id"
    }
}

// MARK: - Associations
extension Region {
    public static let country = belongsTo(Country.self)
    public static let areas = hasMany(Area.self)
    public static let sites = hasMany(DiveSite.self)
}
