import SwiftUI
import UmiDesignSystem

/// Floating card shown to first-time users showcasing a featured dive destination.
/// Appears after camera animation completes and auto-dismisses after 4 seconds.
struct FeaturedDestinationCard: View {
    let destination: FeaturedDestination
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var dismissTask: Task<Void, Never>?

    private let autoDismissDelay: TimeInterval = 4.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with sparkle icon
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.reef)
                Text("Discover")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.reef)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.mist.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.kelp.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
            }

            // Destination name
            Text(destination.displayName)
                .font(.headline)
                .foregroundStyle(Color.foam)

            // Tagline
            Text(destination.tagline)
                .font(.subheadline)
                .foregroundStyle(Color.mist)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.lagoon.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
            scheduleAutoDismiss()
        }
        .onDisappear {
            dismissTask?.cancel()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Featured destination: \(destination.displayName). \(destination.tagline)")
        .accessibilityHint("Tap anywhere on the map to explore")
    }

    private func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    private func scheduleAutoDismiss() {
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(autoDismissDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.abyss
        VStack {
            FeaturedDestinationCard(
                destination: FeaturedDestination(
                    regionId: "red-sea-egypt",
                    displayName: "Red Sea, Egypt",
                    tagline: "Crystal waters and legendary wrecks",
                    latitude: 27.2,
                    longitude: 34.0,
                    zoomLevel: 6.5
                ),
                onDismiss: { print("Dismissed") }
            )
            .padding(.top, 60)
            Spacer()
        }
    }
}
