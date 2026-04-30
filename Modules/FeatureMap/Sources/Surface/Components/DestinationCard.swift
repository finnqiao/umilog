import SwiftUI
import UmiDB
import UmiDesignSystem

/// Card for a dive destination (region) shown in the sheet at world zoom level.
/// Displays region name, country, site count, and a decorative icon.
struct DestinationCard: View {
    let region: RegionSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Destination icon
                ZStack {
                    Circle()
                        .fill(Color.lagoon.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.lagoon)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(region.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(region.countryName)
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                // Site count badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(region.siteCount > 0 ? "\(region.siteCount)" : "-")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lagoon)
                    Text(region.siteCount > 0 ? "sites" : "explore")
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.trench.opacity(0.5))
            )
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(region.name), \(region.countryName), \(region.siteCount) dive sites")
        .accessibilityHint("Double tap to explore this destination")
    }
}

/// Compact horizontal destination card for the peek carousel.
struct DestinationChipCard: View {
    let region: RegionSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lagoon)

                Text(region.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)

                Text(region.siteCount > 0 ? "\u{00B7} \(region.siteCount)" : "\u{00B7} Explore")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.trench)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
