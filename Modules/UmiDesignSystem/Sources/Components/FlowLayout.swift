import SwiftUI

/// A layout that arranges views in a flowing manner, wrapping to new lines as needed.
/// Useful for displaying filter chips or tags that need to wrap.
public struct FlowLayout: Layout {
    public var spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func flowLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentX + size.width)
            currentX += size.width + spacing
        }

        let finalHeight = currentY + lineHeight
        let finalWidth = min(maxX, maxWidth)

        return (CGSize(width: finalWidth, height: finalHeight), positions)
    }
}

#Preview("Flow Layout") {
    FlowLayout(spacing: 8) {
        ForEach(["Reef", "Wreck", "Wall", "Cave", "Shore", "Drift", "Beginner", "Intermediate", "Advanced"], id: \.self) { item in
            FilterPill(title: item, isSelected: item == "Reef", action: {})
        }
    }
    .padding()
    .background(Color.midnight)
}
