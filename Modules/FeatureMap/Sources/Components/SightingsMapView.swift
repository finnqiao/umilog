import SwiftUI
import MapKit
import UmiDesignSystem

/// Embedded map view showing locations where a species has been sighted.
/// Displays pins at dive site coordinates with clustering for nearby locations.
public struct SightingsMapView: View {
    let locations: [SightingLocation]
    let onLocationTap: ((SightingLocation) -> Void)?

    @State private var position: MapCameraPosition = .automatic

    public init(
        locations: [SightingLocation],
        onLocationTap: ((SightingLocation) -> Void)? = nil
    ) {
        self.locations = locations
        self.onLocationTap = onLocationTap
    }

    public var body: some View {
        Group {
            if locations.isEmpty {
                emptyState
            } else {
                mapContent
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)

            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.title)
                    .foregroundStyle(.tertiary)

                Text("No sighting locations")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var mapContent: some View {
        Map(position: $position) {
            ForEach(locations) { location in
                Annotation(
                    location.siteName,
                    coordinate: location.coordinate,
                    anchor: .bottom
                ) {
                    SightingPin(count: location.sightingCount)
                        .onTapGesture {
                            onLocationTap?(location)
                        }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .allowsHitTesting(true)
        .onAppear {
            updateCameraPosition()
        }
    }

    private func updateCameraPosition() {
        guard !locations.isEmpty else { return }

        if locations.count == 1, let first = locations.first {
            position = .camera(
                MapCamera(
                    centerCoordinate: first.coordinate,
                    distance: 50000 // 50km view for single location
                )
            )
        } else {
            // Calculate bounding region for all locations
            let coordinates = locations.map { $0.coordinate }
            let region = MKCoordinateRegion(coordinates: coordinates)
            position = .region(region)
        }
    }
}

// MARK: - Sighting Pin

private struct SightingPin: View {
    let count: Int

    var body: some View {
        ZStack {
            // Shadow
            Circle()
                .fill(.black.opacity(0.2))
                .frame(width: 32, height: 32)
                .offset(y: 2)

            // Pin body
            Circle()
                .fill(Color.lagoon)
                .frame(width: 32, height: 32)
                .overlay {
                    if count > 1 {
                        Text("\(min(count, 99))")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

            // Pin point
            Triangle()
                .fill(Color.lagoon)
                .frame(width: 10, height: 8)
                .offset(y: 18)
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Supporting Types

/// Represents a location where a species has been sighted
public struct SightingLocation: Identifiable, Equatable {
    public let id: String
    public let siteId: String
    public let siteName: String
    public let latitude: Double
    public let longitude: Double
    public let sightingCount: Int

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        id: String = UUID().uuidString,
        siteId: String,
        siteName: String,
        latitude: Double,
        longitude: Double,
        sightingCount: Int = 1
    ) {
        self.id = id
        self.siteId = siteId
        self.siteName = siteName
        self.latitude = latitude
        self.longitude = longitude
        self.sightingCount = sightingCount
    }
}

// MARK: - MKCoordinateRegion Extension

private extension MKCoordinateRegion {
    /// Creates a region that encompasses all the given coordinates with some padding
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )
            return
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Add 20% padding
        let latDelta = (maxLat - minLat) * 1.4
        let lonDelta = (maxLon - minLon) * 1.4

        // Ensure minimum span
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.5),
            longitudeDelta: max(lonDelta, 0.5)
        )

        self = MKCoordinateRegion(center: center, span: span)
    }
}

#Preview("Sightings Map") {
    VStack {
        SightingsMapView(
            locations: [
                SightingLocation(
                    siteId: "1",
                    siteName: "Great Barrier Reef",
                    latitude: -18.2871,
                    longitude: 147.6992,
                    sightingCount: 3
                ),
                SightingLocation(
                    siteId: "2",
                    siteName: "Ningaloo Reef",
                    latitude: -22.6966,
                    longitude: 113.6822,
                    sightingCount: 1
                )
            ]
        )
        .padding()

        SightingsMapView(locations: [])
            .padding()
    }
}
