import Foundation
import UIKit
import os

/// Actor-based image caching service with two-tier cache (memory + disk).
///
/// Usage:
/// ```swift
/// let image = await ImageCacheService.shared.image(for: "Q123456", url: cdnURL)
/// ```
public actor ImageCacheService {
    public static let shared = ImageCacheService()

    // MARK: - Configuration

    private let maxMemoryCacheCount = 50
    private let maxDiskCacheSizeMB = 100
    private let requestTimeoutSeconds: TimeInterval = 15

    // MARK: - Caches

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    // MARK: - State

    private var inFlightRequests: [String: Task<UIImage?, Never>] = [:]

    // MARK: - Init

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("SiteImages", isDirectory: true)

        // Create disk cache directory if needed
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Configure memory cache
        memoryCache.countLimit = maxMemoryCacheCount

        Log.images.info("ImageCacheService initialized. Disk cache: \(self.diskCacheURL.path)")
    }

    // MARK: - Public API

    /// Load image for a site, checking memory cache, disk cache, then network.
    /// Returns nil if image cannot be loaded (offline, not available, etc.)
    public func image(for siteId: String, url: URL?) async -> UIImage? {
        // 1. Check memory cache
        if let cached = loadFromMemory(siteId) {
            Log.images.debug("Memory cache hit: \(siteId)")
            return cached
        }

        // 2. Check disk cache
        if let cached = loadFromDisk(siteId) {
            saveToMemory(siteId, image: cached)
            Log.images.debug("Disk cache hit: \(siteId)")
            return cached
        }

        // 3. No URL means no network fetch
        guard let url = url else {
            return nil
        }

        // 4. Deduplicate in-flight requests
        if let existing = inFlightRequests[siteId] {
            return await existing.value
        }

        // 5. Fetch from network
        let task = Task<UIImage?, Never> {
            await downloadAndCache(siteId, url: url)
        }
        inFlightRequests[siteId] = task
        let result = await task.value
        inFlightRequests[siteId] = nil
        return result
    }

    /// Prefetch images for multiple sites (fire-and-forget style).
    /// Useful for viewport pre-loading.
    public func prefetch(siteIds: [String], urls: [String: URL]) async {
        for siteId in siteIds {
            guard let url = urls[siteId] else { continue }

            // Skip if already cached
            if loadFromMemory(siteId) != nil || loadFromDisk(siteId) != nil {
                continue
            }

            // Skip if already in-flight
            if inFlightRequests[siteId] != nil {
                continue
            }

            // Start low-priority fetch
            Task(priority: .utility) {
                _ = await self.image(for: siteId, url: url)
            }
        }
    }

    /// Clear all caches (memory and disk).
    public func clearCache() async {
        memoryCache.removeAllObjects()

        do {
            let files = try fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil)
            for file in files {
                try? fileManager.removeItem(at: file)
            }
            Log.images.info("Cache cleared. Removed \(files.count) files.")
        } catch {
            Log.images.error("Failed to clear disk cache: \(error.localizedDescription)")
        }
    }

    /// Get disk cache size in bytes.
    public func diskCacheSize() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + size
        }
    }

    // MARK: - Memory Cache

    private func loadFromMemory(_ siteId: String) -> UIImage? {
        memoryCache.object(forKey: siteId as NSString)
    }

    private func saveToMemory(_ siteId: String, image: UIImage) {
        memoryCache.setObject(image, forKey: siteId as NSString)
    }

    // MARK: - Disk Cache

    private func diskCachePath(for siteId: String) -> URL {
        diskCacheURL.appendingPathComponent("\(siteId).jpg")
    }

    private func loadFromDisk(_ siteId: String) -> UIImage? {
        let path = diskCachePath(for: siteId)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        return UIImage(contentsOfFile: path.path)
    }

    private func saveToDisk(_ siteId: String, data: Data) {
        let path = diskCachePath(for: siteId)
        do {
            try data.write(to: path)
        } catch {
            Log.images.error("Failed to save to disk cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Network

    private func downloadAndCache(_ siteId: String, url: URL) async -> UIImage? {
        Log.images.debug("Fetching image: \(siteId) from \(url.absoluteString)")

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = requestTimeoutSeconds
            let session = URLSession(configuration: config)

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                Log.images.warning("Bad response for \(siteId): \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            guard let image = UIImage(data: data) else {
                Log.images.warning("Invalid image data for \(siteId)")
                return nil
            }

            // Cache
            saveToMemory(siteId, image: image)
            saveToDisk(siteId, data: data)

            Log.images.info("Cached image: \(siteId) (\(data.count / 1024)KB)")
            return image

        } catch {
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                Log.images.debug("Offline, skipping fetch for \(siteId)")
            } else {
                Log.images.error("Download failed for \(siteId): \(error.localizedDescription)")
            }
            return nil
        }
    }

    // MARK: - Cache Maintenance

    /// Evict oldest files when disk cache exceeds limit.
    /// Called periodically or on app launch.
    public func evictIfNeeded() async {
        let maxBytes = maxDiskCacheSizeMB * 1024 * 1024
        var currentSize = diskCacheSize()

        guard currentSize > maxBytes else { return }

        Log.images.info("Disk cache over limit (\(currentSize / 1024 / 1024)MB). Evicting...")

        // Get files sorted by modification date (oldest first)
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        let sortedFiles = files.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return date1 < date2
        }

        // Delete oldest files until under limit
        for file in sortedFiles {
            guard currentSize > maxBytes else { break }
            let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try? fileManager.removeItem(at: file)
            currentSize -= fileSize
        }

        Log.images.info("Eviction complete. New size: \(currentSize / 1024 / 1024)MB")
    }
}
