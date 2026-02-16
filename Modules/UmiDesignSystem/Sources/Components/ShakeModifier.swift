import SwiftUI

/// A view modifier that applies a shake animation to a view.
/// Use this to provide feedback when a user taps a button with invalid state.
public struct ShakeModifier: ViewModifier {
    @Binding var trigger: Bool
    var intensity: CGFloat

    public init(trigger: Binding<Bool>, intensity: CGFloat = 10) {
        self._trigger = trigger
        self.intensity = intensity
    }

    @State private var offset: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    performShake()
                }
            }
    }

    private func performShake() {
        let shakeDuration = 0.05
        let shakeCount = 4

        Task { @MainActor in
            for i in 0..<shakeCount {
                withAnimation(.linear(duration: shakeDuration)) {
                    offset = i.isMultiple(of: 2) ? intensity : -intensity
                }
                try? await Task.sleep(nanoseconds: UInt64(shakeDuration * 1_000_000_000))
            }
            withAnimation(.linear(duration: shakeDuration)) {
                offset = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(shakeDuration * 1_000_000_000))
            trigger = false
        }
    }
}

public extension View {
    /// Applies a shake animation when triggered.
    /// - Parameters:
    ///   - trigger: Binding that triggers the shake when set to true.
    ///              Automatically resets to false after animation completes.
    ///   - intensity: How far the view moves during the shake (default: 10 points)
    func shake(trigger: Binding<Bool>, intensity: CGFloat = 10) -> some View {
        modifier(ShakeModifier(trigger: trigger, intensity: intensity))
    }
}

#Preview("Shake Animation") {
    struct PreviewWrapper: View {
        @State private var shakeIt = false

        var body: some View {
            VStack(spacing: 20) {
                Button("Tap to Shake") {
                    shakeIt = true
                }
                .padding()
                .background(Color.lagoon)
                .foregroundStyle(.white)
                .cornerRadius(8)
                .shake(trigger: $shakeIt)

                Button("Trigger Shake") {
                    shakeIt = true
                }
            }
        }
    }
    return PreviewWrapper()
}
