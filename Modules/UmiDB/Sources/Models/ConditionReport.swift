import Foundation
import GRDB

/// A lightweight conditions report for a dive site.
/// Can be auto-generated from a DiveLog or submitted independently via quick report.
public struct ConditionReport: Codable, Identifiable, Equatable {
    public static let databaseTableName = "condition_reports"

    public var id: String
    public var siteId: String
    public var reporterId: String
    public var visibility: Double?       // meters
    public var current: Current?
    public var temperature: Double?      // celsius
    public var surfaceConditions: SurfaceConditions?
    public var notes: String?
    public var reportedAt: Date
    public var createdAt: Date
    public var source: ReportSource

    public enum Current: String, Codable, CaseIterable, DatabaseValueConvertible {
        case none = "None"
        case light = "Light"
        case moderate = "Moderate"
        case strong = "Strong"

        public var displayName: String { rawValue }
    }

    public enum SurfaceConditions: String, Codable, CaseIterable, DatabaseValueConvertible {
        case calm = "Calm"
        case choppy = "Choppy"
        case rough = "Rough"

        public var displayName: String { rawValue }
    }

    public enum ReportSource: String, Codable, DatabaseValueConvertible {
        case diveLog
        case quickReport
        case synced
    }

    public init(
        id: String = UUID().uuidString,
        siteId: String,
        reporterId: String = "",
        visibility: Double? = nil,
        current: Current? = nil,
        temperature: Double? = nil,
        surfaceConditions: SurfaceConditions? = nil,
        notes: String? = nil,
        reportedAt: Date = Date(),
        createdAt: Date = Date(),
        source: ReportSource = .quickReport
    ) {
        self.id = id
        self.siteId = siteId
        self.reporterId = reporterId
        self.visibility = visibility
        self.current = current
        self.temperature = temperature
        self.surfaceConditions = surfaceConditions
        self.notes = notes
        self.reportedAt = reportedAt
        self.createdAt = createdAt
        self.source = source
    }
}

// MARK: - GRDB

extension ConditionReport: FetchableRecord, PersistableRecord {
    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let siteId = Column(CodingKeys.siteId)
        static let reporterId = Column(CodingKeys.reporterId)
        static let visibility = Column(CodingKeys.visibility)
        static let current = Column(CodingKeys.current)
        static let temperature = Column(CodingKeys.temperature)
        static let surfaceConditions = Column(CodingKeys.surfaceConditions)
        static let notes = Column(CodingKeys.notes)
        static let reportedAt = Column(CodingKeys.reportedAt)
        static let createdAt = Column(CodingKeys.createdAt)
        static let source = Column(CodingKeys.source)
    }
}

// MARK: - Associations

extension ConditionReport {
    public static let site = belongsTo(DiveSite.self, using: ForeignKey(["siteId"]))
}

// MARK: - Aggregated Conditions Summary

/// Aggregated condition data for a site based on recent reports.
public struct SiteConditionSummary: Equatable {
    public let siteId: String
    public let latestReport: ConditionReport?
    public let avgVisibility: Double?
    public let avgTemperature: Double?
    public let dominantCurrent: ConditionReport.Current?
    public let reportCount24h: Int
    public let reportCount7d: Int
    public let freshness: Freshness

    public enum Freshness: Equatable {
        case live       // < 2 hours
        case recent     // < 24 hours
        case stale      // < 7 days
        case old        // > 7 days
        case none       // no reports

        public var label: String {
            switch self {
            case .live: return "Just now"
            case .recent: return "Today"
            case .stale: return "This week"
            case .old: return "Older"
            case .none: return "No reports"
            }
        }
    }
}

extension SiteConditionSummary: Identifiable {
    public var id: String { siteId }
}
