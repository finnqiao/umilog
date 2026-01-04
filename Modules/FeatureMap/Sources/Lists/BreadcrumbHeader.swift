import SwiftUI
import UmiDB
import UmiDesignSystem

// MARK: - Breadcrumb Header

/// Navigation breadcrumb showing current drill-down level
struct BreadcrumbHeader: View {
    let tier: Tier
    let regionName: String?
    let regionsCount: Int
    let areasCount: Int
    let sitesCount: Int
    var onResetToWorld: () -> Void
    var onResetToRegion: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Breadcrumb
            HStack(spacing: 6) {
                Text("Regions")
                    .foregroundStyle(tier == .regions ? Color.lagoon : Color.mist)
                    .onTapGesture { onResetToWorld() }
                Text("›").foregroundStyle(Color.mist.opacity(0.6))
                Text(regionName ?? "Areas")
                    .foregroundStyle(tier == .areas ? Color.lagoon : Color.mist)
                    .onTapGesture {
                        if regionName != nil {
                            onResetToRegion()
                        }
                    }
                Text("›").foregroundStyle(Color.mist.opacity(0.6))
                Text("Sites")
                    .foregroundStyle(tier == .sites ? Color.lagoon : Color.mist)
            }
            Spacer()
            // Counts
            Text(countText)
                .font(.caption)
                .foregroundStyle(Color.mist)
        }
    }

    private var countText: String {
        switch tier {
        case .regions: return "\(abbreviatedCount(regionsCount)) regions"
        case .areas: return "\(abbreviatedCount(areasCount)) areas"
        case .sites: return "\(abbreviatedCount(sitesCount)) sites"
        }
    }
}

// MARK: - Areas List

/// Displays a scrollable list of dive areas within a region
struct AreasListView: View {
    let areas: [Area]
    let onAreaTap: (Area) -> Void

    var body: some View {
        if areas.isEmpty {
            EmptyStateView(
                icon: "mappin.slash",
                title: "No areas yet",
                message: "Pick a region or clear filters to browse dive areas."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(areas) { area in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(area.name).font(.body)
                                    .accessibilityLabel("Area: \(area.name)")
                                Text(summary(for: area))
                                    .font(.caption).foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                                    .accessibilityLabel(accessibilitySummary(for: area))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                .accessibilityLabel("Open area")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onAreaTap(area) }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func summary(for area: Area) -> String {
        var components: [String] = []
        if !area.country.isEmpty {
            components.append(area.country)
        }
        components.append("\(area.siteCount) sites")
        if area.shopCount > 0 {
            components.append("\(area.shopCount) shops")
        }
        return components.joined(separator: " · ")
    }

    private func accessibilitySummary(for area: Area) -> String {
        var sentence = "Located in \(area.country.isEmpty ? "this region" : area.country) with \(area.siteCount) dive sites"
        if area.shopCount > 0 {
            sentence += " and \(area.shopCount) dive shops"
        }
        return sentence
    }
}
