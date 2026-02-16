import SwiftUI
import UmiDesignSystem

/// First step of onboarding - introduces the app's value proposition
public struct WelcomeStepView: View {
    @ObservedObject var state: OnboardingState

    public init(state: OnboardingState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // App Icon and Title
            VStack(spacing: 16) {
                Image(systemName: "water.waves")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.lagoon, Color.reef],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Welcome to UmiLog")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("Your personal dive companion")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Feature highlights
            VStack(spacing: 20) {
                FeatureRow(
                    icon: "map.fill",
                    title: "Discover",
                    description: "Explore 1,000+ dive sites worldwide"
                )

                FeatureRow(
                    icon: "pencil.and.list.clipboard",
                    title: "Log",
                    description: "Track every dive with rich details"
                )

                FeatureRow(
                    icon: "fish.fill",
                    title: "Identify",
                    description: "Catalog the marine life you encounter"
                )

                FeatureRow(
                    icon: "icloud.fill",
                    title: "Sync",
                    description: "Access your logs on all your devices"
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Get Started button
            Button(action: { state.nextStep() }) {
                Text("Get Started")
                    .font(.headline)
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
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.lagoon)
                .frame(width: 44, height: 44)
                .background(Color.lagoon.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    WelcomeStepView(state: OnboardingState())
        .preferredColorScheme(.dark)
}
