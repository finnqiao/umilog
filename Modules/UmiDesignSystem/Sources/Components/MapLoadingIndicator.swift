import SwiftUI

/// Sonar-ring pulse indicator for the map cold-start placeholder.
/// Concentric rings pulse outward in `pinDefault` cyan at low opacity.
/// Respects Reduce Motion: shows a static ring when enabled.
public struct MapLoadingIndicator: View {
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ringCount = 3
    private let color = Color.pinDefault

    public init() {}

    public var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(reduceMotion ? 0.15 : (animate ? 0.0 : 0.25)), lineWidth: 1.5)
                    .frame(width: ringSize(for: index), height: ringSize(for: index))
                    .scaleEffect(reduceMotion ? 1.0 : (animate ? 1.6 : 1.0))
                    .animation(
                        reduceMotion ? nil :
                            .easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: animate
                    )
            }

            // Center dot
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: 8, height: 8)
        }
        .onAppear {
            if !reduceMotion {
                animate = true
            }
        }
    }

    private func ringSize(for index: Int) -> CGFloat {
        CGFloat(40 + index * 20)
    }
}
