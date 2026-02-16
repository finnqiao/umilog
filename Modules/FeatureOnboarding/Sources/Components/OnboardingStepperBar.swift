import SwiftUI
import UmiDesignSystem

/// Visual progress indicator for onboarding steps
public struct OnboardingStepperBar: View {
    let currentStep: OnboardingState.Step
    let totalSteps: Int

    public init(currentStep: OnboardingState.Step, totalSteps: Int) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                StepDot(
                    isCompleted: index < currentStep.rawValue,
                    isCurrent: index == currentStep.rawValue
                )
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(totalSteps)")
        .accessibilityValue(currentStep.title)
    }
}

private struct StepDot: View {
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)
            .animation(.smooth(duration: 0.2), value: isCurrent)
            .animation(.smooth(duration: 0.2), value: isCompleted)
    }

    private var fillColor: Color {
        if isCurrent {
            return Color.lagoon
        } else if isCompleted {
            return Color.lagoon.opacity(0.6)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        OnboardingStepperBar(currentStep: .welcome, totalSteps: 6)
        OnboardingStepperBar(currentStep: .experienceLevel, totalSteps: 6)
        OnboardingStepperBar(currentStep: .certifications, totalSteps: 6)
        OnboardingStepperBar(currentStep: .locationPermission, totalSteps: 6)
        OnboardingStepperBar(currentStep: .themePreference, totalSteps: 6)
        OnboardingStepperBar(currentStep: .completion, totalSteps: 6)
    }
    .padding()
    .preferredColorScheme(.dark)
}
