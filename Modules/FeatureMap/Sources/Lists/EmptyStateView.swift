import SwiftUI
import UmiDesignSystem

/// Configuration for empty state display
struct EmptyStateConfiguration {
    let icon: String
    let title: String
    let message: String
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
}

/// Reusable empty state view for lists
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.mist)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.foam)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.mist)
            if let primaryTitle, let primaryAction {
                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.reef.opacity(0.8)))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            if let secondaryTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .font(.footnote)
                        .foregroundStyle(Color.mist)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helpers

/// Abbreviates large counts (e.g., 1500 -> "1.5k")
func abbreviatedCount(_ value: Int) -> String {
    guard value >= 1_000 else { return "\(value)" }
    let formatted = Double(value) / 1_000
    let text = String(format: "%.1fk", formatted)
    return text.replacingOccurrences(of: ".0k", with: "k")
}
