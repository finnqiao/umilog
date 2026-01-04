import Foundation
import UmiDB
import os

/// Parses CSV dive log files into DiveLog entries
public struct CSVImporter {
    private static let logger = Logger(subsystem: "app.umilog", category: "CSVImporter")

    /// Expected CSV columns (case-insensitive matching)
    public enum Column: String, CaseIterable {
        case date
        case time
        case siteName = "site_name"
        case siteId = "site_id"
        case maxDepth = "max_depth"
        case avgDepth = "avg_depth"
        case bottomTime = "bottom_time"
        case startPressure = "start_pressure"
        case endPressure = "end_pressure"
        case temperature
        case visibility
        case current
        case conditions
        case notes
        case buddy
        case instructor

        /// Alternative column names that map to this column
        var aliases: [String] {
            switch self {
            case .date: return ["date", "dive_date", "divedate"]
            case .time: return ["time", "start_time", "starttime"]
            case .siteName: return ["site_name", "sitename", "site", "location"]
            case .siteId: return ["site_id", "siteid"]
            case .maxDepth: return ["max_depth", "maxdepth", "depth", "max_depth_m"]
            case .avgDepth: return ["avg_depth", "avgdepth", "average_depth"]
            case .bottomTime: return ["bottom_time", "bottomtime", "time_min", "duration"]
            case .startPressure: return ["start_pressure", "startpressure", "start_bar"]
            case .endPressure: return ["end_pressure", "endpressure", "end_bar"]
            case .temperature: return ["temperature", "temp", "water_temp"]
            case .visibility: return ["visibility", "vis", "visibility_m"]
            case .current: return ["current"]
            case .conditions: return ["conditions", "weather"]
            case .notes: return ["notes", "comments", "remarks"]
            case .buddy: return ["buddy", "dive_buddy"]
            case .instructor: return ["instructor", "instructor_name"]
            }
        }
    }

    /// Result of parsing a CSV file
    public struct ImportResult {
        public let dives: [DiveLog]
        public let warnings: [String]
        public let skippedRows: Int
    }

    /// Parse CSV data into dive logs
    public static func parse(data: Data, siteRepository: SiteRepository) throws -> ImportResult {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else {
            throw ImportError.noData
        }

        // Parse header row
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine).map { $0.lowercased() }
        let columnMap = mapColumns(headers: headers)

        var dives: [DiveLog] = []
        var warnings: [String] = []
        var skipped = 0

        // Parse data rows
        for (index, line) in lines.dropFirst().enumerated() {
            let rowNumber = index + 2 // Account for header and 0-based index

            do {
                let values = parseCSVLine(line)
                if let dive = try parseRow(values: values, columnMap: columnMap, rowNumber: rowNumber, siteRepository: siteRepository) {
                    dives.append(dive)
                } else {
                    skipped += 1
                    warnings.append("Row \(rowNumber): Missing required fields (date, depth, or time)")
                }
            } catch {
                skipped += 1
                warnings.append("Row \(rowNumber): \(error.localizedDescription)")
            }
        }

