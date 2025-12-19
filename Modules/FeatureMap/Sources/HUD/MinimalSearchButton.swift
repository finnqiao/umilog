import SwiftUI
import UmiDesignSystem

/// A minimal search icon button for the map HUD.
/// Positioned in the top-right corner to provide quick access to search.
struct MinimalSearchButton: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.foam)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.foam.opacity(0.12), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
        }
        .accessibilityLabel("Search dive sites")
    }
}

#Preview {
    ZStack {
        Color.abyss
        MinimalSearchButton {
            print("Search tapped")
        }
    }
}
