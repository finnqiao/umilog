import Foundation
import Combine
import CoreLocation
import UmiDB
import UmiLocationKit
import UmiCoreKit
import os

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

    // v6: GPS draft logging support
    @Published public var gpsLatitude: Double?
    @Published public var gpsLongitude: Double?
    @Published public var gpsLocationName: String?
    @Published public var isUsingGPS = false

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
            if let siteId = dive.siteId, let site = try? siteRepository.fetch(id: siteId) {
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
        } catch let error as LocationError {
            Log.location.error("Failed to get location: \(error.localizedDescription)")
            if case .permissionDenied = error {
                NotificationCenter.default.post(name: .locationPermissionDenied, object: nil)
            } else {
                errorMessage = error.localizedDescription
                showingError = true
            }
        } catch {
            Log.location.error("Failed to get location: \(error.localizedDescription)")
            errorMessage = "Failed to get location"
            showingError = true
        }
    }

    /// Use current GPS coordinates without requiring a known site.
    /// This enables draft logging at new/unknown dive sites.
    public func useGPSCoordinates() async {
        do {
            let location = try await locationService.getCurrentLocation()

            // Clear any selected site
            selectedSite = nil
            isUsingGPS = true

            // Store GPS coordinates
            gpsLatitude = location.coordinate.latitude
            gpsLongitude = location.coordinate.longitude

            // Attempt reverse geocoding for display name
            await reverseGeocode(location: location)
        } catch {
            errorMessage = "Failed to get location: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func reverseGeocode(location: CLLocation) async {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                if let locality = placemark.locality {
                    components.append(locality)
                }
                if let administrativeArea = placemark.administrativeArea {
                    components.append(administrativeArea)
                }
                if let country = placemark.country {
                    components.append(country)
                }
                gpsLocationName = components.isEmpty ? nil : "Near " + components.joined(separator: ", ")
            }
        } catch {
            // Geocoding failed - that's okay, just use coordinates
            gpsLocationName = nil
        }
    }

    /// Clear GPS and return to site selection mode.
    public func clearGPS() {
        gpsLatitude = nil
        gpsLongitude = nil
        gpsLocationName = nil
        isUsingGPS = false
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
            Log.diveLog.debug("Failed to apply location defaults: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Loading
    
    private func loadLastDive() async {
        do {
            let dives = try diveRepository.fetchRecent(limit: 1)
            lastDive = dives.first
            hasLastDive = lastDive != nil
        } catch {
            Log.diveLog.debug("Failed to load last dive: \(error.localizedDescription)")
        }
    }
    
    private func loadNearbySites() async {
        guard let location = locationService.currentLocation else { return }
        
        do {
            let allSites = try siteRepository.fetchAll()
            
            // Sort by distance
            nearbySites = allSites.sorted { site1, site2 in
                let loc1 = CLLocation(latitude: site1.latitude, longitude: site1.longitude)
                let loc2 = CLLocation(latitude: site2.latitude, longitude: site2.longitude)
                return location.distance(from: loc1) < location.distance(from: loc2)
            }
        } catch {
            Log.map.debug("Failed to load nearby sites: \(error.localizedDescription)")
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
        let hasLocation = selectedSite != nil || (gpsLatitude != nil && gpsLongitude != nil)
        return hasLocation && maxDepth > 0 && bottomTime > 0
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
        let result = await saveDiveWithResult()
        return result != nil
    }

    /// Save dive and return the dive ID if successful (for GPS draft flow)
    public func saveDiveWithResult() async -> String? {
        guard canSave else {
            errorMessage = "Please select a dive site or use GPS, and enter depth/time"
            showingError = true
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        do {
            // Calculate end time
            let endTime = diveDate.addingTimeInterval(Double(bottomTime) * 60)

            let diveId = UUID().uuidString

            // Create dive log with either site or GPS coordinates
            let dive = DiveLog(
                id: diveId,
                siteId: selectedSite?.id,
                pendingLatitude: selectedSite == nil ? gpsLatitude : nil,
                pendingLongitude: selectedSite == nil ? gpsLongitude : nil,
                date: diveDate,
                startTime: diveDate,
                endTime: endTime,
                maxDepth: maxDepth,
                averageDepth: maxDepth * 0.7, // Estimate
                bottomTime: bottomTime,
                startPressure: 200,
                endPressure: 50,
                temperature: waterTemp ?? 26,
                visibility: visibility ?? 15,
                notes: notes,
                signed: false,
                createdAt: Date(),
                updatedAt: Date()
            )

            // Save to database
            try diveRepository.create(dive)

            // Update site visited count if we have a site
            if let site = selectedSite {
                try database.write { db in
                    let updatedSite = DiveSite(
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
                        isPlanned: site.isPlanned,
                        visitedCount: site.visitedCount + 1,
                        createdAt: site.createdAt,
                        countryId: site.countryId,
                        regionId: site.regionId,
                        areaId: site.areaId,
                        wikidataId: site.wikidataId,
                        osmId: site.osmId
                    )
                    try updatedSite.update(db)
                }
            }

            // Post notification for map update
            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)

            return diveId

        } catch {
            errorMessage = "Failed to save dive: \(error.localizedDescription)"
            showingError = true
            return nil
        }
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