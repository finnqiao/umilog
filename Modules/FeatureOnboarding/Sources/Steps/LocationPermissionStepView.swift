import SwiftUI
import UmiDesignSystem
import UmiLocationKit

/// Fourth step - explains and requests location permission
public struct LocationPermissionStepView: View {
    @ObservedObject var state: OnboardingState
    @ObservedObject private var locationState = LocationPermissionState.shared

    public init(state: OnboardingState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon and header
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.lagoon.opacity(0.3), Color.reef.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "location.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.lagoon)
                }

                Text("Enable Location Services")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Get the most out of UmiLog with location features")
                    .font(.subheadline)
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 16) {
                BenefitRow(
                    icon: "mappin.circle.fill",
                    title: "Find nearby sites",
                    description: "Discover dive sites close to you"
                )

                BenefitRow(
                    icon: "bell.badge.fill",
                    title: "Arrival alerts",
                    description: "Get notified when you arrive at a dive site"
                )

                BenefitRow(
                    icon: "location.fill.viewfinder",
                    title: "Auto-fill logging",
                    description: "Automatically suggest your current location"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Permission status
            if locationState.hasLocationAccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("Location access granted")
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
                .onAppear {
                    state.locationPermissionGranted = true
                }
            }

            // Action buttons
            VStack(spacing: 12) {
                if !locationState.hasLocationAccess && !locationState.showDeniedGuidance {
                    Button(action: requestPermission) {
                        Text("Enable Location")
                            .font(.headline)
                            .foregroundStyle(Color.white)
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
                } else if locationState.showDeniedGuidance {
                    Button(action: openSettings) {
                        Text("Open Settings")
                            .font(.headline)
                            .foregroundStyle(Color.lagoon)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                // Navigation
                HStack(spacing: 12) {
                    Button(action: { state.previousStep() }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button(action: { state.nextStep() }) {
                        Text(locationState.hasLocationAccess ? "Continue" : "Skip for Now")
                            .font(.headline)
                            .foregroundStyle(locationState.hasLocationAccess ? Color.white : Color(UIColor.label))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                locationState.hasLocationAccess
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [Color.lagoon, Color.oceanBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    : AnyShapeStyle(.ultraThinMaterial)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func requestPermission() {
        locationState.userRequestedPermission()
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.lagoon)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.secondaryLabel))
            }
        }
    }
}

#Preview {
    LocationPermissionStepView(state: OnboardingState())
        .preferredColorScheme(.dark)
}
