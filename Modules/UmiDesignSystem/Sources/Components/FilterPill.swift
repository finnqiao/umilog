import SwiftUI

/// Reusable filter pill component for filter chips.
/// Used in both History and Map tabs for consistent filter UI.
public struct FilterPill: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    public init(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        selectedColor: Color = .lagoon,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.selectedColor = selectedColor
        self.action = action
    }

    public var body: some View {
        Button(action: {
            action()
            Haptics.soft()
        }) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? Color.foam : Color.mist)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? selectedColor : Color.trench)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Filter Pills") {
    struct PreviewWrapper: View {
        @State private var selected: Set<String> = ["Reef"]

        var body: some View {
            HStack(spacing: 8) {
                FilterPill(
                    title: "All",
                    isSelected: selected.isEmpty,
                    action: { selected.removeAll() }
                )
                FilterPill(
                    title: "Reef",
                    isSelected: selected.contains("Reef"),
                    selectedColor: .reef,
                    action: { toggle("Reef") }
                )
                FilterPill(
                    title: "Wreck",
                    icon: "ferry.fill",
                    isSelected: selected.contains("Wreck"),
                    selectedColor: .amber,
                    action: { toggle("Wreck") }
                )
            }
            .padding()
            .background(Color.midnight)
        }

        func toggle(_ item: String) {
            if selected.contains(item) {
                selected.remove(item)
            } else {
                selected.insert(item)
            }
        }
    }
    return PreviewWrapper()
}
