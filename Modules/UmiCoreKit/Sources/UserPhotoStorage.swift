import Foundation
import UIKit
import ImageIO

public enum CertificationCardSide: String, CaseIterable {
    case front
    case back
}

public struct SavedSightingPhotoInfo {
    public let filename: String
    public let thumbnailFilename: String
    public let width: Int
    public let height: Int

    public init(
        filename: String,
        thumbnailFilename: String,
        width: Int,
        height: Int
    ) {
        self.filename = filename
        self.thumbnailFilename = thumbnailFilename
        self.width = width
        self.height = height
    }
}

public struct PhotoMetadata {
    public let capturedAt: Date?
    public let latitude: Double?
    public let longitude: Double?

    public init(capturedAt: Date?, latitude: Double?, longitude: Double?) {
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum UserPhotoStorageError: Error {
    case invalidImageData
    case failedToEncodeImage
}

public final class CertificationCardStorageService {
    public static let shared = CertificationCardStorageService()

    private let fileManager = FileManager.default
    private let baseFolderName = "certifications"

    public func saveCardImage(
        _ image: UIImage,
        certificationId: String,
        side: CertificationCardSide
    ) throws -> String {
        let resized = image.resized(maxDimension: 1200)
        guard let data = resized.jpegData(compressionQuality: 0.8) else {
            throw UserPhotoStorageError.failedToEncodeImage
        }

        let relativePath = "\(baseFolderName)/\(certificationId)_\(side.rawValue).jpg"
        let absolute = try absoluteURL(forRelativePath: relativePath)
        try ensureParentDirectoryExists(for: absolute)
        try data.write(to: absolute, options: [.atomic])
        return relativePath
    }

    public func imageURL(forRelativePath path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return absoluteURLIfPossible(forRelativePath: path)
    }

    public func deleteImage(relativePath: String?) {
        guard let relativePath,
              let url = absoluteURLIfPossible(forRelativePath: relativePath) else {
            return
        }
        try? fileManager.removeItem(at: url)
    }

    public func clearAllImages() {
        guard let baseURL = absoluteURLIfPossible(forRelativePath: baseFolderName) else { return }
        try? fileManager.removeItem(at: baseURL)
    }

    private func absoluteURLIfPossible(forRelativePath path: String) -> URL? {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents.appendingPathComponent(path)
    }

    private func absoluteURL(forRelativePath path: String) throws -> URL {
        guard let url = absoluteURLIfPossible(forRelativePath: path) else {
            throw UserPhotoStorageError.invalidImageData
        }
        return url
    }

    private func ensureParentDirectoryExists(for url: URL) throws {
        let folder = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    }
}

public final class SightingPhotoStorageService {
    public static let shared = SightingPhotoStorageService()

    private let fileManager = FileManager.default
    private let baseFolderName = "sighting_photos"

    public func savePhoto(
        image: UIImage,
        sightingId: String
    ) throws -> SavedSightingPhotoInfo {
        let photoId = UUID().uuidString
        let folder = "\(baseFolderName)/\(sightingId)"
        let filename = "\(folder)/\(photoId).jpg"
        let thumbnailFilename = "\(folder)/\(photoId)_thumb.jpg"

        let fullImage = image.resized(maxDimension: 2048)
        let thumbImage = image.resized(maxDimension: 300)

        guard let fullData = fullImage.jpegData(compressionQuality: 0.85),
              let thumbData = thumbImage.jpegData(compressionQuality: 0.7) else {
            throw UserPhotoStorageError.failedToEncodeImage
        }

        let fullURL = try absoluteURL(forRelativePath: filename)
        let thumbURL = try absoluteURL(forRelativePath: thumbnailFilename)

        try ensureParentDirectoryExists(for: fullURL)
        try fullData.write(to: fullURL, options: [.atomic])
        try thumbData.write(to: thumbURL, options: [.atomic])

        let fullSize = fullImage.size
        return SavedSightingPhotoInfo(
            filename: filename,
            thumbnailFilename: thumbnailFilename,
            width: Int(fullSize.width),
            height: Int(fullSize.height)
        )
    }

    public func imageURL(forRelativePath path: String) -> URL? {
        absoluteURLIfPossible(forRelativePath: path)
    }

    public func deletePhotoFiles(forSightingId sightingId: String) {
        guard let baseURL = absoluteURLIfPossible(forRelativePath: "\(baseFolderName)/\(sightingId)") else {
            return
        }
        try? fileManager.removeItem(at: baseURL)
    }

    public func deleteFile(relativePath: String?) {
        guard let relativePath,
              let fileURL = absoluteURLIfPossible(forRelativePath: relativePath) else {
            return
        }
        try? fileManager.removeItem(at: fileURL)
    }

    public func clearAllPhotos() {
        guard let baseURL = absoluteURLIfPossible(forRelativePath: baseFolderName) else { return }
        try? fileManager.removeItem(at: baseURL)
    }

    private func absoluteURLIfPossible(forRelativePath path: String) -> URL? {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents.appendingPathComponent(path)
    }

    private func absoluteURL(forRelativePath path: String) throws -> URL {
        guard let url = absoluteURLIfPossible(forRelativePath: path) else {
            throw UserPhotoStorageError.invalidImageData
        }
        return url
    }

    private func ensureParentDirectoryExists(for url: URL) throws {
        let folder = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    }
}

public enum PhotoMetadataExtractor {
    public static func extract(from imageData: Data) -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return PhotoMetadata(capturedAt: nil, latitude: nil, longitude: nil)
        }

        let capturedAt = parseCapturedDate(from: properties)
        let (latitude, longitude) = parseGPS(from: properties)
        return PhotoMetadata(capturedAt: capturedAt, latitude: latitude, longitude: longitude)
    }

    private static func parseCapturedDate(from properties: [CFString: Any]) -> Date? {
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            return exifDateFormatter.date(from: original)
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let dateTime = tiff[kCGImagePropertyTIFFDateTime] as? String {
            return exifDateFormatter.date(from: dateTime)
        }

        return nil
    }

    private static func parseGPS(from properties: [CFString: Any]) -> (Double?, Double?) {
        guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
              let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String else {
            return (nil, nil)
        }

        let signedLat = (latRef.uppercased() == "S") ? -lat : lat
        let signedLon = (lonRef.uppercased() == "W") ? -lon : lon
        return (signedLat, signedLon)
    }

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let currentMax = max(size.width, size.height)
        guard currentMax > maxDimension, currentMax > 0 else { return self }

        let scale = maxDimension / currentMax
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
