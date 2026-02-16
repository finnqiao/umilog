import SwiftUI
import UmiDesignSystem

/// Final step - confirms setup completion and invites user to start exploring
public struct CompletionStepView: View {
    @ObservedObject var state: OnboardingState
    let onComplete: () -> Void

    @State private var showConfetti = false

    public init(state: OnboardingState, onComplete: @escaping () -> Void) {
        self.state = state
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Success animation
            ZStack {
                // Animated rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.lagoon.opacity(0.6), Color.reef.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(80 + index * 40), height: CGFloat(80 + index * 40))
                        .opacity(showConfetti ? 0.8 - Double(index) * 0.2 : 0)
                        .scaleEffect(showConfetti ? 1 : 0.5)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(Double(index) * 0.1),
                            value: showConfetti
                        )
                }

                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.lagoon, Color.reef],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showConfetti ? 1 : 0.5)
                    .opacity(showConfetti ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showConfetti)
            }

            // Completion message
            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("Your dive log is ready. Start exploring and logging your underwater adventures.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Quick feature tutorial
            VStack(spacing: 16) {
                Text("Quick Tips")
                    .font(.headline)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 12) {
                    QuickTipRow(
                        icon: "map.fill",
                        title: "Explore",
                        description: "Pinch to zoom, tap pins to view site details"
                    )

                    QuickTipRow(
                        icon: "plus.circle.fill",
                        title: "Log Dives",
                        description: "Tap the + button to start logging a dive"
                    )

                    QuickTipRow(
                        icon: "bookmark.fill",
                        title: "Save Sites",
                        description: "Bookmark sites to your wishlist for later"
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 24)

            // Profile summary
            if state.selectedExperienceLevel != nil || !state.selectedCertifications.isEmpty {
                VStack(spacing: 8) {
                    if let level = state.selectedExperienceLevel {
                        HStack(spacing: 8) {
                            Image(systemName: level.iconName)
                                .foregroundStyle(Color.lagoon)
                            Text(level.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !state.selectedCertifications.isEmpty {
                        Text(state.selectedCertifications.map { $0.shortName }.joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }

            Spacer()

            // Start exploring button
            Button(action: completeOnboarding) {
                HStack(spacing: 8) {
                    Text("Start Exploring")
                        .font(.headline)

                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.lagoon, Color.oceanBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }

    private func completeOnboarding() {
        state.completeOnboarding()
        onComplete()
    }
}

// MARK: - Quick Tip Row

private struct QuickTipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.lagoon)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    CompletionStepView(state: OnboardingState()) {
        print("Onboarding completed")
    }
    .preferredColorScheme(.dark)
}
