import Foundation
import UmiDB
import CoreLocation
import os

/// Parses Subsurface XML (.ssrf) and Subsurface-exported XML files into DiveLog entries.
/// Subsurface is the most popular open-source dive log software.
///
/// Expected format:
/// ```xml
/// <divelog>
///   <divesites>
///     <site uuid="..." name="Blue Hole" gps="28.572 34.558"/>
///   </divesites>
///   <dives>
///     <trip location="Dahab" date="2025-12-15">
///       <dive number="1" date="2025-12-15" time="09:30:00" duration="45:00 min">
///         <depth max="30.2 m" mean="18.5 m"/>
///         <temperature water="26.0 C" air="30.0 C"/>
///         <cylinder size="12.0 l" start="200 bar" end="50 bar" o2="21.0%"/>
///         <location gps="28.572 34.558">Blue Hole, Dahab</location>
///         <buddy>Jane</buddy>
///         <notes>Amazing visibility</notes>
///       </dive>
///     </trip>
///   </dives>
/// </divelog>
/// ```
public final class SubsurfaceImporter: NSObject, XMLParserDelegate {
    private static let logger = Logger(subsystem: "app.umilog", category: "SubsurfaceImporter")

    // Results
    private var dives: [DiveLog] = []
    private var warnings: [String] = []

    // Dive site lookup from <divesites> section
    private var siteMap: [String: SubsurfaceSite] = [:]  // uuid -> site

    // Current parsing state
    private var currentElement = ""
    private var currentValue = ""
    private var inDiveSites = false
    private var inDive = false

    // Current dive fields
    private var diveDate: Date?
    private var diveTime: Date?
    private var diveDuration: Int?  // minutes
    private var maxDepth: Double?
    private var meanDepth: Double?
    private var waterTemp: Double?
    private var startPressure: Int?
    private var endPressure: Int?
    private var o2Percent: Double?
    private var locationName: String?
    private var locationGPS: CLLocationCoordinate2D?
    private var buddy: String?
    private var divemaster: String?
    private var suit: String?
    private var notes: String?
    private var visibility: String?
    private var diveNumber: Int?

    private let siteRepository: SiteRepository

    public init(siteRepository: SiteRepository) {
        self.siteRepository = siteRepository
        super.init()
    }

    /// Parse Subsurface XML data into dive logs.
    public func parse(data: Data) throws -> CSVImporter.ImportResult {
        dives = []
        warnings = []
        siteMap = [:]

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        if let error = parser.parserError {
            throw ImportError.invalidFormat("XML parsing error: \(error.localizedDescription)")
        }

        Self.logger.info("Subsurface import: \(self.dives.count) dives parsed, \(self.warnings.count) warnings")
        return CSVImporter.ImportResult(dives: dives, warnings: warnings, skippedRows: 0)
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentValue = ""

        switch elementName {
        case "divesites":
            inDiveSites = true

        case "site":
            if inDiveSites {
                parseDiveSiteElement(attributeDict)
            }

        case "dive":
            inDive = true
            resetCurrentDive()
            parseDiveAttributes(attributeDict)

        case "depth":
            if inDive {
                parseDepthAttributes(attributeDict)
            }

        case "temperature":
            if inDive {
                parseTemperatureAttributes(attributeDict)
            }

        case "cylinder":
            if inDive {
                parseCylinderAttributes(attributeDict)
            }

        case "location":
            if inDive {
                if let gps = attributeDict["gps"] {
                    locationGPS = parseGPSString(gps)
                }
            }

        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "divesites":
            inDiveSites = false

        case "dive":
            if inDive {
                finalizeDive()
                inDive = false
            }

        case "location":
            if inDive && !trimmed.isEmpty {
                locationName = trimmed
            }

        case "buddy":
            if inDive && !trimmed.isEmpty {
                buddy = trimmed
            }

        case "divemaster":
            if inDive && !trimmed.isEmpty {
                divemaster = trimmed
            }

        case "suit":
            if inDive && !trimmed.isEmpty {
                suit = trimmed
            }

        case "notes":
            if inDive && !trimmed.isEmpty {
                notes = trimmed
            }

        case "visibility":
            if inDive && !trimmed.isEmpty {
                visibility = trimmed
            }

        default:
            break
        }

        currentElement = ""
        currentValue = ""
    }

    // MARK: - Attribute Parsers

    private func parseDiveSiteElement(_ attrs: [String: String]) {
        guard let uuid = attrs["uuid"] else { return }
        let site = SubsurfaceSite(
            uuid: uuid,
            name: attrs["name"],
            gps: attrs["gps"].flatMap(parseGPSString)
        )
        siteMap[uuid] = site
    }

    private func parseDiveAttributes(_ attrs: [String: String]) {
        if let dateStr = attrs["date"] {
            diveDate = parseSubsurfaceDate(dateStr)
        }
        if let timeStr = attrs["time"], let date = diveDate {
            diveTime = parseSubsurfaceTime(timeStr, on: date)
        }
        if let durStr = attrs["duration"] {
            diveDuration = parseSubsurfaceDuration(durStr)
        }
        if let numStr = attrs["number"] {
            diveNumber = Int(numStr)
        }
        if let visStr = attrs["visibility"] {
            visibility = visStr
        }
    }

    private func parseDepthAttributes(_ attrs: [String: String]) {
        if let maxStr = attrs["max"] {
            maxDepth = parseMetricValue(maxStr)
        }
        if let meanStr = attrs["mean"] {
            meanDepth = parseMetricValue(meanStr)
        }
    }

    private func parseTemperatureAttributes(_ attrs: [String: String]) {
        if let waterStr = attrs["water"] {
            waterTemp = parseMetricValue(waterStr)
        }
    }

