import SwiftUI
import UmiDB
import UmiDesignSystem

/// Beautiful share card for dive logs
struct DiveShareCard: View {
    let dive: DiveLog
    let site: DiveSite?

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.oceanBlue, .diveTeal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                VStack(alignment: .leading, spacing: 4) {
                    if let site = site {
                        Text(site.name)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text(site.location)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text("Dive Log")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                }
                .padding(20)
            }

            // Stats grid
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    StatBox(
                        icon: "arrow.down",
                        value: String(format: "%.1f", dive.maxDepth),
                        unit: "m",
                        label: "Max Depth",
                        color: .diveTeal
                    )
                    Divider().frame(height: 60)
                    StatBox(
                        icon: "clock",
                        value: "\(dive.bottomTime)",
                        unit: "min",
                        label: "Bottom Time",
                        color: .oceanBlue
                    )
                }

                Divider()

                HStack(spacing: 0) {
                    StatBox(
                        icon: "thermometer",
                        value: String(format: "%.0f", dive.temperature),
                        unit: "°C",
                        label: "Water Temp",
                        color: .amber
                    )
                    Divider().frame(height: 60)
                    StatBox(
                        icon: "eye",
                        value: String(format: "%.0f", dive.visibility),
                        unit: "m",
                        label: "Visibility",
                        color: .seaGreen
                    )
                }

                // Date
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(formatDate(dive.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if dive.signed {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.seaGreen)
                            Text("Verified")
                                .font(.caption)
                                .foregroundStyle(Color.seaGreen)
                        }
                    }
                }
                .padding(.top, 4)

                // Notes (if any)
                if !dive.notes.isEmpty {
                    Text(dive.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))

            // Footer branding
            HStack {
                Image(systemName: "water.waves")
                    .foregroundStyle(Color.diveTeal)
                Text("UmiLog")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("umilog.app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
        }
        .frame(width: 340)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

private struct StatBox: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Share Card Generator

@MainActor
struct ShareCardGenerator {
    /// Generate a shareable image from a dive log
    @MainActor
    static func generateImage(for dive: DiveLog, site: DiveSite?) -> UIImage? {
        let cardView = DiveShareCard(dive: dive, site: site)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0 // High resolution
        return renderer.uiImage
    }

    /// Create a share activity controller for the dive
    @MainActor
    static func share(dive: DiveLog, site: DiveSite?) -> [Any] {
        var items: [Any] = []

        // Generate image
        if let image = generateImage(for: dive, site: site) {
            items.append(image)
        }

        // Add text summary
        let siteName = site?.name ?? "Dive"
        let summary = """
        \(siteName)
        Depth: \(String(format: "%.1fm", dive.maxDepth)) | Time: \(dive.bottomTime)min
        Logged with UmiLog
        """
        items.append(summary)

        return items
    }
}

#Preview {
    DiveShareCard(
        dive: DiveLog(
            date: Date(),
            startTime: Date(),
            maxDepth: 24.5,
            averageDepth: 18.2,
            bottomTime: 42,
            startPressure: 200,
            endPressure: 60,
            temperature: 26,
            visibility: 15,
            current: .light,
            conditions: .good,
            notes: "Beautiful dive! Saw manta rays and a sea turtle.",
            signed: true
        ),
        site: nil
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
