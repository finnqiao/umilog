import Foundation
import Combine

/// Centralized power policy used by map/location features.
/// This keeps Boat Mode and thermal throttling consistent across modules.
@MainActor
public final class PowerManager: ObservableObject {
    public enum PerformancePolicy: String {
        case standard
        case boatMode
        case thermalThrottled
        case critical
    }

    public static let shared = PowerManager()

    @Published public private(set) var isBoatModeEnabled: Bool
    @Published public private(set) var thermalState: ProcessInfo.ThermalState
    @Published public private(set) var isLowPowerModeEnabled: Bool
    @Published public private(set) var performancePolicy: PerformancePolicy

    private let defaults: UserDefaults
    private let processInfo: ProcessInfo
    private var thermalObserver: NSObjectProtocol?
    private var lowPowerObserver: NSObjectProtocol?

    private init(
        defaults: UserDefaults = .standard,
        processInfo: ProcessInfo = .processInfo
    ) {
        self.defaults = defaults
        self.processInfo = processInfo
        self.isBoatModeEnabled = defaults.bool(forKey: AppConstants.UserDefaultsKeys.boatModeEnabled)
        self.thermalState = processInfo.thermalState
        self.isLowPowerModeEnabled = processInfo.isLowPowerModeEnabled
        self.performancePolicy = .standard
        self.performancePolicy = computePolicy()
        startMonitoringSystemState()
    }

    deinit {
        if let thermalObserver {
            NotificationCenter.default.removeObserver(thermalObserver)
        }
        if let lowPowerObserver {
            NotificationCenter.default.removeObserver(lowPowerObserver)
        }
    }

    public func setBoatModeEnabled(_ enabled: Bool) {
        guard isBoatModeEnabled != enabled else { return }
        isBoatModeEnabled = enabled
        defaults.set(enabled, forKey: AppConstants.UserDefaultsKeys.boatModeEnabled)
        recalculatePolicy()
    }

    public func toggleBoatMode() {
        setBoatModeEnabled(!isBoatModeEnabled)
    }

    public var preferredMapFramesPerSecond: Int {
        switch performancePolicy {
        case .standard:
            return 60
        case .boatMode:
            return 30
        case .thermalThrottled:
            return 24
        case .critical:
            return 15
        }
    }

    public var shouldHideMapCompass: Bool {
        performancePolicy != .standard
    }

    public var locationDistanceFilterMeters: Double {
        switch performancePolicy {
        case .standard:
            return 50
        case .boatMode:
            return 500
        case .thermalThrottled:
            return 750
        case .critical:
            return 1_000
        }
    }

    public var shouldUseReducedLocationAccuracy: Bool {
        performancePolicy != .standard
    }

    public var shouldUseSignificantChangeWhenBackgrounded: Bool {
        performancePolicy != .standard
    }

    public var imagePrefetchLimit: Int {
        switch performancePolicy {
        case .standard:
            return 50
        case .boatMode:
            return 20
        case .thermalThrottled:
            return 10
        case .critical:
            return 0
        }
    }

    // MARK: - Private

    private func startMonitoringSystemState() {
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.thermalState = self.processInfo.thermalState
            self.recalculatePolicy()
        }

        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isLowPowerModeEnabled = self.processInfo.isLowPowerModeEnabled
            self.recalculatePolicy()
        }
    }

    private func recalculatePolicy() {
        performancePolicy = computePolicy()
    }

    private func computePolicy() -> PerformancePolicy {
        switch processInfo.thermalState {
        case .critical:
            return .critical
        case .serious:
            return .thermalThrottled
        case .fair, .nominal:
            if isBoatModeEnabled || processInfo.isLowPowerModeEnabled {
                return .boatMode
            }
            return .standard
        @unknown default:
            return isBoatModeEnabled ? .boatMode : .standard
        }
    }
}
