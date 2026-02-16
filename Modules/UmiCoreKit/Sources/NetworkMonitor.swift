import Foundation
import Network
import Combine

/// Monitors network connectivity and publishes status changes.
/// Uses NWPathMonitor from the Network framework.
@MainActor
public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()

    /// Current connectivity status
    @Published public private(set) var isConnected: Bool = true

    /// Current connection type
    @Published public private(set) var connectionType: ConnectionType = .unknown

    /// Whether the connection is expensive (cellular)
    @Published public private(set) var isExpensive: Bool = false

    /// Whether the connection is constrained (low data mode)
    @Published public private(set) var isConstrained: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.umilog.networkmonitor")

    public enum ConnectionType: String {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained

                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .unknown
                }

                // Log state changes
                if wasConnected != self.isConnected {
                    Log.network.info("Network status changed: \(self.isConnected ? "connected" : "disconnected")")

                    // Post notification for non-SwiftUI observers
                    NotificationCenter.default.post(
                        name: .networkStatusChanged,
                        object: self.isConnected
                    )
                }
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
