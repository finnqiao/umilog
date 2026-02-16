import SwiftUI
import UmiDB
import UmiDesignSystem
import CoreLocation

/// Content view for cluster expand mode.
/// Shows a "site stack" of dive sites in a tapped cluster.
struct ClusterExpandContent: View {
    // MARK: - Properties

    let context: ClusterExpandContext
    let sites: [DiveSite]
    let detent: SurfaceDetent

    var onSiteTap: (DiveSite) -> Void
    var onZoomIn: () -> Void
    var onClose: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            if detent != .peek {
                // Site list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(nearbySites, id: \.id) { site in
                            ClusterSiteRow(site: site)
                                .onTapGesture {
                                    onSiteTap(site)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            } else {
                // Peek mode - show count and zoom button
                peekContent
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Site Stack")
                    .font(.headline)
                    .foregroundStyle(Color.foam)
                Text("\(context.siteCount) sites in this area")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.mist)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.kelp.opacity(0.5)))
            }
            .accessibilityLabel("Close site stack")
        }
    }

    // MARK: - Peek Content

    private var peekContent: some View {
        HStack(spacing: 12) {
            // Site count badge
            VStack(alignment: .leading, spacing: 2) {
                Text("\(context.siteCount)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.pinDefault)
                Text("dive sites")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }

            Spacer()

            // Zoom in button
            Button(action: onZoomIn) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Zoom In")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Color.abyss)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.pinDefault))
            }
            .accessibilityLabel("Zoom in to see individual sites")
        }
        .padding(.vertical, 8)
    }

    // MARK: - Nearby Sites

    /// Sites sorted by distance from cluster center.
    private var nearbySites: [DiveSite] {
        sites
            .filter { site in
                let distance = CLLocation(latitude: site.latitude, longitude: site.longitude)
                    .distance(from: CLLocation(
                        latitude: context.clusterCenter.latitude,
                        longitude: context.clusterCenter.longitude
                    ))
                // Include sites within ~50km of cluster center
                return distance < 50000
            }
            .sorted { site1, site2 in
                let d1 = CLLocation(latitude: site1.latitude, longitude: site1.longitude)
                    .distance(from: CLLocation(
                        latitude: context.clusterCenter.latitude,
                        longitude: context.clusterCenter.longitude
                    ))
                let d2 = CLLocation(latitude: site2.latitude, longitude: site2.longitude)
                    .distance(from: CLLocation(
                        latitude: context.clusterCenter.latitude,
                        longitude: context.clusterCenter.longitude
                    ))
                return d1 < d2
            }
            .prefix(20) // Limit to 20 nearest sites
            .map { $0 }
    }
}

// MARK: - Cluster Site Row

private struct ClusterSiteRow: View {
    let site: DiveSite

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(site.difficulty.rawValue)
                        .font(.caption)
                        .foregroundStyle(Color.mist)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(Color.mist.opacity(0.5))

                    Text("Max \(Int(site.maxDepth))m")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
            }

            Spacer()

            // Dive count badge
            if site.visitedCount > 0 {
                Text("\(site.visitedCount)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.pinVisited)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.mist.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.trench)
        )
    }

    private var statusColor: Color {
        if site.visitedCount > 0 {
            return Color.pinVisited
        } else if site.wishlist {
            return Color.pinFavorite
        } else {
            return Color.pinDefault.opacity(0.5)
        }
    }
}

// MARK: - Preview

#Preview("Cluster Expand") {
    ZStack {
        Color.abyss.ignoresSafeArea()
        VStack {
            Spacer()
            ClusterExpandContent(
                context: ClusterExpandContext(
                    clusterCenter: CLLocationCoordinate2D(latitude: 8.0, longitude: 98.3),
                    siteCount: 12,
                    returnContext: ExploreContext()
                ),
                sites: [],
                detent: .medium,
                onSiteTap: { _ in },
                onZoomIn: {},
                onClose: {}
            )
            .frame(height: 400)
            .background(Color.midnight)
        }
    }
}
