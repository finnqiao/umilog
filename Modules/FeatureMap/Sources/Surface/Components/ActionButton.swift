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
        .accessibilityLabel(title)
    }

    // MARK: - Computed Colors

    private var foregroundColor: Color {
        if isPrimary {
            return .white
        } else if isActive {
            return Color.oceanBlue
        } else {
            return Color(uiColor: .label)
        }
    }

    private var backgroundColor: Color {
        if isPrimary {
            return Color.oceanBlue
        } else if isActive {
            return Color.oceanBlue.opacity(0.12)
        } else {
            return Color.gray.opacity(0.08)
        }
    }

    private var borderColor: Color {
        if isActive {
            return Color.oceanBlue.opacity(0.3)
        } else {
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        isActive ? 1.5 : 0
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
