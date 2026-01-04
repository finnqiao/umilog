import SwiftUI

/// Reusable view for displaying permission denial states with actionable CTAs
public struct PermissionDeniedView: View {
    public enum PermissionType {
        case location
        case notification

        var icon: String {
            switch self {
            case .location: return "location.slash"
            case .notification: return "bell.slash"
            }
        }

        var title: String {
            switch self {
            case .location: return "Location Access Required"
            case .notification: return "Notifications Disabled"
            }
        }

        var message: String {
            switch self {
            case .location:
                return "UmiLog needs location access to find nearby dive sites and log dives at your current position."
            case .notification:
                return "Enable notifications to get reminders when you arrive at dive sites."
            }
        }

        var buttonStyle: ButtonStyleType {
            switch self {
            case .location: return .prominent
            case .notification: return .bordered
            }
        }

        enum ButtonStyleType {
            case prominent, bordered
        }
    }

    private let type: PermissionType
    private let compact: Bool

    public init(type: PermissionType, compact: Bool = false) {
        self.type = type
        self.compact = compact
    }

    public var body: some View {
        VStack(spacing: compact ? 12 : 16) {
            Image(systemName: type.icon)
                .font(.system(size: compact ? 36 : 48))
                .foregroundStyle(.secondary)

            Text(type.title)
                .font(compact ? .subheadline.weight(.semibold) : .headline)

            Text(type.message)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            settingsButton
        }
        .padding(compact ? 16 : 24)
    }

    @ViewBuilder
    private var settingsButton: some View {
        if type.buttonStyle == .prominent {
            Button("Open Settings") { openSettings() }
                .buttonStyle(.borderedProminent)
                .controlSize(compact ? .small : .regular)
        } else {
            Button("Open Settings") { openSettings() }
                .buttonStyle(.bordered)
                .controlSize(compact ? .small : .regular)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview("Location Permission") {
    PermissionDeniedView(type: .location)
}

#Preview("Notification Permission - Compact") {
    PermissionDeniedView(type: .notification, compact: true)
}
