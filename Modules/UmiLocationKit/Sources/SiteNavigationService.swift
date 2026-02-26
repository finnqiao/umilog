import Foundation
import MapKit
import UIKit
import UmiDB

public enum SiteEntryNavigationMode: String {
    case shore
    case boat
    case liveaboard
    case unknown
}

public struct SiteNavigationService {
    public static func navigate(to site: DiveSite, entryModes: [String] = []) {
        let coordinate = CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = site.name
        mapItem.openInMaps(launchOptions: launchOptions(for: site, entryModes: entryModes))
    }

    public static func launchOptions(for site: DiveSite, entryModes: [String] = []) -> [String: Any] {
        let mode = preferredMode(for: site, entryModes: entryModes)
        let directions: String
        switch mode {
        case .shore:
            directions = MKLaunchOptionsDirectionsModeWalking
        case .boat, .liveaboard, .unknown:
            directions = MKLaunchOptionsDirectionsModeDriving
        }
        return [MKLaunchOptionsDirectionsModeKey: directions]
    }

    @discardableResult
    public static func copyCoordinates(of site: DiveSite) -> String {
        let text = String(format: "%.6f, %.6f", site.latitude, site.longitude)
        UIPasteboard.general.string = text
        return text
    }

    public static func shareURL(for site: DiveSite) -> URL? {
        let encodedName = site.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? site.name
        let urlString = String(format: "https://maps.apple.com/?ll=%.6f,%.6f&q=%@", site.latitude, site.longitude, encodedName)
        return URL(string: urlString)
    }

    public static func preferredMode(for site: DiveSite, entryModes: [String] = []) -> SiteEntryNavigationMode {
        let normalized = entryModes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if normalized.contains("shore") { return .shore }
        if normalized.contains("boat") { return .boat }
        if normalized.contains("liveaboard") { return .liveaboard }

        if site.type == .shore {
            return .shore
        }
        return .unknown
    }
}
