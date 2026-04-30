import CoreLocation

struct LaunchSelection {
    enum Source: Equatable {
        case savedCamera
        case authorizedLocation
        case featuredTopSite
        case globalFallback
    }

    let source: Source
    let savedCamera: (center: CLLocationCoordinate2D, zoom: Double)?
    let authorizedLocation: CLLocationCoordinate2D?
    let featuredDestination: FeaturedDestination?
}

enum LaunchSelectionResolver {
    static func resolve(
        savedCamera: (center: CLLocationCoordinate2D, zoom: Double)?,
        authorizedLocation: CLLocationCoordinate2D?,
        featuredDestination: () -> FeaturedDestination?
    ) -> LaunchSelection {
        if let savedCamera {
            return LaunchSelection(
                source: .savedCamera,
                savedCamera: savedCamera,
                authorizedLocation: nil,
                featuredDestination: nil
            )
        }

        if let authorizedLocation {
            return LaunchSelection(
                source: .authorizedLocation,
                savedCamera: nil,
                authorizedLocation: authorizedLocation,
                featuredDestination: nil
            )
        }

        if let featured = featuredDestination() {
            return LaunchSelection(
                source: .featuredTopSite,
                savedCamera: nil,
                authorizedLocation: nil,
                featuredDestination: featured
            )
        }

        return LaunchSelection(
            source: .globalFallback,
            savedCamera: nil,
            authorizedLocation: nil,
            featuredDestination: nil
        )
    }
}
