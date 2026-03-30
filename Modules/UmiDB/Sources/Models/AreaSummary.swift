import Foundation
import CoreLocation

/// Lightweight area info for UI display in map markers and sheet lists.
/// Pre-computed data with site counts for fast rendering at regional zoom.
public struct AreaSummary: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let regionId: String?
    public let regionName: String?
    public let countryName: String?
    public let siteCount: Int
    public let centerLat: Double
    public let centerLon: Double

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }

    public init(
        id: String,
        name: String,
        regionId: String? = nil,
        regionName: String? = nil,
        countryName: String? = nil,
        siteCount: Int,
        centerLat: Double,
        centerLon: Double
    ) {
        self.id = id
        self.name = name
        self.regionId = regionId
        self.regionName = regionName
        self.countryName = countryName
        self.siteCount = siteCount
        self.centerLat = centerLat
        self.centerLon = centerLon
    }
}
