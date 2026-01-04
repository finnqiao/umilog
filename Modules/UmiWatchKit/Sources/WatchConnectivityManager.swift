import Foundation
import WatchConnectivity
import os

/// Manages WatchConnectivity session with paired Apple Watch
@MainActor
public final class WatchConnectivityManager: NSObject, ObservableObject {
    private static let logger = Logger(subsystem: "app.umilog", category: "WatchConnectivity")

    public static let shared = WatchConnectivityManager()

    // MARK: - Published State

    @Published public private(set) var isPaired: Bool = false
    @Published public private(set) var isReachable: Bool = false
    @Published public private(set) var isWatchAppInstalled: Bool = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var connectionState: ConnectionState = .unknown

    // MARK: - State

    public enum ConnectionState: String {
        case unknown = "Unknown"
        case notSupported = "Not Supported"
        case inactive = "Inactive"
        case activated = "Connected"
        case notPaired = "Not Paired"
    }

    // MARK: - Callbacks

    public var onDiveReceived: ((DivePayload) -> Void)?
    public var onSyncRequested: (() -> Void)?

    // MARK: - Private

    private var session: WCSession?

    private override init() {
        super.init()

        guard WCSession.isSupported() else {
            Self.logger.info("WatchConnectivity not supported on this device")
            connectionState = .notSupported
            return
        }

        session = WCSession.default
        session?.delegate = self
    }

    // MARK: - Public Methods

    public func activate() {
        guard let session = session else {
            Self.logger.warning("Cannot activate - WCSession not available")
            return
        }

        Self.logger.info("Activating WCSession...")
        session.activate()
    }

    /// Send dive data to Watch
    public func sendDives(_ dives: [DivePayload]) {
        guard let session = session, session.isReachable else {
            Self.logger.warning("Watch not reachable, cannot send dives")
            return
        }

        let payload: [String: Any] = [
            "type": "dives",
            "dives": dives.map { $0.toDictionary() },
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(payload, replyHandler: { reply in
            Self.logger.info("Dives sent successfully, reply: \(reply)")
            Task { @MainActor in
                self.lastSyncDate = Date()
            }
        }, errorHandler: { error in
            Self.logger.error("Failed to send dives: \(error.localizedDescription)")
        })
    }

    /// Request sync from Watch
    public func requestSync() {
        guard let session = session, session.isReachable else {
            Self.logger.warning("Watch not reachable, cannot request sync")
            return
        }

        let payload: [String: Any] = [
            "type": "syncRequest",
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(payload, replyHandler: { reply in
            Self.logger.info("Sync request sent, reply: \(reply)")
        }, errorHandler: { error in
            Self.logger.error("Failed to request sync: \(error.localizedDescription)")
        })
    }

    /// Transfer user info for background updates
    public func transferUserInfo(_ info: [String: Any]) {
        guard let session = session else { return }
        session.transferUserInfo(info)
        Self.logger.info("Transferred user info to Watch")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                Self.logger.error("WCSession activation failed: \(error.localizedDescription)")
                connectionState = .inactive
                return
            }

            switch activationState {
            case .activated:
                Self.logger.info("WCSession activated")
                connectionState = .activated
                isPaired = session.isPaired
                isWatchAppInstalled = session.isWatchAppInstalled
                isReachable = session.isReachable
            case .inactive:
                connectionState = .inactive
            case .notActivated:
                connectionState = .unknown
            @unknown default:
                connectionState = .unknown
            }

            if !session.isPaired {
                connectionState = .notPaired
            }
        }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            Self.logger.info("WCSession became inactive")
            connectionState = .inactive
        }
    }

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            Self.logger.info("WCSession deactivated")
            connectionState = .unknown
        }
        // Reactivate for switching watches
        session.activate()
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            Self.logger.info("Watch reachability changed: \(session.isReachable)")
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleMessage(message)
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            handleMessage(message)
            replyHandler(["status": "received"])
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            handleMessage(userInfo)
        }
    }
}

// MARK: - Message Handling

extension WatchConnectivityManager {
    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            Self.logger.warning("Received message without type")
            return
        }

        switch type {
        case "dive":
            if let diveData = message["dive"] as? [String: Any],
               let payload = DivePayload.from(diveData) {
                Self.logger.info("Received dive from Watch")
                onDiveReceived?(payload)
            }

        case "syncRequest":
            Self.logger.info("Watch requested sync")
            onSyncRequested?()

        default:
            Self.logger.info("Received unknown message type: \(type)")
        }
    }
}

// MARK: - Dive Payload

/// Lightweight dive data for Watch transfer
public struct DivePayload: Codable {
    public let id: String
    public let date: Date
    public let siteName: String?
    public let maxDepth: Double
    public let bottomTime: Int
    public let temperature: Double?

    public init(
        id: String,
        date: Date,
        siteName: String?,
        maxDepth: Double,
        bottomTime: Int,
        temperature: Double?
    ) {
        self.id = id
        self.date = date
        self.siteName = siteName
        self.maxDepth = maxDepth
        self.bottomTime = bottomTime
        self.temperature = temperature
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "date": date.timeIntervalSince1970,
            "maxDepth": maxDepth,
            "bottomTime": bottomTime
        ]
        if let siteName = siteName { dict["siteName"] = siteName }
        if let temperature = temperature { dict["temperature"] = temperature }
        return dict
    }

    static func from(_ dict: [String: Any]) -> DivePayload? {
        guard let id = dict["id"] as? String,
              let dateTimestamp = dict["date"] as? TimeInterval,
              let maxDepth = dict["maxDepth"] as? Double,
              let bottomTime = dict["bottomTime"] as? Int else {
            return nil
        }

        return DivePayload(
            id: id,
            date: Date(timeIntervalSince1970: dateTimestamp),
            siteName: dict["siteName"] as? String,
            maxDepth: maxDepth,
            bottomTime: bottomTime,
            temperature: dict["temperature"] as? Double
        )
    }
}
