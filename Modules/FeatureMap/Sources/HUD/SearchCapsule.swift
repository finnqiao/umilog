import SwiftUI
import UmiDesignSystem

/// Full-width search capsule displayed at the top of the Discover screen.
/// Shows search guidance plus current map context.
struct SearchCapsule: View {
    let title: String
    let subtitle: String?
    var onTap: () -> Void
    var onLocateMeTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.mist)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.foam)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.mist)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Locate me button
                Button {
                    onLocateMeTap()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.lagoon)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.trench)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("diveMap.locationButton")
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.trench.opacity(0.88))
                    .overlay(
                        Capsule()
                            .stroke(Color.lagoon.opacity(0.35), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(SearchCapsuleButtonStyle())
        .contentShape(Capsule())
        .accessibilityLabel(title)
        .accessibilityHint("Search dive sites, species, places")
        .accessibilityIdentifier("diveMap.searchBar")
    }
}

private struct SearchCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.abyss
            .ignoresSafeArea()
        VStack {
            SearchCapsule(
                title: "Search dive sites, species, places",
                subtitle: "Aegean Sea · 72 sites in this map area",
                onTap: {},
                onLocateMeTap: {}
            )
                .padding(.horizontal, 16)
            SearchCapsule(
                title: "Search dive sites, species, places",
                subtitle: "Coral Triangle · 12 destinations in view",
                onTap: {},
                onLocateMeTap: {}
            )
                .padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 60)
    }
}
