import Foundation
import MapLibre
import os
import Combine

private let logger = Logger(subsystem: "app.umilog", category: "OfflineTiles")

/// Status of an individual offline tile pack.
public enum OfflinePackStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case paused
    case complete(sizeMB: Double, downloadedAt: Date)
    case error(String)
}

/// Snapshot of a downloaded or in-progress pack.
public struct OfflinePackInfo: Identifiable, Equatable {
    public let id: String  // region id
    public let region: OfflineRegion
    public let status: OfflinePackStatus
}

/// Manages downloading, pausing, resuming, and deleting MapLibre offline tile packs.
/// Each pack corresponds to an `OfflineRegion` bounding box.
@Observable
public final class OfflineTilePackManager {
    public static let shared = OfflineTilePackManager()

    // MARK: - Published State

    public private(set) var packs: [OfflinePackInfo] = []
    public private(set) var totalStorageUsedMB: Double = 0

    // MARK: - Private

    private let storage = MLNOfflineStorage.shared
    private let metadataKey = "umilog-region-id"
    private var observationTokens: [NSObjectProtocol] = []

    private init() {
        observeProgress()
        refreshPacks()
    }

    deinit {
        for token in observationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Public API

    /// Builds the pack list by merging all predefined regions with any existing downloads.
    public func refreshPacks() {
        let existingPacks = storage.packs ?? []
        var infos: [OfflinePackInfo] = []
        var totalBytes: UInt64 = 0

        for region in OfflineRegion.allRegions {
            if let mlnPack = existingPacks.first(where: { regionId(for: $0) == region.id }) {
                let status = packStatus(for: mlnPack)
                infos.append(OfflinePackInfo(id: region.id, region: region, status: status))
                totalBytes += mlnPack.progress.countOfBytesCompleted
            } else {
                infos.append(OfflinePackInfo(id: region.id, region: region, status: .notDownloaded))
            }
        }

        packs = infos
        totalStorageUsedMB = Double(totalBytes) / 1_048_576
    }

    /// Start downloading tiles for a region.
    public func download(region: OfflineRegion, styleURL: URL) {
        let tileRegion = MLNTilePyramidOfflineRegion(
            styleURL: styleURL,
            bounds: region.bounds,
            fromZoomLevel: region.minZoom,
            toZoomLevel: region.maxZoom
        )

        let metadata: [String: String] = [metadataKey: region.id]
        guard let contextData = try? JSONEncoder().encode(metadata) else {
            logger.error("offline_download_failed: cannot encode metadata for \(region.id, privacy: .public)")
            return
        }

        storage.addPack(for: tileRegion, withContext: contextData) { [weak self] pack, error in
            if let error {
                logger.error("offline_download_failed: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("offline_download_started: \(region.id, privacy: .public)")
                pack?.resume()
            }
            self?.refreshPacks()
        }
    }

    /// Pause an in-progress download.
    public func pause(regionId: String) {
        guard let pack = mlnPack(for: regionId) else { return }
        pack.suspend()
        logger.info("offline_pack_paused: \(regionId, privacy: .public)")
        refreshPacks()
    }

    /// Resume a paused download.
    public func resume(regionId: String) {
        guard let pack = mlnPack(for: regionId) else { return }
        pack.resume()
        logger.info("offline_pack_resumed: \(regionId, privacy: .public)")
        refreshPacks()
    }

    /// Delete a downloaded pack and free storage.
    public func delete(regionId: String) {
        guard let pack = mlnPack(for: regionId) else { return }
        storage.removePack(pack) { [weak self] error in
            if let error {
                logger.error("offline_delete_failed: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("offline_pack_deleted: \(regionId, privacy: .public)")
            }
            self?.refreshPacks()
        }
    }

    /// Whether a specific region has been fully downloaded.
    public func isDownloaded(regionId: String) -> Bool {
        if case .complete = packs.first(where: { $0.id == regionId })?.status {
            return true
        }
        return false
    }

    /// Returns the total number of downloaded packs.
    public var downloadedCount: Int {
        packs.filter { if case .complete = $0.status { return true }; return false }.count
    }

    // MARK: - Progress Observation

    private func observeProgress() {
        let progressToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let pack = notification.object as? MLNOfflinePack else { return }
            let progress = pack.progress

            if progress.countOfResourcesExpected > 0 {
                let pct = Double(progress.countOfResourcesCompleted) / Double(progress.countOfResourcesExpected)
                if let regionId = self?.regionId(for: pack) {
                    logger.debug("offline_progress: \(regionId, privacy: .public) \(Int(pct * 100))%")
                }
            }

            self?.refreshPacks()
        }

        let errorToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[MLNOfflinePackUserInfoKey.error] as? NSError {
                logger.error("offline_pack_error: \(error.localizedDescription, privacy: .public)")
            }
            self?.refreshPacks()
        }

        observationTokens = [progressToken, errorToken]
    }

    // MARK: - Helpers

    private func mlnPack(for regionId: String) -> MLNOfflinePack? {
        storage.packs?.first { self.regionId(for: $0) == regionId }
    }

    private func regionId(for pack: MLNOfflinePack) -> String? {
        let data = pack.context
        guard let metadata = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return metadata[metadataKey]
    }

    private func packStatus(for pack: MLNOfflinePack) -> OfflinePackStatus {
        let progress = pack.progress
        let expected = progress.countOfResourcesExpected
        let completed = progress.countOfResourcesCompleted
        let bytes = progress.countOfBytesCompleted

        switch pack.state {
        case .active:
            if expected > 0 && completed >= expected {
                let sizeMB = Double(bytes) / 1_048_576
                let date = UserDefaults.standard.object(
                    forKey: "offline_pack_date_\(regionId(for: pack) ?? "unknown")"
                ) as? Date ?? Date()
                return .complete(sizeMB: sizeMB, downloadedAt: date)
            }
            let pct = expected > 0 ? Double(completed) / Double(expected) : 0
            return .downloading(progress: pct)

        case .inactive:
            if expected > 0 && completed >= expected {
                let sizeMB = Double(bytes) / 1_048_576
                let date = UserDefaults.standard.object(
                    forKey: "offline_pack_date_\(regionId(for: pack) ?? "unknown")"
                ) as? Date ?? Date()
                return .complete(sizeMB: sizeMB, downloadedAt: date)
            }
            return .paused

        case .unknown, .invalid:
            return .error("Pack is in an invalid state")

        @unknown default:
            return .error("Unknown pack state")
        }
    }
}
