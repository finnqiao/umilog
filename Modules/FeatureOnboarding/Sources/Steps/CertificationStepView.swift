import SwiftUI
import UmiDesignSystem

/// Third step - user selects their diving certifications
public struct CertificationStepView: View {
    @ObservedObject var state: OnboardingState

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    public init(state: OnboardingState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Select your certifications")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Choose all that apply")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            // Certification grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Certification.allCases) { cert in
                        CertificationChip(
                            certification: cert,
                            isSelected: state.selectedCertifications.contains(cert),
                            action: {
                                withAnimation(.smooth(duration: 0.2)) {
                                    if state.selectedCertifications.contains(cert) {
                                        state.selectedCertifications.remove(cert)
                                    } else {
                                        state.selectedCertifications.insert(cert)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }

            // Selected count
            if !state.selectedCertifications.isEmpty {
                Text("\(state.selectedCertifications.count) certification\(state.selectedCertifications.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Text(state.selectedCertifications.isEmpty ? "Skip" : "Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            state.selectedCertifications.isEmpty
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

private struct CertificationChip: View {
    let certification: Certification
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: certification.iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.white : Color.lagoon)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.lagoon : Color.lagoon.opacity(0.15))
                    .clipShape(Circle())

                Text(certification.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isSelected ? Color.lagoon : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(certification.rawValue) certification")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    CertificationStepView(state: OnboardingState())
        .preferredColorScheme(.dark)
}