    private func parseCylinderAttributes(_ attrs: [String: String]) {
        if let startStr = attrs["start"] {
            startPressure = Int(parseMetricValue(startStr) ?? 0)
        }
        if let endStr = attrs["end"] {
            endPressure = Int(parseMetricValue(endStr) ?? 0)
        }
        if let o2Str = attrs["o2"] {
            o2Percent = parsePercentValue(o2Str)
        }
    }

    // MARK: - Dive Finalization

    private func resetCurrentDive() {
        diveDate = nil
        diveTime = nil
        diveDuration = nil
        maxDepth = nil
        meanDepth = nil
        waterTemp = nil
        startPressure = nil
        endPressure = nil
        o2Percent = nil
        locationName = nil
        locationGPS = nil
        buddy = nil
        divemaster = nil
        suit = nil
        notes = nil
        visibility = nil
        diveNumber = nil
    }

    private func finalizeDive() {
        guard let date = diveDate,
              let depth = maxDepth,
              let duration = diveDuration else {
            let num = diveNumber.map { "Dive #\($0)" } ?? "Unknown dive"
            warnings.append("\(num): Missing required fields (date, depth, or duration)")
            return
        }

        let startTime = diveTime ?? date

        // Resolve site by name or GPS
        var siteId: String?
        var pendingLat: Double?
        var pendingLon: Double?

        if let name = locationName {
            siteId = matchSite(name: name, gps: locationGPS)
        }

        // If no site matched but we have GPS, use pending coordinates
        if siteId == nil, let gps = locationGPS {
            pendingLat = gps.latitude
            pendingLon = gps.longitude
        }

        // Build notes from various fields
        var allNotes = [String]()
        if let n = notes { allNotes.append(n) }
        if let b = buddy { allNotes.append("Buddy: \(b)") }
        if let dm = divemaster { allNotes.append("Divemaster: \(dm)") }
        if let s = suit { allNotes.append("Suit: \(s)") }
        if let o2 = o2Percent, o2 != 21 {
            allNotes.append(String(format: "Gas: EAN%.0f", o2))
        }

        // Convert Subsurface visibility (1-5 stars) to meters estimate
        let visMeters = estimateVisibility(from: visibility)

        let dive = DiveLog(
            siteId: siteId,
            pendingLatitude: pendingLat,
            pendingLongitude: pendingLon,
            date: date,
            startTime: startTime,
            endTime: startTime.addingTimeInterval(TimeInterval(duration * 60)),
            maxDepth: depth,
            averageDepth: meanDepth,
            bottomTime: duration,
            startPressure: startPressure ?? 200,
            endPressure: endPressure ?? 50,
            temperature: waterTemp ?? 26.0,
            visibility: visMeters,
            notes: allNotes.joined(separator: "\n")
        )

        dives.append(dive)
    }

    // MARK: - Value Parsers

    /// Parse "30.2 m" or "30.2m" → 30.2
    private func parseMetricValue(_ string: String) -> Double? {
        let cleaned = string
            .replacingOccurrences(of: " m", with: "")
            .replacingOccurrences(of: "m", with: "")
            .replacingOccurrences(of: " bar", with: "")
            .replacingOccurrences(of: "bar", with: "")
            .replacingOccurrences(of: " C", with: "")
            .replacingOccurrences(of: "C", with: "")
            .replacingOccurrences(of: " l", with: "")
            .replacingOccurrences(of: "l", with: "")
            .replacingOccurrences(of: "\u{00B0}", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    /// Parse "21.0%" → 21.0
    private func parsePercentValue(_ string: String) -> Double? {
        let cleaned = string.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    /// Parse "45:00 min" → 45
    private func parseSubsurfaceDuration(_ string: String) -> Int? {
        let cleaned = string
            .replacingOccurrences(of: " min", with: "")
            .replacingOccurrences(of: "min", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Handle "HH:MM" or "MM:SS" format
        let parts = cleaned.split(separator: ":")
        if parts.count == 2, let minutes = Int(parts[0]) {
            return minutes
        }
        return Int(cleaned)
    }

    /// Parse "2025-12-15" → Date
    private func parseSubsurfaceDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }

    /// Parse "09:30:00" and combine with a date
    private func parseSubsurfaceTime(_ string: String, on date: Date) -> Date? {
        let parts = string.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        if parts.count >= 3 { components.second = Int(parts[2]) }
        return Calendar.current.date(from: components)
    }

    /// Parse "28.572 34.558" → CLLocationCoordinate2D
    private func parseGPSString(_ string: String) -> CLLocationCoordinate2D? {
        let parts = string.split(separator: " ")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Convert Subsurface visibility rating (1-5 stars or descriptive) to meters.
    private func estimateVisibility(from string: String?) -> Double {
        guard let vis = string else { return 15.0 }
        // If it's a numeric star rating
        if let stars = Int(vis) {
            switch stars {
            case 1: return 3
            case 2: return 8
            case 3: return 15
            case 4: return 25
            case 5: return 35
            default: return 15
            }
        }
        // If it contains a distance
        if let meters = parseMetricValue(vis) {
            return meters
        }
        return 15.0
    }

    // MARK: - Site Matching

    private func matchSite(name: String, gps: CLLocationCoordinate2D?) -> String? {
        // 1. Exact name match via FTS search
        if let site = try? siteRepository.search(query: name).first {
            return site.id
        }

        // 2. GPS proximity match (within 2km)
        if let gps = gps {
            if let site = try? siteRepository.findNearest(
                latitude: gps.latitude,
                longitude: gps.longitude,
                maxDistanceKm: 2.0
            ) {
                return site.id
            }
        }

        return nil
    }
}

// MARK: - Supporting Types

private struct SubsurfaceSite {
    let uuid: String
    let name: String?
    let gps: CLLocationCoordinate2D?
}
