import SwiftUI

/// An inline validation banner for displaying error messages.
/// Used to provide feedback when form validation fails.
public struct ValidationBanner: View {
    let message: String
    @Binding var isShowing: Bool
    var autoDismissAfter: TimeInterval?

    public init(message: String, isShowing: Binding<Bool>, autoDismissAfter: TimeInterval? = 3.0) {
        self.message = message
        self._isShowing = isShowing
        self.autoDismissAfter = autoDismissAfter
    }

    public var body: some View {
        if isShowing {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.amber)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowing = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.amber.opacity(0.15))
            .cornerRadius(12)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
            .onAppear {
                scheduleAutoDismiss()
            }
        }
    }

    private func scheduleAutoDismiss() {
        guard let delay = autoDismissAfter else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if isShowing {
                withAnimation(.easeOut(duration: 0.2)) {
                    isShowing = false
                }
            }
        }
    }
}

/// A simpler inline validation message without the banner styling.
/// Useful for smaller spaces or inline form validation.
public struct ValidationMessage: View {
    let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(Color.amber)
    }
}

#Preview("Validation Banner") {
    struct PreviewWrapper: View {
        @State private var showBanner = true

        var body: some View {
            VStack(spacing: 20) {
                ValidationBanner(
                    message: "Please select a dive site",
                    isShowing: $showBanner
                )

                Button("Show Banner") {
                    withAnimation {
                        showBanner = true
                    }
                }

                ValidationMessage("Field is required")
            }
            .padding()
        }
    }
    return PreviewWrapper()
}
