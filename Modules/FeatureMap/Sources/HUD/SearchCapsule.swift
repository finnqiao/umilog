import SwiftUI
import UmiDesignSystem

/// Full-width search capsule displayed at the top of the Discover screen.
/// Shows location context and provides search + locate-me actions.
struct SearchCapsule: View {
    let locationContext: String?
    var onTap: () -> Void
    var onLocateMeTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.mist)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Explore dive sites")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.foam)

                    if let context = locationContext, !context.isEmpty {
                        Text(context)
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
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.glass)
                    .overlay(
                        Capsule()
                            .stroke(Color.foam.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel("Search dive sites")
        .accessibilityHint("Opens search to find destinations, areas, and sites")
    }
}

#Preview {
    ZStack {
        Color.abyss
            .ignoresSafeArea()
        VStack {
            SearchCapsule(locationContext: nil, onTap: {}, onLocateMeTap: {})
                .padding(.horizontal, 16)
            SearchCapsule(locationContext: "Coral Triangle \u{00B7} Indonesia", onTap: {}, onLocateMeTap: {})
                .padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 60)
    }
}
