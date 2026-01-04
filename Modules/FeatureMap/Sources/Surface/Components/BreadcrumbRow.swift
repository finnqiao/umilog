import SwiftUI
import UmiDB
import UmiDesignSystem

/// Breadcrumb navigation row for hierarchy drill-down.
/// Shows path like: World > [Country] > [Region] > [Area]
struct BreadcrumbRow: View {
    let hierarchyLevel: HierarchyLevel
    var onNavigateUp: () -> Void
    var onResetToWorld: () -> Void

    // Repositories for name lookups
    private let geographyRepository = GeographyRepository(database: AppDatabase.shared)

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
            // World segment (always tappable to go home)
            Button(action: onResetToWorld) {
                Text("World")
                    .font(.caption)
                    .foregroundStyle(hierarchyLevel.isWorld ? Color.lagoon : Color.mist)
            }

            switch hierarchyLevel {
            case .world:
                EmptyView()

            case .country(let countryId):
                separator
                HStack(spacing: 4) {
                    Text(countryFlag(for: countryId))
                    Text(countryName(for: countryId))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.lagoon)
                }

            case .region(let countryId, let regionId):
                if let countryId = countryId {
                    separator
                    Button(action: onNavigateUp) {
                        HStack(spacing: 4) {
                            Text(countryFlag(for: countryId))
                            Text(countryName(for: countryId))
                                .font(.caption)
                                .foregroundStyle(Color.mist)
                        }
                    }
                }
                separator
                Text(regionName(for: regionId))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.lagoon)

            case .area(let regionId, let areaId):
                separator
                Button(action: onNavigateUp) {
                    Text(regionName(for: regionId))
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
                separator
                Text(areaName(for: areaId))
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

    // MARK: - Name Lookups

    private func countryFlag(for countryId: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in countryId.uppercased().unicodeScalars {
            if let unicode = Unicode.Scalar(base + scalar.value) {
                flag.append(Character(unicode))
            }
        }
        return flag.isEmpty ? "🌍" : flag
    }

    private func countryName(for countryId: String) -> String {
        (try? geographyRepository.fetchCountry(id: countryId))?.name ?? countryId
    }

    private func regionName(for regionId: String) -> String {
        (try? geographyRepository.fetchRegion(id: regionId))?.name ?? regionId
    }

    private func areaName(for areaId: String) -> String {
        (try? geographyRepository.fetchArea(id: areaId))?.name ?? areaId
    }
}

#if DEBUG
struct BreadcrumbRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            BreadcrumbRow(
                hierarchyLevel: .country("JP"),
                onNavigateUp: {},
                onResetToWorld: {}
            )

            BreadcrumbRow(
                hierarchyLevel: .region(countryId: "JP", regionId: "okinawa"),
                onNavigateUp: {},
                onResetToWorld: {}
            )

            BreadcrumbRow(
                hierarchyLevel: .area(regionId: "okinawa", areaId: "kerama"),
                onNavigateUp: {},
                onResetToWorld: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
