import SwiftUI
import UmiDB
import UmiDesignSystem

/// Horizontal scrollable row of site type filter chips.
/// Used in the search interface to filter results by site type (Wrecks, Reefs, Caves, etc.)
struct SiteTypeFilterRow: View {
    // MARK: - Properties

    @Binding var selectedTypes: Set<DiveSite.SiteType>
    @Binding var nightDivingOnly: Bool

    // MARK: - Filter Options

    private struct FilterOption: Identifiable {
        let id: String
        let label: String
        let icon: String
        let siteType: DiveSite.SiteType?
        let isNightFilter: Bool

        init(label: String, icon: String, siteType: DiveSite.SiteType? = nil, isNightFilter: Bool = false) {
            self.id = siteType?.rawValue ?? (isNightFilter ? "night" : "all")
            self.label = label
            self.icon = icon
            self.siteType = siteType
            self.isNightFilter = isNightFilter
        }
    }

    private let filterOptions: [FilterOption] = [
        FilterOption(label: "All", icon: "map"),
        FilterOption(label: "Wrecks", icon: "ferry", siteType: .wreck),
        FilterOption(label: "Reefs", icon: "water.waves", siteType: .reef),
        FilterOption(label: "Caves", icon: "mountain.2", siteType: .cave),
        FilterOption(label: "Night", icon: "moon.stars", isNightFilter: true)
    ]

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterOptions) { option in
                    filterPill(option: option)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Filter Pill

    private func filterPill(option: FilterOption) -> some View {
        let isSelected: Bool = {
            if option.isNightFilter {
                return nightDivingOnly
            } else if let siteType = option.siteType {
                return selectedTypes.contains(siteType)
            } else {
                // "All" is selected when no types are selected and night is off
                return selectedTypes.isEmpty && !nightDivingOnly
            }
        }()

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if option.isNightFilter {
                    nightDivingOnly.toggle()
                } else if let siteType = option.siteType {
                    if selectedTypes.contains(siteType) {
                        selectedTypes.remove(siteType)
                    } else {
                        selectedTypes.insert(siteType)
                    }
                } else {
                    // "All" clears all filters
                    selectedTypes.removeAll()
                    nightDivingOnly = false
                }
            }
            Haptics.soft()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.caption2)
                Text(option.label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? Color.foam : Color.mist)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? pillColor(for: option) : Color.trench)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func pillColor(for option: FilterOption) -> Color {
        if option.isNightFilter {
            return Color.ocean
        }
        guard let siteType = option.siteType else {
            return Color.lagoon
        }
        switch siteType {
        case .wreck:
            return Color.amber
        case .reef:
            return Color.reef
        case .cave:
            return Color.trench.opacity(0.8)
        case .wall:
            return Color.lagoon
        case .shore:
            return Color.difficultyBeginner
        case .drift:
            return Color.difficultyIntermediate
        }
    }
}

#if DEBUG
struct SiteTypeFilterRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("No filters selected")
                .font(.caption)
                .foregroundStyle(Color.mist)
            SiteTypeFilterRow(
                selectedTypes: .constant([]),
                nightDivingOnly: .constant(false)
            )

            Text("Wreck + Reef selected")
                .font(.caption)
                .foregroundStyle(Color.mist)
            SiteTypeFilterRow(
                selectedTypes: .constant([.wreck, .reef]),
                nightDivingOnly: .constant(false)
            )

            Text("Night only")
                .font(.caption)
                .foregroundStyle(Color.mist)
            SiteTypeFilterRow(
                selectedTypes: .constant([]),
                nightDivingOnly: .constant(true)
            )
        }
        .padding()
        .background(Color.midnight)
        .previewLayout(.sizeThatFits)
    }
}
#endif
