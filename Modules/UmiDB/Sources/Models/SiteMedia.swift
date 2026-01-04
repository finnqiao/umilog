import Foundation
import GRDB

/// Media asset for a dive site (photos/videos from Wikimedia Commons)
public struct SiteMedia: Codable, Identifiable, Hashable {
    public let id: String
    public let siteId: String
    public let kind: MediaKind
    public let url: String
    public let width: Int?
    public let height: Int?
    public let license: String?
    public let attribution: String?
    public let sourceUrl: String?
    public let sha256: String?
    public let isRedistributable: Bool

    public enum MediaKind: String, Codable, CaseIterable {
        case photo
        case video
    }

    public init(
        id: String = UUID().uuidString,
        siteId: String,
        kind: MediaKind = .photo,
        url: String,
        width: Int? = nil,
        height: Int? = nil,
        license: String? = nil,
        attribution: String? = nil,
        sourceUrl: String? = nil,
        sha256: String? = nil,
        isRedistributable: Bool = true
    ) {
        self.id = id
        self.siteId = siteId
        self.kind = kind
        self.url = url
        self.width = width
        self.height = height
        self.license = license
        self.attribution = attribution
        self.sourceUrl = sourceUrl
        self.sha256 = sha256
        self.isRedistributable = isRedistributable
    }
}

// MARK: - GRDB

extension SiteMedia: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "site_media"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let siteId = Column(CodingKeys.siteId)
        static let kind = Column(CodingKeys.kind)
        static let url = Column(CodingKeys.url)
        static let width = Column(CodingKeys.width)
        static let height = Column(CodingKeys.height)
        static let license = Column(CodingKeys.license)
        static let attribution = Column(CodingKeys.attribution)
        static let sourceUrl = Column(CodingKeys.sourceUrl)
        static let sha256 = Column(CodingKeys.sha256)
        static let isRedistributable = Column(CodingKeys.isRedistributable)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case siteId = "site_id"
        case kind
        case url
        case width
        case height
        case license
        case attribution
        case sourceUrl = "source_url"
        case sha256
        case isRedistributable = "is_redistributable"
    }
}

// MARK: - Associations

extension SiteMedia {
    public static let site = belongsTo(DiveSite.self)
}

// MARK: - Convenience

extension SiteMedia {
    /// URL object for the media asset
    public var imageURL: URL? {
        URL(string: url)
    }
}