        logger.info("CSV import: \(dives.count) dives parsed, \(skipped) skipped")
        return ImportResult(dives: dives, warnings: warnings, skippedRows: skipped)
    }

    /// Parse a single CSV row into a DiveLog
    private static func parseRow(
        values: [String],
        columnMap: [Column: Int],
        rowNumber: Int,
        siteRepository: SiteRepository
    ) throws -> DiveLog? {
        // Required: date, maxDepth, bottomTime
        guard let dateIndex = columnMap[.date],
              dateIndex < values.count,
              let date = parseDate(values[dateIndex]) else {
            return nil
        }

        guard let depthIndex = columnMap[.maxDepth],
              depthIndex < values.count,
              let maxDepth = Double(values[depthIndex].replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }

        guard let timeIndex = columnMap[.bottomTime],
              timeIndex < values.count,
              let bottomTime = Int(values[timeIndex]) else {
            return nil
        }

        // Parse optional fields
        let siteId = resolveSiteId(
            siteNameIndex: columnMap[.siteName],
            siteIdIndex: columnMap[.siteId],
            values: values,
            siteRepository: siteRepository
        )

        let startTime = columnMap[.time].flatMap { $0 < values.count ? parseTime(values[$0], on: date) : nil } ?? date
        let avgDepth = columnMap[.avgDepth].flatMap { $0 < values.count ? Double(values[$0].replacingOccurrences(of: ",", with: ".")) : nil }
        let startPressure = columnMap[.startPressure].flatMap { $0 < values.count ? Int(values[$0]) : nil } ?? 200
        let endPressure = columnMap[.endPressure].flatMap { $0 < values.count ? Int(values[$0]) : nil } ?? 50
        let temperature = columnMap[.temperature].flatMap { $0 < values.count ? Double(values[$0].replacingOccurrences(of: ",", with: ".")) : nil } ?? 26.0
        let visibility = columnMap[.visibility].flatMap { $0 < values.count ? Double(values[$0].replacingOccurrences(of: ",", with: ".")) : nil } ?? 15.0
        let currentStr = columnMap[.current].flatMap { $0 < values.count ? values[$0] : nil }
        let conditionsStr = columnMap[.conditions].flatMap { $0 < values.count ? values[$0] : nil }
        let notes = columnMap[.notes].flatMap { $0 < values.count ? values[$0] : nil } ?? ""

        let current = DiveLog.Current(rawValue: currentStr?.capitalized ?? "") ?? .none
        let conditions = DiveLog.Conditions(rawValue: conditionsStr?.capitalized ?? "") ?? .good

        return DiveLog(
            siteId: siteId,
            date: date,
            startTime: startTime,
            endTime: startTime.addingTimeInterval(TimeInterval(bottomTime * 60)),
            maxDepth: maxDepth,
            averageDepth: avgDepth,
            bottomTime: bottomTime,
            startPressure: startPressure,
            endPressure: endPressure,
            temperature: temperature,
            visibility: visibility,
            current: current,
            conditions: conditions,
            notes: notes
        )
    }

    /// Map header names to Column enum
    private static func mapColumns(headers: [String]) -> [Column: Int] {
        var map: [Column: Int] = [:]

        for column in Column.allCases {
            for (index, header) in headers.enumerated() {
                if column.aliases.contains(header) {
                    map[column] = index
                    break
                }
            }
        }

        return map
    }

    /// Parse a CSV line, handling quoted values
    private static func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                values.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        values.append(current.trimmingCharacters(in: .whitespaces))

        return values
    }

    /// Parse date string in various formats
    private static func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = [
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"; return f }(),
        ]

        let iso8601 = ISO8601DateFormatter()
        if let date = iso8601.date(from: string) {
            return date
        }

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    /// Parse time string and combine with date
    private static func parseTime(_ string: String, on date: Date) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let time = formatter.date(from: string) else { return nil }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute

        return calendar.date(from: dateComponents)
    }

    /// Try to resolve site ID from name or direct ID
    private static func resolveSiteId(
        siteNameIndex: Int?,
        siteIdIndex: Int?,
        values: [String],
        siteRepository: SiteRepository
    ) -> String? {
        // First try direct site ID
        if let index = siteIdIndex, index < values.count {
            let id = values[index]
            if !id.isEmpty {
                return id
            }
        }

        // Try to match by site name
        if let index = siteNameIndex, index < values.count {
            let name = values[index]
            if !name.isEmpty {
                if let site = try? siteRepository.search(query: name).first {
                    return site.id
                }
            }
        }

        return nil
    }
}

// MARK: - Errors

public enum ImportError: LocalizedError {
    case invalidEncoding
    case noData
    case invalidFormat(String)
    case parseError(row: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Could not read file. Please ensure it's a UTF-8 encoded CSV."
        case .noData:
            return "The file appears to be empty or has no data rows."
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        case .parseError(let row, let message):
            return "Error on row \(row): \(message)"
        }
    }
}
