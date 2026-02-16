import SwiftUI
import UmiDesignSystem

/// Main coordinator view for the onboarding wizard flow
public struct OnboardingWizardView: View {
    @StateObject private var state = OnboardingState()
    @Environment(\.colorScheme) private var colorScheme

    private let onComplete: () -> Void

    public init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Stepper bar (hidden on welcome and completion)
                if state.currentStep != .welcome && state.currentStep != .completion {
                    OnboardingStepperBar(
                        currentStep: state.currentStep,
                        totalSteps: state.totalSteps
                    )
                    .padding(.top, 16)
                }

                // Step content
                TabView(selection: $state.currentStep) {
                    WelcomeStepView(state: state)
                        .tag(OnboardingState.Step.welcome)

                    ExperienceLevelStepView(state: state)
                        .tag(OnboardingState.Step.experienceLevel)

                    CertificationStepView(state: state)
                        .tag(OnboardingState.Step.certifications)

                    LocationPermissionStepView(state: state)
                        .tag(OnboardingState.Step.locationPermission)

                    ThemePreferenceStepView(state: state)
                        .tag(OnboardingState.Step.themePreference)

                    CompletionStepView(state: state, onComplete: onComplete)
                        .tag(OnboardingState.Step.completion)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth(duration: 0.35), value: state.currentStep)
            }
        }
        .preferredColorScheme(state.underwaterThemeEnabled ? .dark : colorScheme)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: state.underwaterThemeEnabled
                ? [Color.waterSurface, Color.waterDeep]
                : [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Public Module Exports

public extension OnboardingWizardView {
    /// Check if onboarding has been completed
    static func isCompleted(defaults: UserDefaults = .standard) -> Bool {
        OnboardingState.isCompleted(defaults: defaults)
    }

    /// Reset onboarding state (for testing)
    static func reset(defaults: UserDefaults = .standard) {
        OnboardingState.reset(defaults: defaults)
    }
}

#Preview("Full Flow") {
    OnboardingWizardView {
        print("Completed!")
    }
}

#Preview("Dark Theme") {
    OnboardingWizardView()
        .preferredColorScheme(.dark)
}
