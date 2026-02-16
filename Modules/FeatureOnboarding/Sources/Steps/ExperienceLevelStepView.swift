import SwiftUI
import UmiDesignSystem

/// Second step - user selects their diving experience level
public struct ExperienceLevelStepView: View {
    @ObservedObject var state: OnboardingState

    public init(state: OnboardingState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Text("What's your experience level?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("This helps us personalize your dive site recommendations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            // Experience level cards
            VStack(spacing: 12) {
                ForEach(ExperienceLevel.allCases) { level in
                    ExperienceLevelCard(
                        level: level,
                        isSelected: state.selectedExperienceLevel == level,
                        action: {
                            withAnimation(.smooth(duration: 0.2)) {
                                state.selectedExperienceLevel = level
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 24)

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
                    Text(state.selectedExperienceLevel == nil ? "Skip" : "Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            state.selectedExperienceLevel == nil
                                ? AnyShapeStyle(.secondary)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color.lagoon, Color.oceanBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

private struct ExperienceLevelCard: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: level.iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.white : Color.lagoon)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? Color.lagoon : Color.lagoon.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(level.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.lagoon)
                }
            }
            .padding(16)
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
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExperienceLevelStepView(state: OnboardingState())
        .preferredColorScheme(.dark)
}
