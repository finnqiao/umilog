import Foundation
import Combine
import CoreLocation
import UmiDB
import UmiLocationKit
import UmiCoreKit

@MainActor
public final class QuickLogViewModel: ObservableObject {
    // Published properties for UI binding
    @Published public var selectedSite: DiveSite?
    @Published public var diveDate = Date()
    @Published public var maxDepth: Double = 18.0
    @Published public var bottomTime: Int = 40
    @Published public var waterTemp: Double?
    @Published public var visibility: Double?
    @Published public var buddy: String = ""
    @Published public var notes: String = ""
    
    // UI state
    @Published public var hasLastDive = false
    @Published public var isSaving = false
    @Published public var showingError = false
    @Published public var errorMessage: String?
    
    // Dependencies
    private let database = AppDatabase.shared
    private let diveRepository: DiveRepository
    private let siteRepository: SiteRepository
    private let locationService = LocationService.shared
    private let geofenceManager = GeofenceManager.shared
    
    // Cached data
    private var lastDive: DiveLog?
    private var nearbySites: [DiveSite] = []
    
    public init() {
        self.diveRepository = DiveRepository(database: database)
        self.siteRepository = SiteRepository(database: database)
    }
    
    // MARK: - Initialization
    
    public func initialize(with suggestedSite: DiveSite?) async {
        // Set suggested site from geofencing
        if let site = suggestedSite {
            selectedSite = site
            applySmartDefaults(for: site)
        } else if geofenceManager.isAtDiveSite, let currentSite = geofenceManager.currentDiveSite {
            // Use current geofenced site
            selectedSite = currentSite
            applySmartDefaults(for: currentSite)
        }
        
        // Load last dive for "same as last" feature
        await loadLastDive()
        
        // Load nearby sites
        await loadNearbySites()
        
        // Apply smart defaults based on patterns
        if selectedSite == nil {
            await applyLocationBasedDefaults()
        }
    }
    
    // MARK: - Quick Actions
    
    public func fillFromLastDive() {
        guard let dive = lastDive else { return }
        
        // Copy relevant fields from last dive
        maxDepth = dive.maxDepth
        bottomTime = dive.bottomTime
        
        // Try to find the site
        Task {
            if let site = try? await siteRepository.fetch(id: dive.siteId) {
                selectedSite = site
            }
        }
        
        // Keep today's date but use similar time of day
        let calendar = Calendar.current
        let lastDiveTime = calendar.dateComponents([.hour, .minute], from: dive.startTime)
        if let hour = lastDiveTime.hour, let minute = lastDiveTime.minute {
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = hour
            components.minute = minute
            if let adjustedDate = calendar.date(from: components) {
                diveDate = adjustedDate
            }
        }
    }
    
    public func useCurrentLocation() async {
        do {
            let location = try await locationService.getCurrentLocation()
            
            // Find nearest dive site
            let nearestSite = await findNearestSite(to: location)
            if let site = nearestSite {
                selectedSite = site
                applySmartDefaults(for: site)
            }
        } catch {
            print("Failed to get location: \(error)")
        }
    }
    
    // MARK: - Smart Defaults
    
    private func applySmartDefaults(for site: DiveSite) {
        // Apply site-specific defaults
        if site.averageDepth > 0 {
            maxDepth = site.averageDepth
        }
        
        // Apply seasonal defaults
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: // Winter
            waterTemp = 22
        case 3, 4, 5: // Spring
            waterTemp = 25
        case 6, 7, 8: // Summer
            waterTemp = 28
        case 9, 10, 11: // Fall
            waterTemp = 26
        default:
            waterTemp = 26
        }
        
