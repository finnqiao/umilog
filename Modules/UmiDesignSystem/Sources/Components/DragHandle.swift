import SwiftUI

/// Standard iOS-style drag handle for bottom sheets. Single capsule, 36×5pt,
/// replaces ad-hoc chevron/arrow treatments.
///
/// Plan §3e / §7: one shared handle primitive used by every bottom sheet.
public struct DragHandle: View {
    private let width: CGFloat
    private let height: CGFloat
    private let color: Color

    public init(
        width: CGFloat = 36,
        height: CGFloat = 5,
        color: Color = .mist
    ) {
        self.width = width
        self.height = height
        self.color = color
    }

    public var body: some View {
        Capsule()
            .fill(color.opacity(0.5))
            .frame(width: width, height: height)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 0) {
        DragHandle()
        Text("Sheet content")
            .foregroundStyle(Color.foam)
            .frame(maxWidth: .infinity)
            .padding()
    }
    .background(Color.midnight)
}
