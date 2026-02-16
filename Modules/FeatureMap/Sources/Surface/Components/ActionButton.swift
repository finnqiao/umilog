import SwiftUI
import UmiDesignSystem

/// Reusable action button for surface content views.
/// Used in Inspect mode for Save/Plan/Log actions.
struct ActionButton: View {
    let icon: String
    let title: String
    var isActive: Bool = false
    var isPrimary: Bool = false
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                        .tint(foregroundColor)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Loading \(title)" : title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Computed Colors

    private var foregroundColor: Color {
        if isPrimary {
            return Color.foam
        } else if isActive {
            return Color.lagoon
        } else {
            return Color.foam
        }
    }

    private var backgroundColor: Color {
        if isPrimary {
            return Color.lagoon
        } else if isActive {
            return Color.lagoon.opacity(0.2)
        } else {
            return Color.trench
        }
    }

    private var borderColor: Color {
        if isActive {
            return Color.lagoon.opacity(0.4)
        } else {
            return Color.ocean.opacity(0.2)
        }
    }

    private var borderWidth: CGFloat {
        1
    }
}

#if DEBUG
struct ActionButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            ActionButton(icon: "star.fill", title: "Saved", isActive: true) {}
            ActionButton(icon: "calendar", title: "Plan") {}
            ActionButton(icon: "waveform", title: "Log", isPrimary: true) {}
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