        // Default visibility based on site type
        switch site.type {
        case .reef:
            visibility = 20
        case .wall:
            visibility = 25
        case .wreck:
            visibility = 15
        case .shore:
            visibility = 10
        default:
            visibility = 15
        }
    }
    
    private func applyLocationBasedDefaults() async {
        // Try to detect patterns from previous dives at similar times
        do {
            let allDives = try await diveRepository.getAllDives()
            let calendar = Calendar.current
            let currentHour = calendar.component(.hour, from: Date())
            
            // Find dives at similar time of day
            let similarTimeDives = allDives.filter { dive in
                let diveHour = calendar.component(.hour, from: dive.startTime)
                return abs(diveHour - currentHour) <= 2
            }
            
            if !similarTimeDives.isEmpty {
                // Calculate averages
                let avgDepth = similarTimeDives.map(\.maxDepth).reduce(0, +) / Double(similarTimeDives.count)
                let avgTime = similarTimeDives.map(\.bottomTime).reduce(0, +) / similarTimeDives.count
                
                maxDepth = round(avgDepth)
                bottomTime = avgTime
            }
        } catch {
            print("Failed to apply location defaults: \(error)")
        }
    }
    
    // MARK: - Data Loading
    
    private func loadLastDive() async {
        do {
            let dives = try await diveRepository.fetchRecent(limit: 1)
            lastDive = dives.first
            hasLastDive = lastDive != nil
        } catch {
            print("Failed to load last dive: \(error)")
        }
    }
    
    private func loadNearbySites() async {
        guard let location = locationService.currentLocation else { return }
        
        do {
            let allSites = try await siteRepository.getAllSites()
            
            // Sort by distance
            nearbySites = allSites.sorted { site1, site2 in
                let loc1 = CLLocation(latitude: site1.latitude, longitude: site1.longitude)
                let loc2 = CLLocation(latitude: site2.latitude, longitude: site2.longitude)
                return location.distance(from: loc1) < location.distance(from: loc2)
            }
        } catch {
            print("Failed to load nearby sites: \(error)")
        }
    }
    
    private func findNearestSite(to location: CLLocation) async -> DiveSite? {
        if nearbySites.isEmpty {
            await loadNearbySites()
        }
        
        // Return closest site within 1km
        for site in nearbySites {
            let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
            let distance = location.distance(from: siteLocation)
            if distance <= 1000 { // Within 1km
                return site
            }
        }
        
        return nil
    }
    
    // MARK: - Save
    
    public var canSave: Bool {
        selectedSite != nil && maxDepth > 0 && bottomTime > 0
    }
    
    public var saveButtonTitle: String {
        let timeAgo = abs(diveDate.timeIntervalSinceNow)
        if timeAgo < 3600 { // Within last hour
            return "Log Dive"
        } else {
            return "Log Past Dive"
        }
    }
    
    public func saveDive() async -> Bool {
        guard canSave, let site = selectedSite else {
            errorMessage = "Please select a dive site and enter depth/time"
            showingError = true
            return false
        }
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            // Calculate end time
            let endTime = diveDate.addingTimeInterval(Double(bottomTime) * 60)
            
            // Create dive log
            let dive = DiveLog(
                id: UUID().uuidString,
                diveNumber: try await getNextDiveNumber(),
                date: diveDate,
                startTime: diveDate,
                endTime: endTime,
                bottomTime: bottomTime,
                maxDepth: maxDepth,
                averageDepth: maxDepth * 0.7, // Estimate
                waterTemp: waterTemp ?? 26,
                visibility: visibility ?? 15,
                startPressure: 200,
                endPressure: 50,
                gasType: "Air",
                notes: notes,
                buddy: buddy.isEmpty ? nil : buddy,
                siteId: site.id,
                verified: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // Save to database
            try await diveRepository.create(dive)
            
            // Update site visited count
            var updatedSite = site
            try await database.write { db in
                updatedSite = DiveSite(
                    id: site.id,
                    name: site.name,
                    location: site.location,
                    latitude: site.latitude,
                    longitude: site.longitude,
                    region: site.region,
                    averageDepth: site.averageDepth,
                    maxDepth: site.maxDepth,
                    averageTemp: site.averageTemp,
                    averageVisibility: site.averageVisibility,
                    difficulty: site.difficulty,
                    type: site.type,
                    description: site.description,
                    wishlist: false, // No longer wishlist if we dove there
                    visitedCount: site.visitedCount + 1,
                    createdAt: site.createdAt
                )
                try updatedSite.update(db)
            }
            
            // Post notification for map update
            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
            
            return true
            
        } catch {
            errorMessage = "Failed to save dive: \(error.localizedDescription)"
            showingError = true
            return false
        }
    }
    
    private func getNextDiveNumber() async throws -> Int {
        let allDives = try await diveRepository.getAllDives()
        let maxNumber = allDives.map(\.diveNumber).max() ?? 0
        return maxNumber + 1
    }
}

// MARK: - Quick Log Entry Point

import SwiftUI

public struct QuickLogButton: View {
    @State private var showingQuickLog = false
    let suggestedSite: DiveSite?
    
    public init(suggestedSite: DiveSite? = nil) {
        self.suggestedSite = suggestedSite
    }
    
    public var body: some View {
        Button(action: { showingQuickLog = true }) {
            Label("Quick Log", systemImage: "plus.circle.fill")
        }
        .sheet(isPresented: $showingQuickLog) {
            QuickLogView(suggestedSite: suggestedSite)
        }
    }
}