import Foundation
import GRDB
import CoreLocation

public struct DiveShop: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let country: String?
    public let region: String?
    public let area: String?
    public let latitude: Double?
    public let longitude: Double?
    public let website: String?
    public let phone: String?
    public let email: String?
    public let services: [String]
    public let license: String?
    public let sourceUrl: String?
    
    public init(
        id: String,
        name: String,
        country: String? = nil,
        region: String? = nil,
        area: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        website: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        services: [String] = [],
        license: String? = nil,
        sourceUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.region = region
        self.area = area
        self.latitude = latitude
        self.longitude = longitude
        self.website = website
        self.phone = phone
        self.email = email
        self.services = services
        self.license = license
        self.sourceUrl = sourceUrl
    }
    
    public var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case country
        case region
        case area
        case latitude
        case longitude
        case website
        case phone
        case email
        case services
        case license
        case sourceUrl = "source_url"
    }
}

extension DiveShop: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "dive_shops"
    
    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let name = Column(CodingKeys.name)
        public static let country = Column(CodingKeys.country)
        public static let region = Column(CodingKeys.region)
        public static let area = Column(CodingKeys.area)
        public static let latitude = Column(CodingKeys.latitude)
        public static let longitude = Column(CodingKeys.longitude)
        public static let website = Column(CodingKeys.website)
        public static let phone = Column(CodingKeys.phone)
        public static let email = Column(CodingKeys.email)
        public static let services = Column(CodingKeys.services)
        public static let license = Column(CodingKeys.license)
        public static let sourceUrl = Column(CodingKeys.sourceUrl)
    }
    
    public init(row: Row) {
        self.id = row[Columns.id]
        self.name = row[Columns.name]
        self.country = row[Columns.country]
        self.region = row[Columns.region]
        self.area = row[Columns.area]
        self.latitude = row[Columns.latitude]
        self.longitude = row[Columns.longitude]
        self.website = row[Columns.website]
        self.phone = row[Columns.phone]
        self.email = row[Columns.email]
        self.license = row[Columns.license]
        self.sourceUrl = row[Columns.sourceUrl]
        
        let servicesString: String? = row[Columns.services]
        self.services = Self.decodeServices(servicesString)
    }
    
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.country] = country
        container[Columns.region] = region
        container[Columns.area] = area
        container[Columns.latitude] = latitude
        container[Columns.longitude] = longitude
        container[Columns.website] = website
        container[Columns.phone] = phone
        container[Columns.email] = email
        container[Columns.services] = Self.encodeServices(services)
        container[Columns.license] = license
        container[Columns.sourceUrl] = sourceUrl
    }
    
    private static func decodeServices(_ value: String?) -> [String] {
        guard
            let value,
            let data = value.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return decoded
    }
    
    private static func encodeServices(_ services: [String]) -> String {
        guard
            let data = try? JSONEncoder().encode(services),
            let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }
}
