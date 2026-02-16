import SwiftUI
import UmiDB
import UmiDesignSystem

/// Quick-access chips for popular diving regions, shown above the map.
/// Allows fast navigation to high-density regions from anywhere.
struct PopularRegionChips: View {
    let regions: [RegionSummary]
    let onTap: (RegionSummary) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(regions) { region in
                    RegionQuickChip(region: region) {
                        onTap(region)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Region Quick Chip

private struct RegionQuickChip: View {
    let region: RegionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.lagoon)

                Text(region.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)
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
        .accessibilityLabel("Go to \(region.name)")
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
                    onTap: { _ in }
                )
                Spacer()
            }
            .padding(.top, 60)
        }
    }
}
#endif
