import SwiftUI
import UmiCoreKit

/// Tracks onboarding wizard state and user selections
@MainActor
public final class OnboardingState: ObservableObject {
    // MARK: - Step Navigation

    public enum Step: Int, CaseIterable {
        case welcome = 0
        case experienceLevel = 1
        case certifications = 2
        case locationPermission = 3
        case themePreference = 4
        case completion = 5

        public var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .experienceLevel: return "Experience"
            case .certifications: return "Certifications"
            case .locationPermission: return "Location"
            case .themePreference: return "Theme"
            case .completion: return "Ready"
            }
        }

        public var canSkip: Bool {
            switch self {
            case .welcome, .completion:
                return false
            case .experienceLevel, .certifications, .locationPermission, .themePreference:
                return true
            }
        }
    }

    @Published public var currentStep: Step = .welcome
    @Published public var isAnimating: Bool = false

    // MARK: - User Selections

    @Published public var selectedExperienceLevel: ExperienceLevel?
    @Published public var selectedCertifications: Set<Certification> = []
    @Published public var locationPermissionGranted: Bool = false
    @Published public var underwaterThemeEnabled: Bool = true

    // MARK: - Computed Properties

    public var totalSteps: Int { Step.allCases.count }

    public var progress: Double {
        Double(currentStep.rawValue) / Double(totalSteps - 1)
    }

    public var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .experienceLevel:
            return selectedExperienceLevel != nil
        case .certifications:
            return true // Optional
        case .locationPermission:
            return true // Can skip
        case .themePreference:
            return true
        case .completion:
            return true
        }
    }

    public var isFirstStep: Bool {
        currentStep == .welcome
    }

    public var isLastStep: Bool {
        currentStep == .completion
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation

    public func nextStep() {
        guard let nextIndex = Step(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.smooth(duration: 0.35)) {
            currentStep = nextIndex
        }
    }

    public func previousStep() {
        guard let prevIndex = Step(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.smooth(duration: 0.35)) {
            currentStep = prevIndex
        }
    }

    public func skipToStep(_ step: Step) {
        withAnimation(.smooth(duration: 0.35)) {
            currentStep = step
        }
    }

    // MARK: - Profile Generation

    public func buildProfile() -> UserProfile {
        UserProfile(
            experienceLevel: selectedExperienceLevel,
            certifications: selectedCertifications,
            divingStartDate: nil,
            prefersDarkTheme: underwaterThemeEnabled
        )
    }

    // MARK: - Completion

    public func completeOnboarding(defaults: UserDefaults = .standard) {
        // Save user profile
        let profile = buildProfile()
        profile.save(to: defaults)

        // Mark onboarding as completed
        defaults.set(true, forKey: "app.umilog.onboardingCompleted")

        // Save theme preference separately for AppState
        defaults.set(underwaterThemeEnabled, forKey: AppConstants.UserDefaultsKeys.underwaterThemeEnabled)
        // Backward compatibility with older builds that used the legacy key.
        defaults.set(underwaterThemeEnabled, forKey: "underwaterThemeEnabled")
    }

    public static func isCompleted(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: "app.umilog.onboardingCompleted")
    }

    public static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "app.umilog.onboardingCompleted")
        UserProfile.clear(from: defaults)
    }
}
