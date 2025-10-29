import Foundation
import GRDB

public struct SiteShopLink: Codable, Hashable {
    public let siteId: String
    public let shopId: String
    public let distanceKm: Double?
    
    public init(siteId: String, shopId: String, distanceKm: Double? = nil) {
        self.siteId = siteId
        self.shopId = shopId
        self.distanceKm = distanceKm
    }
    
    private enum CodingKeys: String, CodingKey {
        case siteId = "site_id"
        case shopId = "shop_id"
        case distanceKm = "distance_km"
    }
}

extension SiteShopLink: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "site_shops"
    
    public enum Columns {
        public static let siteId = Column(CodingKeys.siteId)
        public static let shopId = Column(CodingKeys.shopId)
        public static let distanceKm = Column(CodingKeys.distanceKm)
    }
}
