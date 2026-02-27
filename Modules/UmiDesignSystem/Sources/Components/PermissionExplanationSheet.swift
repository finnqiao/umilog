import SwiftUI

/// Context shown before system permission prompts.
/// This helps users understand why access is requested.
public struct PermissionExplanationSheet: View {
    public enum PermissionType {
        case location
        case locationAlways
        case notifications
        case camera
        case photoLibrary
        case bluetooth

        var icon: String {
            switch self {
            case .location:
                return "location.fill"
            case .locationAlways:
                return "location.circle.fill"
            case .notifications:
                return "bell.badge.fill"
            case .camera:
                return "camera.fill"
            case .photoLibrary:
                return "photo.on.rectangle.angled"
            case .bluetooth:
                return "dot.radiowaves.left.and.right"
            }
        }

        var title: String {
            switch self {
            case .location:
                return "Allow Location Access"
            case .locationAlways:
                return "Enable Site Arrival Reminders"
            case .notifications:
                return "Allow Notifications"
            case .camera:
                return "Allow Camera Access"
            case .photoLibrary:
                return "Allow Photo Library Access"
            case .bluetooth:
                return "Allow Bluetooth Access"
            }
        }

        var explanation: String {
            switch self {
            case .location:
                return "UmiLog uses your location to show nearby dive sites and center the map around you."
            case .locationAlways:
                return "Always-on location lets UmiLog remind you to log a dive when you arrive at or leave a dive site."
            case .notifications:
                return "Notifications let UmiLog send dive reminders and important gear alerts."
            case .camera:
                return "Camera access lets you attach new photos to sightings and dive logs."
            case .photoLibrary:
                return "Photo Library access lets you attach existing photos to sightings and certification cards."
            case .bluetooth:
                return "Bluetooth access lets UmiLog connect to compatible dive computers for sync."
            }
        }
    }

    private let permission: PermissionType
    private let onContinue: () -> Void
    private let onSkip: () -> Void

    public init(
        permission: PermissionType,
        onContinue: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.permission = permission
        self.onContinue = onContinue
        self.onSkip = onSkip
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: permission.icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.top, 8)

            Text(permission.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(permission.explanation)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button("Not Now", action: onSkip)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    PermissionExplanationSheet(
        permission: .location,
        onContinue: {},
        onSkip: {}
    )
}
