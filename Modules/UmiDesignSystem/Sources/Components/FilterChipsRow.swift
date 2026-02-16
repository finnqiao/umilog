import SwiftUI

/// Horizontal scrolling row of filter chips.
/// Reusable component for both History and Map tabs.
public struct FilterChipsRow<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content
            }
            .padding(.horizontal, 16)
        }
    }
}

/// Vertical divider for separating filter groups.
public struct FilterDivider: View {
    public init() {}

    public var body: some View {
        Capsule()
            .fill(Color.ocean.opacity(0.3))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }
}

#Preview("Filter Chips Row") {
    FilterChipsRow {
        FilterPill(title: "All", isSelected: true, action: {})
        FilterPill(title: "Saved", icon: "star.fill", isSelected: false, action: {})
        FilterPill(title: "Logged", icon: "checkmark.circle.fill", isSelected: false, action: {})

        FilterDivider()

        FilterPill(title: "Beginner", isSelected: false, selectedColor: .difficultyBeginner, action: {})
        FilterPill(title: "Intermediate", isSelected: true, selectedColor: .difficultyIntermediate, action: {})
        FilterPill(title: "Advanced", isSelected: false, selectedColor: .difficultyAdvanced, action: {})
    }
    .padding(.vertical)
    .background(Color.midnight)
}
