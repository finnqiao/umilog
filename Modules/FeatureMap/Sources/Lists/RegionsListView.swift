import SwiftUI
import UmiDB
import UmiDesignSystem

/// Displays a scrollable list of dive regions
struct RegionsListView: View {
    let regions: [Region]
    @Binding var selectedRegion: Region?
    var onRegionTap: (Region) -> Void

    var body: some View {
        if regions.isEmpty {
            EmptyStateView(
                icon: "globe.europe.africa",
                title: "No regions found",
                message: "Zoom out or clear filters to explore all regions."
            )
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    Text("All Regions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    Text(summaryLine)
                        .font(.subheadline)
                        .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    ForEach(regions) { region in
                        RegionRow(region: region, isSelected: selectedRegion?.id == region.id)
                            .contentShape(Rectangle())
                            .onTapGesture { onRegionTap(region) }
                    }
                }
            }
        }
    }

    private var summaryLine: String {
        guard !regions.isEmpty else { return "No regions yet" }
        let visitedTotal = regions.reduce(0) { $0 + $1.visitedCount }
        let sitesTotal = regions.reduce(0) { $0 + $1.totalSites }
        let shopTotal = regions.reduce(0) { $0 + $1.shopCount }
        var parts = ["\(visitedTotal)/\(sitesTotal) visited"]
        if shopTotal > 0 {
            parts.append("\(shopTotal) shops")
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Region Row

struct RegionRow: View {
    let region: Region
    var isSelected: Bool = false

    var body: some View {
        HStack {
            Circle()
                .fill(region.visitedCount > 0 ? Color.oceanBlue : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .accessibilityLabel(region.visitedCount > 0 ? "Visited" : "Not visited")

            VStack(alignment: .leading, spacing: 2) {
                Text(region.name)
                    .font(.body)
                    .accessibilityLabel("Region: \(region.name)")
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                    .accessibilityLabel(accessibilityDetail)
            }

            Spacer()

            if region.visitedCount > 0 {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .accessibilityLabel("Has visited sites")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.glass.opacity(0.6) : Color.clear)
        )
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        let visited = "\(region.visitedCount)/\(region.totalSites) visited"
        guard region.shopCount > 0 else { return visited }
        return "\(visited) • \(region.shopCount) shops"
    }

    private var accessibilityDetail: String {
        if region.shopCount > 0 {
            return "\(region.visitedCount) of \(region.totalSites) sites visited, \(region.shopCount) dive shops"
        }
        return "\(region.visitedCount) of \(region.totalSites) sites visited"
    }
}
