import SwiftUI
import UmiDB
import UmiDesignSystem

/// Contextual chip rail shown above the map.
///
/// Content changes based on the current semantic zoom level:
/// - **World**: Featured destination chips (Red Sea, Philippines, etc.)
/// - **Regional**: Area chips within the visible region (Moalboal, Dauin, etc.)
/// - **Local**: Breadcrumb path (Philippines > Visayas > Cebu)
struct ContextualChipsRail: View {
    let zoomLevel: MapZoomLevel
    let destinations: [RegionSummary]
    let areas: [AreaSummary]
    let breadcrumbPath: [String]
    let onDestinationTap: (RegionSummary) -> Void
    let onAreaTap: (AreaSummary) -> Void
    let onBreadcrumbTap: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                switch zoomLevel {
                case .world:
                    ForEach(destinations) { region in
                        DestinationQuickChip(region: region) {
                            onDestinationTap(region)
                        }
                    }
                case .regional:
                    ForEach(areas) { area in
                        AreaQuickChip(area: area) {
                            onAreaTap(area)
                        }
                    }
                case .local:
                    if !breadcrumbPath.isEmpty {
                        ForEach(Array(breadcrumbPath.enumerated()), id: \.offset) { index, crumb in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.mist.opacity(0.5))
                            }
                            BreadcrumbChip(title: crumb, isLast: index == breadcrumbPath.count - 1) {
                                onBreadcrumbTap(index)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .animation(.easeInOut(duration: 0.25), value: zoomLevel)
    }
}

// Keep backward compatibility: PopularRegionChips wraps ContextualChipsRail at world zoom.
struct PopularRegionChips: View {
    let regions: [RegionSummary]
    let onTap: (RegionSummary) -> Void

    var body: some View {
        ContextualChipsRail(
            zoomLevel: .world,
            destinations: regions,
            areas: [],
            breadcrumbPath: [],
            onDestinationTap: onTap,
            onAreaTap: { _ in },
            onBreadcrumbTap: { _ in }
        )
    }
}

// MARK: - Destination Chip (World Zoom)

private struct DestinationQuickChip: View {
    let region: RegionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(Color.lagoon)

                Text(region.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)

                Text("· \(region.siteCount)")
                    .font(.caption2)
                    .foregroundStyle(Color.mist)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.abyss.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to \(region.name), \(region.siteCount) sites")
    }
}

// MARK: - Area Chip (Regional Zoom)

private struct AreaQuickChip: View {
    let area: AreaSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "map")
                    .font(.caption2)
                    .foregroundStyle(Color.reef)

                Text(area.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)

                Text("· \(area.siteCount)")
                    .font(.caption2)
                    .foregroundStyle(Color.mist)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.abyss.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to \(area.name), \(area.siteCount) sites")
    }
}

// MARK: - Breadcrumb Chip (Local Zoom)

private struct BreadcrumbChip: View {
    let title: String
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isLast ? .semibold : .medium)
                .foregroundStyle(isLast ? Color.foam : Color.mist)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isLast ? Color.trench : Color.abyss.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLast ? "Current location: \(title)" : "Navigate to \(title)")
    }
}

// MARK: - Preview

#if DEBUG
struct ContextualChipsRail_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.trench
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // World zoom
                ContextualChipsRail(
                    zoomLevel: .world,
                    destinations: RegionSummary.popular,
                    areas: [],
                    breadcrumbPath: [],
                    onDestinationTap: { _ in },
                    onAreaTap: { _ in },
                    onBreadcrumbTap: { _ in }
                )

                // Local zoom with breadcrumbs
                ContextualChipsRail(
                    zoomLevel: .local,
                    destinations: [],
                    areas: [],
                    breadcrumbPath: ["Philippines", "Visayas", "Moalboal"],
                    onDestinationTap: { _ in },
                    onAreaTap: { _ in },
                    onBreadcrumbTap: { _ in }
                )

                Spacer()
            }
            .padding(.top, 60)
        }
    }
}
#endif
