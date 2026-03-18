import SwiftUI
import UmiDesignSystem

/// A location button that centers the map on the user's current position.
/// Matches the MinimalSearchButton styling for consistent bottom-right stack.
struct MyLocationButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.foam)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.foam.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("My location")
        .accessibilityHint("Centers the map on your current location")
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.abyss
            .ignoresSafeArea()
        MyLocationButton { }
    }
}
#endif
