import SwiftUI
import UmiDesignSystem

/// Segmented control for switching between entry modes (Explore/Trips/Near me).
/// Displayed in the bottom surface header.
struct EntryModeSelector: View {
    @Binding var currentMode: MapEntryMode
    let nearMeSiteCount: Int?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MapEntryMode.allCases) { mode in
                ModeTab(
                    mode: mode,
                    isSelected: currentMode == mode,
                    badge: badgeText(for: mode)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentMode = mode
                    }
                    Haptics.soft()
                }
            }
        }
        .background(Color.trench)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func badgeText(for mode: MapEntryMode) -> String? {
        guard mode == .nearMe else { return nil }

        if let count = nearMeSiteCount {
            return count == 0 ? "(0)" : nil
        }
        return nil
    }
}

// MARK: - Mode Tab

private struct ModeTab: View {
    let mode: MapEntryMode
    let isSelected: Bool
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 12, weight: .medium))

                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)

                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                }
            }
            .foregroundStyle(isSelected ? Color.foam : Color.mist)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.lagoon.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName) mode")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#if DEBUG
struct EntryModeSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EntryModeSelector(
                currentMode: .constant(.explore),
                nearMeSiteCount: nil
            )

            EntryModeSelector(
                currentMode: .constant(.nearMe),
                nearMeSiteCount: 0
            )

            EntryModeSelector(
                currentMode: .constant(.trips),
                nearMeSiteCount: 5
            )
        }
        .padding()
        .background(Color.abyss)
    }
}
#endif
