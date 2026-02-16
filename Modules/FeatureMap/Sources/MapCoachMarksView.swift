import SwiftUI
import UmiDesignSystem
import UmiCoreKit

/// NX-002: Coach marks overlay to teach map gestures to new users
struct MapCoachMarksView: View {
    @Binding var isShowing: Bool
    @State private var currentStep: Int = 0

    private let steps: [(icon: String, title: String, description: String)] = [
        ("hand.pinch", "Pinch to Zoom", "Use two fingers to zoom in and explore dive sites in detail."),
        ("hand.draw", "Pan to Explore", "Drag with one finger to move around the map."),
        ("hand.tap", "Tap Clusters", "Tap grouped pins to zoom in and reveal individual sites.")
    ]

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    advanceOrDismiss()
                }

            VStack(spacing: 24) {
                Spacer()

                // Coach mark card
                VStack(spacing: 20) {
                    // Gesture icon
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.oceanBlue, .diveTeal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 8)

                    // Title and description
                    VStack(spacing: 8) {
                        Text(steps[currentStep].title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(steps[currentStep].description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentStep ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 8)

                    // Action buttons
                    HStack(spacing: 16) {
                        if currentStep < steps.count - 1 {
                            Button {
                                dismiss()
                            } label: {
                                Text("Skip")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Button {
                                advanceStep()
                            } label: {
                                Text("Next")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [.oceanBlue, .diveTeal],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                        } else {
                            Button {
                                dismiss()
                            } label: {
                                Text("Got it!")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [.oceanBlue, .diveTeal],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                )
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    private func advanceStep() {
        withAnimation(.spring(response: 0.3)) {
            currentStep += 1
        }
    }

    private func advanceOrDismiss() {
        if currentStep < steps.count - 1 {
            advanceStep()
        } else {
            dismiss()
        }
    }

    private func dismiss() {
        // Mark as seen
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasSeenMapCoachMarks)
        withAnimation(.easeOut(duration: 0.2)) {
            isShowing = false
        }
    }
}

// MARK: - Helper to check if coach marks should be shown

extension MapCoachMarksView {
    /// Returns true if the user hasn't seen coach marks yet
    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hasSeenMapCoachMarks)
    }
}

#Preview {
    MapCoachMarksView(isShowing: .constant(true))
}
