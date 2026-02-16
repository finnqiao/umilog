import Foundation
import GRDB

/// User-specific state for a dive site (wishlist, planned, notes)
/// This separates user data from seed data for efficient sync
public struct UserSiteState: Codable, Identifiable {
    public var id: String { siteId }
    public let siteId: String
    public var isWishlist: Bool
    public var isPlanned: Bool
    public var userNotes: String?
    public var userRating: Int?
    public var lastVisitedAt: Date?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        siteId: String,
        isWishlist: Bool = false,
        isPlanned: Bool = false,
        userNotes: String? = nil,
        userRating: Int? = nil,
        lastVisitedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.siteId = siteId
        self.isWishlist = isWishlist
        self.isPlanned = isPlanned
        self.userNotes = userNotes
        self.userRating = userRating
        self.lastVisitedAt = lastVisitedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case siteId = "site_id"
        case isWishlist = "is_wishlist"
        case isPlanned = "is_planned"
        case userNotes = "user_notes"
        case userRating = "user_rating"
        case lastVisitedAt = "last_visited_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - GRDB
extension UserSiteState: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "user_site_states"

    public enum Columns {
        static let siteId = Column(CodingKeys.siteId)
        static let isWishlist = Column(CodingKeys.isWishlist)
        static let isPlanned = Column(CodingKeys.isPlanned)
        static let userNotes = Column(CodingKeys.userNotes)
        static let userRating = Column(CodingKeys.userRating)
        static let lastVisitedAt = Column(CodingKeys.lastVisitedAt)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - Associations
extension UserSiteState {
    public static let site = belongsTo(DiveSite.self)
}
