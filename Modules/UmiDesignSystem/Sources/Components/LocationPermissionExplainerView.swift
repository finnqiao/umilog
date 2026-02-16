import SwiftUI

/// Custom pre-permission screen that explains location benefits before triggering system dialog
/// Shows map content in background so user can see the app value
public struct LocationPermissionExplainerView: View {
    let onEnable: () -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(onEnable: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onEnable = onEnable
        self.onSkip = onSkip
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Card container
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.oceanBlue, .diveTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 8)

                // Title
                Text("Discover Nearby Dive Sites")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                // Benefits list
                VStack(alignment: .leading, spacing: 16) {
                    benefitRow(
                        icon: "mappin.and.ellipse",
                        title: "Find sites near you",
                        description: "See dive sites within your area on the map"
                    )
                    benefitRow(
                        icon: "bell.badge",
                        title: "Arrival notifications",
                        description: "Get a reminder to log when you arrive at a dive site"
                    )
                    benefitRow(
                        icon: "clock.arrow.circlepath",
                        title: "Auto-fill logging",
                        description: "Quick log auto-detects your location and nearest site"
                    )
                }
                .padding(.horizontal, 8)

                // Privacy note
                Text("Your location is only used on-device and never shared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onEnable) {
                        Text("Enable Location")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.oceanBlue, .diveTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkip) {
                        Text("Not Now")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            )
            .padding(.horizontal, 20)

            Spacer()
                .frame(height: 40)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Location permission request")
    }

    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.oceanBlue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Location Denied Banner

/// Banner shown when location is denied, with guidance to enable in Settings
public struct LocationDeniedBanner: View {
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    @State private var isDismissed = false

    public init(onOpenSettings: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "location.slash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Location disabled")
                        .font(.subheadline.weight(.semibold))
                    Text("Enable to find nearby dive sites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Enable") {
                    onOpenSettings()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.oceanBlue)

                Button {
                    withAnimation {
                        isDismissed = true
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview("Explainer") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        LocationPermissionExplainerView(
            onEnable: { print("Enable tapped") },
            onSkip: { print("Skip tapped") }
        )
    }
}

#Preview("Denied Banner") {
    VStack {
        LocationDeniedBanner(
            onOpenSettings: { print("Open settings") },
            onDismiss: { print("Dismissed") }
        )
        .padding()

        Spacer()
    }
}
