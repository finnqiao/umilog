import SwiftUI
import UmiDB
import UmiDesignSystem

/// Card for a dive area shown in the sheet at regional zoom level.
/// Displays area name, region, and site count.
struct AreaCard: View {
    let area: AreaSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Area icon
                ZStack {
                    Circle()
                        .fill(Color.reef.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "map")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.reef)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(area.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)

                    if let regionName = area.regionName {
                        Text(regionName)
                            .font(.caption)
                            .foregroundStyle(Color.mist)
                    }
                }

                Spacer()

                // Site count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(area.siteCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.reef)
                    Text("sites")
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.trench.opacity(0.5))
            )
        }
        .buttonStyle(AreaCardButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(area.name), \(area.siteCount) dive sites")
        .accessibilityHint("Double tap to explore this area")
    }
}

/// Compact horizontal area chip for peek carousel at regional zoom.
struct AreaChipCard: View {
    let area: AreaSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.reef)

                Text(area.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)

                Text("\u{00B7} \(area.siteCount)")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
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

private struct AreaCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
