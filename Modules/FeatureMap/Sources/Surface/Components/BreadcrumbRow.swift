import SwiftUI
import UmiDesignSystem

/// Breadcrumb navigation row for hierarchy drill-down.
/// Shows path like: Regions > [Region] > [Area]
struct BreadcrumbRow: View {
    let hierarchyLevel: HierarchyLevel
    var onNavigateUp: () -> Void
    var onResetToWorld: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: onNavigateUp) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lagoon)
            }
            .accessibilityLabel("Go back")

            // Breadcrumb segments
            breadcrumbSegments

            Spacer()
        }
    }

    @ViewBuilder
    private var breadcrumbSegments: some View {
        HStack(spacing: 6) {
            // World / Regions segment (always tappable to go home)
            Button(action: onResetToWorld) {
                Text("Regions")
                    .font(.caption)
                    .foregroundStyle(hierarchyLevel.isWorld ? Color.lagoon : Color.mist)
            }

            switch hierarchyLevel {
            case .world:
                EmptyView()

            case .region(let regionId):
                separator
                Text(regionId)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.lagoon)

            case .area(let regionId, let areaId):
                separator
                Button(action: onNavigateUp) {
                    Text(regionId)
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
                separator
                Text(areaId)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.lagoon)
            }
        }
    }

    private var separator: some View {
        Text("›")
            .font(.caption)
            .foregroundStyle(Color.mist.opacity(0.6))
    }
}

#if DEBUG
struct BreadcrumbRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            BreadcrumbRow(
                hierarchyLevel: .region("Okinawa"),
                onNavigateUp: {},
                onResetToWorld: {}
            )

            BreadcrumbRow(
                hierarchyLevel: .area(regionId: "Okinawa", areaId: "Kerama Islands"),
                onNavigateUp: {},
                onResetToWorld: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
