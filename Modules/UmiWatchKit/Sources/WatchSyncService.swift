import Foundation
import UmiDB
import UmiCoreKit
import os

/// Handles syncing dive data between iPhone and Apple Watch
@MainActor
public final class WatchSyncService: ObservableObject {
    private static let logger = Logger(subsystem: "app.umilog", category: "WatchSyncService")

    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastError: String?

    private let connectivityManager: WatchConnectivityManager
    private let diveRepository: DiveRepository
    private let siteRepository: SiteRepository

    public init(
        connectivityManager: WatchConnectivityManager = .shared,
        diveRepository: DiveRepository = DiveRepository(database: AppDatabase.shared),
        siteRepository: SiteRepository = SiteRepository(database: AppDatabase.shared)
    ) {
        self.connectivityManager = connectivityManager
        self.diveRepository = diveRepository
        self.siteRepository = siteRepository

        setupCallbacks()
    }

    private func setupCallbacks() {
        connectivityManager.onDiveReceived = { [weak self] payload in
            Task { @MainActor in
                await self?.handleReceivedDive(payload)
            }
        }

        connectivityManager.onSyncRequested = { [weak self] in
            Task { @MainActor in
                await self?.syncDivesToWatch()
            }
        }
    }

    // MARK: - Public Methods

    /// Activate Watch connectivity
    public func activate() {
        connectivityManager.activate()
    }

    /// Sync recent dives to Watch
    public func syncDivesToWatch() async {
        guard connectivityManager.isReachable else {
            Self.logger.warning("Watch not reachable, cannot sync")
            lastError = "Watch not reachable"
            return
        }

        isSyncing = true
        lastError = nil

        do {
            // Get recent dives (last 20)
            let dives = try diveRepository.fetchRecent(limit: 20)

            // Convert to payloads with site names
            var payloads: [DivePayload] = []
            for dive in dives {
                var siteName: String?
                if let siteId = dive.siteId {
                    siteName = try? siteRepository.fetch(id: siteId)?.name
                }

                payloads.append(DivePayload(
                    id: dive.id,
                    date: dive.date,
                    siteName: siteName,
                    maxDepth: dive.maxDepth,
                    bottomTime: dive.bottomTime,
                    temperature: dive.temperature
                ))
            }

            // Send to Watch
            connectivityManager.sendDives(payloads)
            Self.logger.info("Synced \(payloads.count) dives to Watch")

        } catch {
            Self.logger.error("Failed to sync dives: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }

        isSyncing = false
    }

    /// Handle dive received from Watch
    private func handleReceivedDive(_ payload: DivePayload) async {
        Self.logger.info("Processing dive from Watch: \(payload.id)")

        // Check for duplicates
        do {
            if try diveRepository.hasDuplicate(date: payload.date, maxDepth: payload.maxDepth) {
                Self.logger.info("Dive already exists, skipping")
                return
            }

            // Create dive log from payload
            let dive = DiveLog(
                id: payload.id,
                siteId: nil, // Will need site matching in future
                date: payload.date,
                startTime: payload.date,
                endTime: payload.date.addingTimeInterval(TimeInterval(payload.bottomTime * 60)),
                maxDepth: payload.maxDepth,
                bottomTime: payload.bottomTime,
                startPressure: 200,
                endPressure: 50,
                temperature: payload.temperature ?? 26.0,
                visibility: 15.0,
                notes: "Logged from Apple Watch"
            )

            try diveRepository.create(dive)
            Self.logger.info("Saved dive from Watch: \(payload.id)")

            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)

        } catch {
            Self.logger.error("Failed to save Watch dive: \(error.localizedDescription)")
        }
    }
}
