import SwiftUI
import UmiDesignSystem
import UmiDB
import UmiLocationKit

/// A floating callout card that appears when tapping a dive site marker on the map.
/// Shows site preview with thumbnail, name, depth and action buttons.
struct SiteCalloutCard: View {
    let site: DiveSite
    let mediaURL: URL?
    var onViewDetails: () -> Void
    var onLogDive: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header: thumbnail + info + navigate icon + close button
            HStack(spacing: 12) {
                AsyncSiteImage(
                    siteId: site.id,
                    siteType: site.type,
                    imageURL: mediaURL,
                    size: 52,
                    cornerRadius: 10
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.foam)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                        Text(depthText)
                            .font(.caption)
                    }
                    .foregroundStyle(Color.mist)

                    HStack(spacing: 6) {
                        Text(site.type.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.foam)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.ocean.opacity(0.5))
                            .clipShape(Capsule())

                        Circle()
                            .fill(calloutDifficultyColor(site.difficulty))
                            .frame(width: 5, height: 5)

                        Text(site.difficulty.rawValue)
                            .font(.caption)
                            .foregroundStyle(Color.mist)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }

                Spacer()

                // Navigate icon — inline with header to free up action row space
                Button {
                    SiteNavigationService.navigate(to: site)
                    Haptics.soft()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.lagoon)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.lagoon.opacity(0.15)))
                }
                .accessibilityLabel("Open \(site.name) in Maps")

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.mist)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.kelp.opacity(0.5)))
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("diveMap.sitePreview.close")
            }

            // Two equal-width action buttons
            HStack(spacing: 8) {
                Button(action: onViewDetails) {
                    Text("View Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.trench)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.ocean.opacity(0.4), lineWidth: 1)
                        )
                }
                .accessibilityLabel("View details for \(site.name)")
                .accessibilityIdentifier("diveMap.sitePreview.viewDetails")

                Button(action: onLogDive) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Log Dive")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.abyss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.reef)
                    )
                }
                .accessibilityLabel("Start logging dive at \(site.name)")
                .accessibilityIdentifier("diveMap.sitePreview.logDive")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.trench)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.lagoon.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("diveMap.sitePreview")
    }

    private func calloutDifficultyColor(_ difficulty: DiveSite.Difficulty) -> Color {
        switch difficulty {
        case .beginner: return .difficultyBeginner
        case .intermediate: return .difficultyIntermediate
        case .advanced: return .difficultyAdvanced
        }
    }

    private var depthText: String {
        if site.maxDepth > 0 {
            return String(format: "%.1fm depth", site.maxDepth)
        } else {
            return "Depth unknown"
        }
    }
}

#if DEBUG
struct SiteCalloutCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.abyss
                .ignoresSafeArea()

            VStack {
                Spacer()

                SiteCalloutCard(
                    site: DiveSite(
                        id: "blue_corner",
                        name: "Blue Corner Wall",
                        location: "Palau, Micronesia",
                        latitude: 7.0,
                        longitude: 134.0,
                        region: "Micronesia",
                        averageDepth: 15.0,
                        maxDepth: 18.30,
                        averageTemp: 28.0,
                        averageVisibility: 30.0,
                        type: .reef
                    ),
                    mediaURL: nil,
                    onViewDetails: { print("View Details") },
                    onLogDive: { print("Log Dive") },
                    onDismiss: { print("Dismiss") }
                )
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 200)
            }
        }
    }
}
#endif
