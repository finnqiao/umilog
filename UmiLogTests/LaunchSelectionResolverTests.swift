import XCTest
import CoreLocation
@testable import FeatureMap

final class LaunchSelectionResolverTests: XCTestCase {
    func testResolvePrefersSavedCameraOverOtherSources() {
        let savedCamera = (
            center: CLLocationCoordinate2D(latitude: -8.5, longitude: 119.6),
            zoom: 9.2
        )
        var featuredLookupCalls = 0

        let selection = LaunchSelectionResolver.resolve(
            savedCamera: savedCamera,
            authorizedLocation: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0)
        ) {
            featuredLookupCalls += 1
            return makeFeatured(id: "featured-a")
        }

        XCTAssertEqual(selection.source, .savedCamera)
        XCTAssertEqual(selection.savedCamera?.zoom, 9.2)
        XCTAssertEqual(featuredLookupCalls, 0)
    }

    func testResolvePrefersAuthorizedLocationWhenNoSavedCamera() {
        var featuredLookupCalls = 0
        let location = CLLocationCoordinate2D(latitude: -0.5, longitude: 130.5)

        let selection = LaunchSelectionResolver.resolve(
            savedCamera: nil,
            authorizedLocation: location
        ) {
            featuredLookupCalls += 1
            return makeFeatured(id: "featured-b")
        }

        XCTAssertEqual(selection.source, .authorizedLocation)
        guard let selectedLocation = selection.authorizedLocation else {
            XCTFail("Expected authorized launch location to be selected")
            return
        }
        XCTAssertEqual(selectedLocation.latitude, location.latitude, accuracy: 0.0001)
        XCTAssertEqual(selectedLocation.longitude, location.longitude, accuracy: 0.0001)
        XCTAssertEqual(featuredLookupCalls, 0)
    }

    func testResolveUsesFeaturedSiteWhenNoSavedCameraOrLocation() {
        let featured = makeFeatured(id: "featured-c")
        let selection = LaunchSelectionResolver.resolve(
            savedCamera: nil,
            authorizedLocation: nil
        ) {
            featured
        }

        XCTAssertEqual(selection.source, .featuredTopSite)
        XCTAssertEqual(selection.featuredDestination?.id, "featured-c")
    }

    func testResolveFallsBackToGlobalWhenNoInputsAvailable() {
        let selection = LaunchSelectionResolver.resolve(
            savedCamera: nil,
            authorizedLocation: nil
        ) {
            nil
        }

        XCTAssertEqual(selection.source, .globalFallback)
        XCTAssertNil(selection.savedCamera)
        XCTAssertNil(selection.authorizedLocation)
        XCTAssertNil(selection.featuredDestination)
    }

    private func makeFeatured(id: String) -> FeaturedDestination {
        FeaturedDestination(
            id: id,
            regionId: "coral-triangle",
            displayName: "Raja Ampat",
            tagline: "Biodiversity capital",
            latitude: -0.5,
            longitude: 130.5,
            zoomLevel: 8.5
        )
    }
}
