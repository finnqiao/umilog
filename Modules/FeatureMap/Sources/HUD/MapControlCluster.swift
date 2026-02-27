import SwiftUI
import UmiDesignSystem

/// Thumb-zone map controls anchored near the bottom-right corner.
struct MapControlCluster: View {
    let isBoatModeEnabled: Bool
    let onLayerToggle: () -> Void
    let onLocateMe: () -> Void
    let onToggleBoatMode: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            MapControlButton(
                icon: "map.fill",
                accessibilityLabel: "Map layers",
                accessibilityHint: "Open map filters and layer options",
                action: onLayerToggle
            )

            MapControlButton(
                icon: isBoatModeEnabled ? "location.north.line.fill" : "location.fill",
                accessibilityLabel: "Locate me",
                accessibilityHint: "Center the map on your current location",
                action: onLocateMe
            )
            .contextMenu {
                Button(isBoatModeEnabled ? "Disable Boat Mode" : "Enable Boat Mode") {
                    onToggleBoatMode()
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MapControlButton: View {
    let icon: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.foam)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.foam.opacity(0.12), lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}

#Preview {
    ZStack {
        Color.abyss.ignoresSafeArea()
        VStack {
            Spacer()
            HStack {
                Spacer()
                MapControlCluster(
                    isBoatModeEnabled: false,
                    onLayerToggle: {},
                    onLocateMe: {},
                    onToggleBoatMode: {}
                )
                .padding()
            }
        }
    }
}
