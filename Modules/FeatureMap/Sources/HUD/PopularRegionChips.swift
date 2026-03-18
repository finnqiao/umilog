import SwiftUI
import UmiDB
import UmiDesignSystem

/// Quick-access chips for popular diving regions, shown above the map.
/// Allows fast navigation to high-density regions from anywhere.
struct PopularRegionChips: View {
    let regions: [RegionSummary]
    var selectedRegionId: String?
    let onTap: (RegionSummary) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(regions) { region in
                    let isSelected = isRegionSelected(region)
                    RegionQuickChip(region: region, isSelected: isSelected) {
                        onTap(region)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func isRegionSelected(_ region: RegionSummary) -> Bool {
        guard let selectedId = selectedRegionId else { return false }
        return region.id == selectedId || region.name == selectedId
    }
}

// MARK: - Region Quick Chip

private struct RegionQuickChip: View {
    let region: RegionSummary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "mappin.circle.fill" : "mappin.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.foam : Color.lagoon)

                Text(region.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.lagoon : Color.abyss.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to \(region.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#if DEBUG
struct PopularRegionChips_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.trench
                .ignoresSafeArea()

            VStack {
                PopularRegionChips(
                    regions: RegionSummary.popular,
                    selectedRegionId: "caribbean",
                    onTap: { _ in }
                )
                Spacer()
            }
            .padding(.top, 60)
        }
    }
}
#endif
