import Foundation
import SwiftUI
import UmiDB

@MainActor
public class DiveLoggerViewModel: ObservableObject {
    // Site selection
    @Published public var selectedSite: DiveSite?
    @Published public var availableSites: [DiveSite] = []
    @Published public var siteSearchQuery = ""
    
    // Date & Time
    @Published public var diveDate = Date()
    @Published public var startTime = Date()
    
    // Dive Details
    @Published public var maxDepth = ""
    @Published public var averageDepth = ""
    @Published public var bottomTime = ""
    @Published public var startPressure = "200"
    @Published public var endPressure = "50"
    
    // Environment
    @Published public var temperature = "27"
    @Published public var visibility = "30"
    @Published public var current: DiveLog.Current = .none
    @Published public var conditions: DiveLog.Conditions = .good
    
    // Notes
    @Published public var notes = ""
    
    // Instructor
    @Published public var instructorName = ""
    @Published public var instructorNumber = ""
    @Published public var signed = false
    
    // State
    @Published public var isLoading = false
    @Published public var isSaved = false
    @Published public var error: String?
    
    private let database = AppDatabase.shared
    
    public init() {
        Task {
            await loadSites()
        }
    }
    
    public func loadSites() async {
        do {
            availableSites = try database.siteRepository.fetchAll()
            if let first = availableSites.first {
                selectedSite = first
            }
        } catch {
            self.error = "Failed to load sites: \(error.localizedDescription)"
        }
    }
    
    public var filteredSites: [DiveSite] {
        if siteSearchQuery.isEmpty {
            return availableSites
        }
        return availableSites.filter { site in
            site.name.localizedCaseInsensitiveContains(siteSearchQuery) ||
            site.location.localizedCaseInsensitiveContains(siteSearchQuery)
        }
    }
    
    public var canSave: Bool {
        selectedSite != nil &&
        !maxDepth.isEmpty &&
        !bottomTime.isEmpty &&
        Double(maxDepth) != nil &&
        Int(bottomTime) != nil
    }
    
    public func saveDive() async -> Bool {
        guard canSave, let site = selectedSite else {
            error = "Please fill in all required fields"
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let dive = DiveLog(
                siteId: site.id,
                date: diveDate,
                startTime: startTime,
                maxDepth: Double(maxDepth) ?? 0,
                averageDepth: Double(averageDepth),
                bottomTime: Int(bottomTime) ?? 0,
                startPressure: Int(startPressure) ?? 200,
                endPressure: Int(endPressure) ?? 50,
                temperature: Double(temperature) ?? 27,
                visibility: Double(visibility) ?? 30,
                current: current,
                conditions: conditions,
                notes: notes,
                instructorName: instructorName.isEmpty ? nil : instructorName,
                instructorNumber: instructorNumber.isEmpty ? nil : instructorNumber,
                signed: signed
            )
            
            try database.diveRepository.create(dive)
            isSaved = true
            print("✅ Dive saved successfully")
            return true
        } catch {
            self.error = "Failed to save dive: \(error.localizedDescription)"
            print("❌ Error saving dive: \(error)")
            return false
        }
    }
    
    public func reset() {
        maxDepth = ""
        averageDepth = ""
        bottomTime = ""
        startPressure = "200"
        endPressure = "50"
        temperature = "27"
        visibility = "30"
        current = .none
        conditions = .good
        notes = ""
        instructorName = ""
        instructorNumber = ""
        signed = false
        isSaved = false
        error = nil
    }
}
