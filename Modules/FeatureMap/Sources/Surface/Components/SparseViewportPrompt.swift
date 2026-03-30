import SwiftUI
import UmiDB
import UmiDesignSystem

/// Shown when the current map viewport has too few sites.
/// Offers helpful next steps: nearest area, expand radius, or editorial fallback.
struct SparseViewportPrompt: View {
    let nearestArea: AreaSummary?
    let nearestRegion: RegionSummary?
    let onExpandSearch: () -> Void
    let onNavigateToArea: ((AreaSummary) -> Void)?
    let onNavigateToRegion: ((RegionSummary) -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // Nearest area card
            if let area = nearestArea {
                nearestAreaCard(area)
            }

            // Nearest destination fallback
            if nearestArea == nil, let region = nearestRegion {
                nearestDestinationCard(region)
            }

            // Expand search button
            Button(action: onExpandSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .medium))
                    Text("Expand search area")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.lagoon)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.lagoon.opacity(0.12))
                )
            }
            .buttonStyle(.plain)

            // Editorial fallback links
            editorialLinks
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func nearestAreaCard(_ area: AreaSummary) -> some View {
        Button {
            onNavigateToArea?(area)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.reef.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.reef)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Closest dive area")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                    Text(area.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.foam)
                    Text("\(area.siteCount) sites")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.reef)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.trench)
            )
        }
        .buttonStyle(.plain)
    }

    private func nearestDestinationCard(_ region: RegionSummary) -> some View {
        Button {
            onNavigateToRegion?(region)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.lagoon.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.lagoon)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Closest destination")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                    Text(region.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.foam)
                    Text("\(region.siteCount) sites · \(region.countryName)")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lagoon)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.trench)
            )
        }
        .buttonStyle(.plain)
    }

    private var editorialLinks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Explore popular regions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.mist)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                EditorialChip(title: "Beginner friendly", icon: "leaf")
                EditorialChip(title: "Warm water", icon: "sun.max")
                EditorialChip(title: "Wrecks", icon: "ferry")
            }
        }
    }
}

// MARK: - Editorial Chip

private struct EditorialChip: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Color.lagoon)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.foam)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.trench)
        )
    }
}
