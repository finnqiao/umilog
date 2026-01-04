import SwiftUI
import UmiDesignSystem
import UmiDB

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
            // Header with thumbnail, info, and close button
            HStack(spacing: 12) {
                // Site thumbnail
                AsyncSiteImage(
                    siteId: site.id,
                    siteType: site.type,
                    imageURL: mediaURL,
                    size: 56,
                    cornerRadius: 10
                )

                // Site info
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
                }

                Spacer()

                // Close button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.mist)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.kelp.opacity(0.5))
                        )
                }
                .accessibilityLabel("Close")
            }

            // Action buttons
            HStack(spacing: 10) {
                // View Details button (secondary)
                Button(action: onViewDetails) {
                    Text("View Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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

                // Log Dive button (primary)
                Button(action: onLogDive) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Log Dive Here")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.abyss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.reef)
                    )
                }
                .accessibilityLabel("Start logging dive at \(site.name)")
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
