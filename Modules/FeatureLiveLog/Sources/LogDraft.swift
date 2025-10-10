import Foundation
import UmiDB

/// In-memory draft used by the logging wizard
public struct LogDraft: Identifiable, Codable {
    public let id: String
    
    // Step 1: Site & Timing
    public var site: DiveSite?
    public var date: Date
    public var startTime: Date
    
    // Step 2: Metrics
    public var maxDepthM: Double?
    public var bottomTimeMin: Int?
    public var startPressureBar: Int?
    public var endPressureBar: Int?
    public var temperatureC: Double?
    public var visibilityM: Double?
    
    // Step 3: Wildlife & Notes
    public var selectedSpecies: Set<String> // species IDs
    public var notes: String
    
    public init(id: String = UUID().uuidString,
                site: DiveSite? = nil,
                date: Date = Date(),
                startTime: Date = Date(),
                maxDepthM: Double? = nil,
                bottomTimeMin: Int? = nil,
                startPressureBar: Int? = nil,
                endPressureBar: Int? = nil,
                temperatureC: Double? = nil,
                visibilityM: Double? = nil,
                selectedSpecies: Set<String> = [],
                notes: String = "") {
        self.id = id
        self.site = site
        self.date = date
        self.startTime = startTime
        self.maxDepthM = maxDepthM
        self.bottomTimeMin = bottomTimeMin
        self.startPressureBar = startPressureBar
        self.endPressureBar = endPressureBar
        self.temperatureC = temperatureC
        self.visibilityM = visibilityM
        self.selectedSpecies = selectedSpecies
        self.notes = notes
    }
}
