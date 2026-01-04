import Foundation
import UmiDB
import os

/// Parses UDDF (Universal Dive Data Format) XML files into DiveLog entries
/// UDDF spec: https://www.uddf.org/
public class UDDFImporter: NSObject, XMLParserDelegate {
    private static let logger = Logger(subsystem: "app.umilog", category: "UDDFImporter")

    // Parsing state
    private var dives: [DiveLog] = []
    private var warnings: [String] = []
    private var currentElement = ""
    private var currentValue = ""

    // Current dive being parsed
    private var currentDiveDate: Date?
    private var currentMaxDepth: Double?
    private var currentBottomTime: Int?
    private var currentTemperature: Double?
    private var currentStartPressure: Int?
    private var currentEndPressure: Int?
    private var currentNotes: String?
    private var currentSiteName: String?

    // Dive sites from file
    private var diveSites: [String: String] = [:] // id -> name
    private var currentSiteId: String?
    private var currentSiteRefId: String?

    // Parsing context
    private var inDive = false
    private var inInformationBeforeDive = false
    private var inInformationAfterDive = false
    private var inSamples = false
    private var inDiveSite = false
    private var inDiveSiteRef = false

    private let siteRepository: SiteRepository

    public init(siteRepository: SiteRepository) {
        self.siteRepository = siteRepository
        super.init()
    }

    /// Parse UDDF data into dive logs
    public func parse(data: Data) throws -> CSVImporter.ImportResult {
        dives = []
        warnings = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        if let error = parser.parserError {
            throw ImportError.invalidFormat("XML parsing error: \(error.localizedDescription)")
        }

        Self.logger.info("UDDF import: \(self.dives.count) dives parsed")
        return CSVImporter.ImportResult(dives: dives, warnings: warnings, skippedRows: 0)
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentValue = ""

        switch elementName {
        case "dive":
            inDive = true
            resetCurrentDive()

        case "informationbeforedive":
            inInformationBeforeDive = true

        case "informationafterdive":
            inInformationAfterDive = true

        case "samples":
            inSamples = true

        case "divesite":
            inDiveSite = true
            currentSiteId = attributeDict["id"]

        case "link":
            if let ref = attributeDict["ref"], inDive {
                currentSiteRefId = ref
            }

        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmedValue = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "dive":
            finalizeDive()
            inDive = false

        case "informationbeforedive":
            inInformationBeforeDive = false

        case "informationafterdive":
            inInformationAfterDive = false

        case "samples":
            inSamples = false

        case "divesite":
            if let id = currentSiteId, let name = currentSiteName {
                diveSites[id] = name
            }
            inDiveSite = false
            currentSiteId = nil
            currentSiteName = nil

        case "datetime":
            if inInformationBeforeDive, let date = parseUDDFDate(trimmedValue) {
                currentDiveDate = date
            }

        case "greatestdepth":
            if let depth = Double(trimmedValue) {
                currentMaxDepth = depth
            }

        case "diveduration":
            // UDDF stores duration in seconds
            if let seconds = Double(trimmedValue) {
                currentBottomTime = Int(seconds / 60)
            }

        case "lowesttemperature":
            if let temp = Double(trimmedValue) {
                // UDDF uses Kelvin
                currentTemperature = temp - 273.15
            }

        case "tankpressurebegin":
            if let pressure = Double(trimmedValue) {
                // UDDF uses Pascal, convert to bar
                currentStartPressure = Int(pressure / 100000)
            }

        case "tankpressureend":
            if let pressure = Double(trimmedValue) {
                currentEndPressure = Int(pressure / 100000)
            }

        case "notes":
            if inDive {
                currentNotes = trimmedValue
            }

        case "name":
            if inDiveSite {
                currentSiteName = trimmedValue
            }

        default:
            break
        }

        currentElement = ""
        currentValue = ""
    }

    // MARK: - Helpers

    private func resetCurrentDive() {
        currentDiveDate = nil
        currentMaxDepth = nil
        currentBottomTime = nil
        currentTemperature = nil
        currentStartPressure = nil
        currentEndPressure = nil
        currentNotes = nil
        currentSiteRefId = nil
    }

    private func finalizeDive() {
        guard let date = currentDiveDate,
              let maxDepth = currentMaxDepth,
              let bottomTime = currentBottomTime else {
            warnings.append("Skipped dive: missing required fields (date, depth, or duration)")
            return
        }

        // Resolve site
        var siteId: String?
        if let refId = currentSiteRefId, let siteName = diveSites[refId] {
            // Try to match site by name
            if let site = try? siteRepository.search(query: siteName).first {
                siteId = site.id
            }
        }

        let dive = DiveLog(
            siteId: siteId,
            date: date,
            startTime: date,
            endTime: date.addingTimeInterval(TimeInterval(bottomTime * 60)),
            maxDepth: maxDepth,
            bottomTime: bottomTime,
            startPressure: currentStartPressure ?? 200,
            endPressure: currentEndPressure ?? 50,
            temperature: currentTemperature ?? 26.0,
            visibility: 15.0,  // Not typically in UDDF
            notes: currentNotes ?? ""
        )

        dives.append(dive)
    }

    private func parseUDDFDate(_ string: String) -> Date? {
        // UDDF uses ISO 8601 format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: string) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
