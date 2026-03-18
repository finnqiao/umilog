import UIKit
import os

/// Captures and caches a JPEG snapshot of the map for instant visual on next launch.
/// Stored in the caches directory (~50-100KB). Automatically evicted by the OS under storage pressure.
public final class MapSnapshotCache {
    public static let shared = MapSnapshotCache()

    private let logger = Logger(subsystem: "app.umilog", category: "MapSnapshot")
    private let fileName = "map_snapshot.jpg"
    private let compressionQuality: CGFloat = 0.7

    private init() {}

    /// URL in the caches directory for the snapshot.
    private var snapshotURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    /// Captures a snapshot from the given view and saves as JPEG.
    public func capture(from view: UIView) {
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }

        guard let data = image.jpegData(compressionQuality: compressionQuality),
              let url = snapshotURL else {
            logger.error("snapshot_capture_failed")
            return
        }

        do {
            try data.write(to: url, options: .atomic)
            logger.log("snapshot_saved size=\(data.count, privacy: .public)")
        } catch {
            logger.error("snapshot_write_failed: \(error)")
        }
    }

    /// Loads the cached snapshot image, if available.
    public func loadSnapshot() -> UIImage? {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// Deletes the cached snapshot.
    public func clear() {
        guard let url = snapshotURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
