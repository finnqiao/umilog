import Foundation
import CoreLocation
import UIKit

/// Tracks the user's journey through the location permission flow
/// Allows the app to show content before requesting system permission
public enum LocationPermissionPhase: String, Codable {
    /// User hasn't seen any permission UI yet
    case initial
    /// User has seen our custom explainer but hasn't responded
    case explainerShown
    /// User has granted permission (any level)
    case granted
    /// User has denied permission
    case denied
}

/// Manages location permission state with a pre-permission explainer flow
@MainActor
public final class LocationPermissionState: ObservableObject {
    public static let shared = LocationPermissionState()

    /// Current phase in the permission flow
    @Published public private(set) var phase: LocationPermissionPhase

    /// Whether to show our custom permission explainer
    @Published public private(set) var showingExplainer: Bool = false

    /// System authorization status
    @Published public private(set) var systemStatus: CLAuthorizationStatus

    // Use lazy initialization to prevent CLLocationManager from triggering
    // any authorization-related behavior until we actually need it
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        return manager
    }()
    private let defaults = UserDefaults.standard
    private static let phaseKey = "app.umilog.locationPermissionPhase"
    private static let hasSeenExplainerKey = "app.umilog.hasSeenLocationExplainer"

    #if DEBUG
    /// Skip permission prompts in DEBUG builds when this launch argument is present
    public static var skipPermissionPrompts: Bool {
        ProcessInfo.processInfo.arguments.contains("--skip-location-prompt")
    }
    #endif

    private init() {
        // Load saved phase
        if let savedPhase = defaults.string(forKey: Self.phaseKey),
           let phase = LocationPermissionPhase(rawValue: savedPhase) {
            self.phase = phase
        } else {
            self.phase = .initial
        }

        // Start with unknown status - we'll check it lazily to avoid triggering
        // any CLLocationManager initialization side effects
        self.systemStatus = .notDetermined

        // Check actual status asynchronously after a brief delay
        // This ensures our UI is ready before any system dialogs might appear
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            self.refreshSystemStatus()
        }
    }

    /// Refresh system status from a temporary CLLocationManager
    /// Note: Guarded to prevent premature system dialog trigger in initial phase (FN-001)
    private func refreshSystemStatus() {
        // Don't touch CLLocationManager in initial phase - this can trigger
        // the system permission dialog on some iOS versions
        guard phase != .initial else {
            // Keep status as notDetermined until user interacts with our explainer
            return
        }
        let tempManager = CLLocationManager()
        systemStatus = tempManager.authorizationStatus
        syncPhaseWithSystemStatus()
    }

    /// Called when user taps "Enable Location" in our explainer
    public func userRequestedPermission() {
        phase = .explainerShown
        savePhase()
        showingExplainer = false

        // Now trigger the actual system dialog
        print("[DEBUG] userRequestedPermission() called - triggering system dialog")
        locationManager.requestWhenInUseAuthorization()
    }

    /// Called when user taps "Skip" or "Not Now" in our explainer
    public func userSkippedPermission() {
        phase = .denied
        savePhase()
        showingExplainer = false
    }

    /// Show the custom explainer if appropriate
    public func showExplainerIfNeeded() {
        #if DEBUG
        if Self.skipPermissionPrompts {
            phase = .granted
            return
        }
        #endif

        // Only show if we haven't asked before and system status is undetermined
        if phase == .initial && systemStatus == .notDetermined {
            showingExplainer = true
        }
    }

    /// Dismiss the explainer without taking action
    public func dismissExplainer() {
        showingExplainer = false
    }

    /// Whether the app can use location (granted at any level)
    public var hasLocationAccess: Bool {
        systemStatus == .authorizedWhenInUse || systemStatus == .authorizedAlways
    }

    /// Whether the user has denied location and we should show guidance
    public var showDeniedGuidance: Bool {
        systemStatus == .denied || systemStatus == .restricted
    }

    /// Open system Settings to enable location
    public func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Private

    private func savePhase() {
        defaults.set(phase.rawValue, forKey: Self.phaseKey)
    }

    private func syncPhaseWithSystemStatus() {
        switch systemStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            phase = .granted
        case .denied, .restricted:
            if phase != .initial {
                phase = .denied
            }
        case .notDetermined:
            // Keep current phase (could be initial or explainerShown)
            break
        @unknown default:
            break
        }
        savePhase()
    }

    @objc private func handleAuthorizationChange() {
        Task { @MainActor in
            systemStatus = locationManager.authorizationStatus
            syncPhaseWithSystemStatus()
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension LocationPermissionState {
    /// Reset permission state for testing
    public func resetForTesting() {
        defaults.removeObject(forKey: Self.phaseKey)
        defaults.removeObject(forKey: Self.hasSeenExplainerKey)
        phase = .initial
        showingExplainer = false
    }
}
#endif
