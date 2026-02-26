import Foundation
import GRDB

public final class ConditionReportRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Create

    public func create(_ report: ConditionReport) throws {
        try database.write { db in
            try report.insert(db)
        }
    }

    /// Auto-generate a condition report from a saved dive log.
    public func createFromDiveLog(_ dive: DiveLog) throws {
        guard let siteId = dive.siteId else { return }

        let report = ConditionReport(
            siteId: siteId,
            visibility: dive.visibility,
            current: ConditionReport.Current(rawValue: dive.current.rawValue),
            temperature: dive.temperature,
            reportedAt: dive.startTime,
            source: .diveLog
        )
        try create(report)
    }

    // MARK: - Read

    /// Fetch the most recent reports for a site.
    public func fetchRecent(siteId: String, limit: Int = 10) throws -> [ConditionReport] {
        try database.read { db in
            try ConditionReport
                .filter(ConditionReport.Columns.siteId == siteId)
                .order(ConditionReport.Columns.reportedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Build an aggregated summary for a site from recent reports.
    public func summary(siteId: String) throws -> SiteConditionSummary {
        try database.read { db in
            let now = Date()
            let twentyFourHoursAgo = now.addingTimeInterval(-86_400)
            let sevenDaysAgo = now.addingTimeInterval(-604_800)

            let latest = try ConditionReport
                .filter(ConditionReport.Columns.siteId == siteId)
                .order(ConditionReport.Columns.reportedAt.desc)
                .fetchOne(db)

            let count24h = try ConditionReport
                .filter(ConditionReport.Columns.siteId == siteId)
                .filter(ConditionReport.Columns.reportedAt >= twentyFourHoursAgo)
                .fetchCount(db)

            let count7d = try ConditionReport
                .filter(ConditionReport.Columns.siteId == siteId)
                .filter(ConditionReport.Columns.reportedAt >= sevenDaysAgo)
                .fetchCount(db)

            // Averages from last 7 days
            let recentReports = try ConditionReport
                .filter(ConditionReport.Columns.siteId == siteId)
                .filter(ConditionReport.Columns.reportedAt >= sevenDaysAgo)
                .fetchAll(db)

            let visibilities = recentReports.compactMap(\.visibility)
            let temperatures = recentReports.compactMap(\.temperature)
            let currents = recentReports.compactMap(\.current)

            let avgVis = visibilities.isEmpty ? nil : visibilities.reduce(0, +) / Double(visibilities.count)
            let avgTemp = temperatures.isEmpty ? nil : temperatures.reduce(0, +) / Double(temperatures.count)

            // Dominant current = most common in recent reports
            let dominantCurrent: ConditionReport.Current? = {
                guard !currents.isEmpty else { return nil }
                var counts: [ConditionReport.Current: Int] = [:]
                for c in currents { counts[c, default: 0] += 1 }
                return counts.max(by: { $0.value < $1.value })?.key
            }()

            // Freshness
            let freshness: SiteConditionSummary.Freshness
            if let latestDate = latest?.reportedAt {
                let age = now.timeIntervalSince(latestDate)
                if age < 7200 { freshness = .live }
                else if age < 86_400 { freshness = .recent }
                else if age < 604_800 { freshness = .stale }
                else { freshness = .old }
            } else {
                freshness = .none
            }

            return SiteConditionSummary(
                siteId: siteId,
                latestReport: latest,
                avgVisibility: avgVis,
                avgTemperature: avgTemp,
                dominantCurrent: dominantCurrent,
                reportCount24h: count24h,
                reportCount7d: count7d,
                freshness: freshness
            )
        }
    }

    /// Fetch condition summaries for multiple sites (for map overlay).
    public func summaries(siteIds: [String]) throws -> [SiteConditionSummary] {
        try siteIds.map { try summary(siteId: $0) }
    }

    // MARK: - Rate Limiting

    /// Check if the user has already submitted a report for this site within the last hour.
    public func hasRecentReport(siteId: String, reporterId: String) throws -> Bool {
        try database.read { db in
            let oneHourAgo = Date().addingTimeInterval(-3600)
            let count = try ConditionReport
                .filter(ConditionReport.Columns.siteId == siteId)
                .filter(ConditionReport.Columns.reporterId == reporterId)
                .filter(ConditionReport.Columns.createdAt >= oneHourAgo)
                .fetchCount(db)
            return count > 0
        }
    }

    // MARK: - Delete

    /// Delete old reports (cleanup, e.g., > 90 days).
    public func deleteOlderThan(days: Int) throws {
        try database.write { db in
            let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
            try ConditionReport
                .filter(ConditionReport.Columns.reportedAt < cutoff)
                .deleteAll(db)
        }
    }
}
