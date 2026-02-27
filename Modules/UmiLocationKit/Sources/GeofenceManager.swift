import Foundation
import CoreLocation
import Combine
import UmiDB
import UmiCoreKit
import os

/// Manages geofences around dive sites for automatic detection
@MainActor
public final class GeofenceManager: NSObject, ObservableObject {
    @Published public var monitoredRegions: Set<CLRegion> = []
    @Published public var currentDiveSite: DiveSite?
    @Published public var isAtDiveSite: Bool = false
    @Published public var lastEntryTime: Date?
    
    private let locationManager = CLLocationManager()
    private let siteRepository: SiteRepository
    private let database: AppDatabase
    private var cancellables = Set<AnyCancellable>()
    private var consecutiveUpdateFailures: Int = 0
    private var consecutiveSlowUpdates: Int = 0
    private var shouldStartMonitoringAfterAuthorization = false
    
    // Maximum number of regions iOS allows us to monitor
    private let maxMonitoredRegions = 20
    
    public static let shared = GeofenceManager()
    
    override private init() {
        self.database = AppDatabase.shared
        self.siteRepository = SiteRepository(database: database)
        super.init()
        setupLocationManager()
        setupBindings()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func setupBindings() {
        // Listen for location updates to refresh nearby geofences
        NotificationCenter.default
            .publisher(for: .locationUpdated)
            .throttle(for: .seconds(60), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] notification in
                if let location = notification.userInfo?["location"] as? CLLocation {
                    Task {
                        await self?.updateGeofences(around: location)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    public func startMonitoring(requestPermissionsIfNeeded: Bool = false) {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            guard requestPermissionsIfNeeded else { return }
            shouldStartMonitoringAfterAuthorization = true
            locationManager.requestWhenInUseAuthorization()
            return
        case .denied, .restricted:
            Log.location.warning("Location permission denied - geofence monitoring disabled")
            return
        @unknown default:
            return
        }

        // Start with current location if available
        if let location = locationManager.location {
            Task {
                await updateGeofences(around: location)
            }
        }
    }

    private func ensureNotificationAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            Log.location.warning("Notification permission denied - dive reminders unavailable")
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    setupNotificationCategories()
                }
                return granted
            } catch {
                Log.location.error("Failed to request notification permission: \(error.localizedDescription)")
                return false
            }
        @unknown default:
            return false
        }
    }
    
    public func stopMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredRegions.removeAll()
    }
    
    /// Update geofences to monitor nearest dive sites
    public func updateGeofences(around location: CLLocation) async {
        let startedAt = Date()
        do {
            // Fetch nearby sites
            let nearbySites = try await fetchNearbySites(
                location: location,
                radiusKm: 50 // 50km radius
            )
            
            // Stop monitoring far away regions
            stopMonitoringDistantRegions(from: location)
            
            // Start monitoring new nearby regions
            let sitesToMonitor = Array(nearbySites.prefix(maxMonitoredRegions))
            for site in sitesToMonitor {
                addGeofence(for: site)
            }

            consecutiveUpdateFailures = 0
            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed > 2.0 {
                consecutiveSlowUpdates += 1
                Log.location.warning("Slow geofence update (\(elapsed, privacy: .public)s)")
                if consecutiveSlowUpdates >= AppConstants.LaunchStability.viewportSlowQueryEscalationThreshold {
                    NotificationCenter.default.post(
                        name: .launchSafeModeActivationRequested,
                        object: nil,
                        userInfo: ["reason": "geofence_slow_updates"]
                    )
                }
            } else {
                consecutiveSlowUpdates = 0
            }
        } catch {
            consecutiveUpdateFailures += 1
            Log.location.error("Failed to update geofences: \(error.localizedDescription)")
            if consecutiveUpdateFailures >= AppConstants.LaunchStability.viewportFailureEscalationThreshold {
                NotificationCenter.default.post(
                    name: .launchSafeModeActivationRequested,
                    object: nil,
                    userInfo: ["reason": "geofence_update_failures"]
                )
            }
        }
    }
    
    private func fetchNearbySites(location: CLLocation, radiusKm: Double) async throws -> [DiveSite] {
        try siteRepository.fetchNearby(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusKm: radiusKm,
            limit: maxMonitoredRegions * 2
        )
    }
    
    private func addGeofence(for site: DiveSite) {
        let identifier = "dive_site_\(site.id)"
        
        // Check if already monitoring
        if locationManager.monitoredRegions.contains(where: { $0.identifier == identifier }) {
            return
        }
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: site.latitude,
                longitude: site.longitude
            ),
            radius: 500, // 500 meter radius
            identifier: identifier
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationManager.startMonitoring(for: region)
        monitoredRegions.insert(region)
    }
    
    private func stopMonitoringDistantRegions(from location: CLLocation) {
        for region in locationManager.monitoredRegions {
            guard let circularRegion = region as? CLCircularRegion else { continue }
            
            let regionLocation = CLLocation(
                latitude: circularRegion.center.latitude,
                longitude: circularRegion.center.longitude
            )
            
            let distance = location.distance(from: regionLocation) / 1000.0
            
            // Stop monitoring if more than 100km away
            if distance > 100 {
                locationManager.stopMonitoring(for: region)
                monitoredRegions.remove(region)
            }
        }
    }
    
    /// Handle site entry/exit for auto-logging prompts
    private func handleSiteEntry(siteId: String) {
        Task {
            do {
                if let site = try database.read({ db in
                    try DiveSite.fetchOne(db, key: siteId)
                }) {
                    currentDiveSite = site
                    isAtDiveSite = true
                    lastEntryTime = Date()
                    
                    // Post notification for auto-log prompt
                    NotificationCenter.default.post(
                        name: .arrivedAtDiveSite,
                        object: nil,
                        userInfo: ["site": site]
                    )
                    
                    // Schedule a local notification
                    await scheduleAutoLogReminder(for: site)
                }
            } catch {
                Log.location.error("Failed to handle site entry: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleSiteExit(siteId: String) {
        if currentDiveSite?.id == siteId {
            // Calculate time spent at site
            let timeAtSite = lastEntryTime.map { Date().timeIntervalSince($0) } ?? 0
            
            // If spent more than 30 minutes, likely dove
            if timeAtSite > 1800 {
                Task {
                    if let site = currentDiveSite {
                        await triggerAutoLogPrompt(for: site)
                    }
                }
            }
            
            currentDiveSite = nil
            isAtDiveSite = false
            lastEntryTime = nil
        }
    }
    
    private func scheduleAutoLogReminder(for site: DiveSite) async {
        guard await ensureNotificationAuthorizationIfNeeded() else { return }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Ready to dive?"
        content.body = "You're at \(site.name). Tap to quick-log your dive!"
        content.sound = .default
        content.categoryIdentifier = "DIVE_LOG_REMINDER"
        content.userInfo = ["siteId": site.id]
        
        // Trigger in 15 minutes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "dive_reminder_\(site.id)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Log.location.error("Failed to schedule notification: \(error.localizedDescription)")
        }
    }
    
    private func triggerAutoLogPrompt(for site: DiveSite) async {
        guard await ensureNotificationAuthorizationIfNeeded() else { return }

        // Create exit notification
        let content = UNMutableNotificationContent()
        content.title = "Log your dive?"
        content.body = "Looks like you just finished diving at \(site.name)"
        content.sound = .default
        content.categoryIdentifier = "DIVE_LOG_PROMPT"
        content.userInfo = ["siteId": site.id]
        
        let request = UNNotificationRequest(
            identifier: "dive_exit_\(site.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Log.location.error("Failed to send notification: \(error.localizedDescription)")
        }
        
        // Also post app notification
        NotificationCenter.default.post(
            name: .shouldPromptDiveLog,
            object: nil,
            userInfo: ["site": site]
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceManager: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard shouldStartMonitoringAfterAuthorization else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            shouldStartMonitoringAfterAuthorization = false
            startMonitoring(requestPermissionsIfNeeded: false)
        case .denied, .restricted:
            shouldStartMonitoringAfterAuthorization = false
            Log.location.warning("Location permission denied - geofence monitoring not started")
        case .notDetermined:
            break
        @unknown default:
            shouldStartMonitoringAfterAuthorization = false
        }
    }

    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier.hasPrefix("dive_site_") else { return }
        
        let siteId = String(region.identifier.dropFirst("dive_site_".count))
        handleSiteEntry(siteId: siteId)
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier.hasPrefix("dive_site_") else { return }
        
        let siteId = String(region.identifier.dropFirst("dive_site_".count))
        handleSiteExit(siteId: siteId)
    }
    
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Log.location.error("Geofence monitoring failed: \(error.localizedDescription)")
        if let region = region {
            monitoredRegions.remove(region)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        // Request initial state
        manager.requestState(for: region)
    }
    
    public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier.hasPrefix("dive_site_") else { return }
        
        let siteId = String(region.identifier.dropFirst("dive_site_".count))
        
        switch state {
        case .inside:
            handleSiteEntry(siteId: siteId)
        case .outside:
            // Already outside, nothing to do
            break
        case .unknown:
            break
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    // Namespaced to prevent cross-app notification conflicts
    public static let arrivedAtDiveSite = Notification.Name("app.umilog.arrivedAtDiveSite")
    public static let shouldPromptDiveLog = Notification.Name("app.umilog.shouldPromptDiveLog")
}

// MARK: - Notification Helpers

import UserNotifications

extension GeofenceManager {
    public func setupNotificationCategories() {
        let logAction = UNNotificationAction(
            identifier: "LOG_DIVE",
            title: "Log Dive",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Not Now",
            options: []
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "DIVE_LOG_REMINDER",
            actions: [logAction, dismissAction],
            intentIdentifiers: []
        )
        
        let promptCategory = UNNotificationCategory(
            identifier: "DIVE_LOG_PROMPT",
            actions: [logAction, dismissAction],
            intentIdentifiers: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            reminderCategory,
            promptCategory
        ])
    }
}
