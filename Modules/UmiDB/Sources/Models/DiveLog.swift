import Foundation
import GRDB

/// Core dive log entry
public struct DiveLog: Codable, Identifiable {
    public let id: String
    public let siteId: String
    public let date: Date
    public let startTime: Date
    public let endTime: Date?
    public let maxDepth: Double // meters
    public let averageDepth: Double? // meters
    public let bottomTime: Int // minutes
    public let startPressure: Int // bar
    public let endPressure: Int // bar
    public let temperature: Double // celsius
    public let visibility: Double // meters
    public let current: Current
    public let conditions: Conditions
    public let notes: String
    public let instructorName: String?
    public let instructorNumber: String?
    public let signed: Bool
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        siteId: String,
        date: Date,
        startTime: Date,
        endTime: Date? = nil,
        maxDepth: Double,
        averageDepth: Double? = nil,
        bottomTime: Int,
        startPressure: Int,
        endPressure: Int,
        temperature: Double,
        visibility: Double,
        current: Current = .none,
        conditions: Conditions = .good,
        notes: String = "",
        instructorName: String? = nil,
        instructorNumber: String? = nil,
        signed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.siteId = siteId
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.maxDepth = maxDepth
        self.averageDepth = averageDepth
        self.bottomTime = bottomTime
        self.startPressure = startPressure
        self.endPressure = endPressure
        self.temperature = temperature
        self.visibility = visibility
        self.current = current
        self.conditions = conditions
        self.notes = notes
        self.instructorName = instructorName
        self.instructorNumber = instructorNumber
        self.signed = signed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public enum Current: String, Codable {
        case none = "None"
        case light = "Light"
        case moderate = "Moderate"
        case strong = "Strong"
    }
    
    public enum Conditions: String, Codable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
    }
}

// MARK: - GRDB
extension DiveLog: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "dives"
    
    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let siteId = Column(CodingKeys.siteId)
        static let date = Column(CodingKeys.date)
        static let startTime = Column(CodingKeys.startTime)
        static let endTime = Column(CodingKeys.endTime)
        static let maxDepth = Column(CodingKeys.maxDepth)
        static let averageDepth = Column(CodingKeys.averageDepth)
        static let bottomTime = Column(CodingKeys.bottomTime)
        static let startPressure = Column(CodingKeys.startPressure)
        static let endPressure = Column(CodingKeys.endPressure)
        static let temperature = Column(CodingKeys.temperature)
        static let visibility = Column(CodingKeys.visibility)
        static let current = Column(CodingKeys.current)
        static let conditions = Column(CodingKeys.conditions)
        static let notes = Column(CodingKeys.notes)
        static let instructorName = Column(CodingKeys.instructorName)
        static let instructorNumber = Column(CodingKeys.instructorNumber)
        static let signed = Column(CodingKeys.signed)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - Associations
extension DiveLog {
    public static let site = belongsTo(DiveSite.self)
    public static let sightings = hasMany(WildlifeSighting.self)
}
