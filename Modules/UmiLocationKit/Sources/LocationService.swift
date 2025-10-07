import Foundation
import CoreLocation
import Combine

/// Main location service handling permissions and location updates
@MainActor
public final class LocationService: NSObject, ObservableObject {
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation?
    @Published public var isUpdatingLocation: Bool = false
    @Published public var lastError: LocationError?
    
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    public static let shared = LocationService()
    
    override private init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true
        
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    public func requestPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            // Upgrade to always if needed for geofencing
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }
    
    public func startLocationUpdates() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            lastError = .permissionDenied
            return
        }
        
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    public func stopLocationUpdates() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
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
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
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
    public static let locationUpdated = Notification.Name("locationUpdated")
}