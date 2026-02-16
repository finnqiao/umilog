import SwiftUI

/// Banner displayed when the app is offline.
public struct OfflineBanner: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)

            Text("You're offline")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Text("Some features unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.trench)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Animated offline indicator dot for compact spaces.
public struct OfflineIndicator: View {
    @State private var isAnimating = false

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.amber)
                .frame(width: 8, height: 8)
                .opacity(isAnimating ? 0.5 : 1.0)

            Text("Offline")
                .font(.caption2)
                .foregroundStyle(Color.mist)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                isAnimating = true
            }
        }
    }
}

#Preview("Offline Banner") {
    VStack {
        OfflineBanner()
        Spacer()
        OfflineIndicator()
        Spacer()
    }
    .background(Color.midnight)
}
