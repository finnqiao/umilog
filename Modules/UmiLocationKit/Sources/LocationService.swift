import Foundation
import CoreLocation
import Combine
import UIKit
import UmiCoreKit

/// Main location service handling permissions and location updates
@MainActor
public final class LocationService: NSObject, ObservableObject {
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation?
    @Published public var isUpdatingLocation: Bool = false
    @Published public var lastError: LocationError?
    
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoringSignificantChanges = false
    private var shouldResumeStandardUpdatesOnForeground = false
    
    public static let shared = LocationService()
    
    override private init() {
        super.init()
        setupLocationManager()
        setupLifecycleBindings()
        setupPowerBindings()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        locationManager.pausesLocationUpdatesAutomatically = true
        // Background updates not needed - geofencing works with WhenInUse while app is active

        authorizationStatus = locationManager.authorizationStatus
        applyPowerPolicy(PowerManager.shared.performancePolicy)
    }
    
    // MARK: - Public Methods
    
    public func requestPermission() {
        requestLocationWhenNeeded()
    }

    /// Requests location permission only when the user takes a location-dependent action.
    public func requestLocationWhenNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    /// Requests Always authorization only when a user enables a feature that needs it.
    public func requestAlwaysPermissionWhenNeeded() {
        guard authorizationStatus == .authorizedWhenInUse else { return }
        locationManager.requestAlwaysAuthorization()
    }
    
    public func startLocationUpdates() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            lastError = .permissionDenied
            return
        }
        
        isUpdatingLocation = true
        if isMonitoringSignificantChanges {
            switchToStandardMonitoring()
        } else {
            locationManager.startUpdatingLocation()
        }
        applyPowerPolicy(PowerManager.shared.performancePolicy)

        if UIApplication.shared.applicationState != .active,
           PowerManager.shared.shouldUseSignificantChangeWhenBackgrounded {
            switchToSignificantChangeMonitoring()
            shouldResumeStandardUpdatesOnForeground = true
        }
    }
    
    public func stopLocationUpdates() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = false
        shouldResumeStandardUpdatesOnForeground = false
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            throw LocationError.permissionDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    /// Get distance between two locations in kilometers
    public func distance(from: CLLocation, to: CLLocation) -> Double {
        from.distance(from: to) / 1000.0
    }
    
    /// Check if location is near a dive site (within radius)
    public func isNearDiveSite(location: CLLocation, site: CLLocationCoordinate2D, radiusKm: Double = 0.5) -> Bool {
        let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
        return distance(from: location, to: siteLocation) <= radiusKm
    }

    public func reduceAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = max(500, PowerManager.shared.locationDistanceFilterMeters)
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
    }

    public func restoreAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
        locationManager.pausesLocationUpdatesAutomatically = true
    }

    /// Uses lower-power significant-change monitoring while backgrounded.
    public func switchToSignificantChangeMonitoring() {
        guard !isMonitoringSignificantChanges else { return }
        locationManager.stopUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = true
    }

    public func switchToStandardMonitoring() {
        if isMonitoringSignificantChanges {
            locationManager.stopMonitoringSignificantLocationChanges()
            isMonitoringSignificantChanges = false
        }
        if isUpdatingLocation {
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - Private Helpers

    private func setupLifecycleBindings() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleWillEnterForeground()
            }
            .store(in: &cancellables)
    }

    private func setupPowerBindings() {
        PowerManager.shared.$performancePolicy
            .receive(on: RunLoop.main)
            .sink { [weak self] policy in
                self?.applyPowerPolicy(policy)
            }
            .store(in: &cancellables)
    }

    private func applyPowerPolicy(_ policy: PowerManager.PerformancePolicy) {
        switch policy {
        case .standard:
            restoreAccuracy()
        case .boatMode, .thermalThrottled, .critical:
            reduceAccuracy()
        }
    }

    private func handleDidEnterBackground() {
        guard isUpdatingLocation else { return }
        if PowerManager.shared.shouldUseSignificantChangeWhenBackgrounded {
            switchToSignificantChangeMonitoring()
            shouldResumeStandardUpdatesOnForeground = true
        }
    }

    private func handleWillEnterForeground() {
        guard isUpdatingLocation else { return }
        if shouldResumeStandardUpdatesOnForeground || isMonitoringSignificantChanges {
            switchToStandardMonitoring()
            shouldResumeStandardUpdatesOnForeground = false
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Both permission levels work for foreground geofencing
            startLocationUpdates()
        case .denied, .restricted:
            lastError = .permissionDenied
            stopLocationUpdates()
        default:
            break
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        
        // If we have a continuation waiting, fulfill it
        if let continuation = locationContinuation {
            continuation.resume(returning: location)
            locationContinuation = nil
        }
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .locationUpdated,
            object: nil,
            userInfo: ["location": location]
        )
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                lastError = .permissionDenied
            case .locationUnknown:
                lastError = .locationUnavailable
            default:
                lastError = .systemError(error)
            }
        } else {
            lastError = .systemError(error)
        }
        
        // If we have a continuation waiting, fail it
        if let continuation = locationContinuation {
            continuation.resume(throwing: lastError ?? LocationError.unknown)
            locationContinuation = nil
        }
    }
}

// MARK: - Error Types

public enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case systemError(Error)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied. Please enable in Settings."
        case .locationUnavailable:
            return "Unable to determine current location."
        case .systemError(let error):
            return error.localizedDescription
        case .unknown:
            return "An unknown location error occurred."
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    // Namespaced to prevent cross-app notification conflicts
    public static let locationUpdated = Notification.Name("app.umilog.locationUpdated")
    public static let locationPermissionDenied = Notification.Name("app.umilog.locationPermissionDenied")
}
