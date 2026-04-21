import Foundation
import GRDB

public struct SightingPhoto: Codable, Identifiable, Hashable {
    public let id: String
    public let sightingId: String
    public let filename: String
    public let thumbnailFilename: String
    public let width: Int
    public let height: Int
    public let capturedAt: Date?
    public let latitude: Double?
    public let longitude: Double?
    public let sortOrder: Int
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        sightingId: String,
        filename: String,
        thumbnailFilename: String,
        width: Int,
        height: Int,
        capturedAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sightingId = sightingId
        self.filename = filename
        self.thumbnailFilename = thumbnailFilename
        self.width = width
        self.height = height
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

extension SightingPhoto: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "sighting_photos"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let sightingId = Column(CodingKeys.sightingId)
        static let filename = Column(CodingKeys.filename)
        static let thumbnailFilename = Column(CodingKeys.thumbnailFilename)
        static let width = Column(CodingKeys.width)
        static let height = Column(CodingKeys.height)
        static let capturedAt = Column(CodingKeys.capturedAt)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
        static let sortOrder = Column(CodingKeys.sortOrder)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}

extension SightingPhoto {
    public static let sighting = belongsTo(WildlifeSighting.self)
}
