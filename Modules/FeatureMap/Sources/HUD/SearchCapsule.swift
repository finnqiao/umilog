import SwiftUI
import UmiDesignSystem

/// Full-width search capsule displayed at the top of the Discover screen.
/// Replaces the floating search icon button with a primary search entry point.
/// Tapping opens the search sheet in the bottom surface.
struct SearchCapsule: View {
    let filterCount: Int
    var onTap: () -> Void
    var onFilterTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.mist)

                Text("Search destinations, areas, sites")
                    .font(.subheadline)
                    .foregroundStyle(Color.mist)

                Spacer()

                // Filter badge button
                Button {
                    onFilterTap()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(filterCount > 0 ? Color.lagoon : Color.mist)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.trench)
                            )

                        if filterCount > 0 {
                            Text("\(filterCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.foam)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(Color.lagoon))
                                .offset(x: 4, y: -4)
                        }
                    }
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
            SearchCapsule(filterCount: 0, onTap: {}, onFilterTap: {})
                .padding(.horizontal, 16)
            SearchCapsule(filterCount: 3, onTap: {}, onFilterTap: {})
                .padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 60)
    }
}
