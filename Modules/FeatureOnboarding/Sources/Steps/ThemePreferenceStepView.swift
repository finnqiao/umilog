import SwiftUI
import UmiDesignSystem

/// Fifth step - user selects theme preference
public struct ThemePreferenceStepView: View {
    @ObservedObject var state: OnboardingState

    public init(state: OnboardingState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Text("Choose your theme")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("Experience UmiLog with our signature underwater aesthetic")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 20)

            Spacer()

            // Theme preview cards
            HStack(spacing: 16) {
                ThemeCard(
                    title: "Underwater",
                    description: "Immersive ocean theme with animated effects",
                    isSelected: state.underwaterThemeEnabled,
                    previewColors: [Color.waterSurface, Color.waterDeep, Color.lagoon],
                    action: {
                        withAnimation(.smooth(duration: 0.3)) {
                            state.underwaterThemeEnabled = true
                        }
                    }
                )

                ThemeCard(
                    title: "Classic",
                    description: "Clean and minimal interface",
                    isSelected: !state.underwaterThemeEnabled,
                    previewColors: [Color(.systemBackground), Color(.secondarySystemBackground), .gray],
                    action: {
                        withAnimation(.smooth(duration: 0.3)) {
                            state.underwaterThemeEnabled = false
                        }
                    }
                )
            }
            .padding(.horizontal, 24)

            // Theme features
            if state.underwaterThemeEnabled {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.reef)
                        Text("Animated caustics and bubbles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(Color.reef)
                        Text("Deep ocean color palette")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Animations respect Reduce Motion accessibility setting")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 12) {
                Button(action: { state.previousStep() }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button(action: { state.nextStep() }) {
                    Text("Continue")
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
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

private struct ThemeCard: View {
    let title: String
    let description: String
    let isSelected: Bool
    let previewColors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: previewColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 100)
                    .overlay(
                        VStack {
                            HStack {
                                Circle()
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Circle()
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Circle()
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Spacer()
                            }
                            .padding(12)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.2))
                                .frame(height: 24)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                        }
                    )

                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? Color.lagoon : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.lagoon)
                        .background(Circle().fill(.white))
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ThemePreferenceStepView(state: OnboardingState())
        .preferredColorScheme(.dark)
}
