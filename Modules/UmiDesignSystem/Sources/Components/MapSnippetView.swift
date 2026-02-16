import SwiftUI
import MapKit

/// A compact, non-interactive map view showing a single location.
/// Used as a header in the Quick Log flow to display the selected dive site.
public struct MapSnippetView: View {
    let latitude: Double?
    let longitude: Double?
    let siteName: String?

    @State private var region: MKCoordinateRegion

    public init(latitude: Double?, longitude: Double?, siteName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.siteName = siteName

        // Initialize region centered on location or default
        let center = CLLocationCoordinate2D(
            latitude: latitude ?? 0,
            longitude: longitude ?? 0
        )
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    private var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    public var body: some View {
        Group {
            if hasLocation {
                mapContent
            } else {
                placeholderContent
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.glass, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var mapContent: some View {
        ZStack(alignment: .bottom) {
            Map(position: .constant(.region(region)), interactionModes: []) {
                ForEach(annotations) { item in
                    Annotation("", coordinate: item.coordinate, anchor: .bottom) {
                        // Custom pin
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color.lagoon)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "water.waves")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .shadow(color: Color.lagoon.opacity(0.5), radius: 4)

                            // Pin tail
                            Triangle()
                                .fill(Color.lagoon)
                                .frame(width: 12, height: 8)
                                .offset(y: -2)
                        }
                    }
                }
            }
            .allowsHitTesting(false)

            // Site name overlay
            if let name = siteName {
                HStack {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.black.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack {
            Color.midnight.opacity(0.5)

            VStack(spacing: 8) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)

                Text("Select a dive site")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var annotations: [MapAnnotationItem] {
        guard let lat = latitude, let lon = longitude else { return [] }
        return [MapAnnotationItem(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))]
    }
}

// MARK: - Supporting Types

private struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview("MapSnippetView") {
    VStack(spacing: 16) {
        MapSnippetView(
            latitude: 8.0432,
            longitude: 98.8367,
            siteName: "Blue Hole, Dahab"
        )

        MapSnippetView(
            latitude: nil,
            longitude: nil,
            siteName: nil
        )
    }
    .padding()
    .background(Color.abyss)
}
