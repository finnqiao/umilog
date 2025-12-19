import SwiftUI
import UmiDB
import UmiDesignSystem

/// Lightweight preview card shown when tapping a dive site pin (US-8)
/// Shows basic info without leaving the map context
struct SitePreviewCard: View {
    let site: DiveSite
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.headline)
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(site.difficulty.rawValue.capitalized)
                    Text("•")
                    Text("Max \(Int(site.maxDepth))m")
                    if site.averageTemp > 0 {
                        Text("•")
                        Text("\(Int(site.averageTemp))°C")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.mist)
            }

            Spacer()

            Button(action: onTap) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.foam)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.glass)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.foam.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    // Swipe down to dismiss
                    if value.translation.height > 30 {
                        onDismiss()
                    }
                }
        )
    }

    private var statusColor: Color {
        if site.visitedCount > 0 {
            return .statusLogged
        } else if site.wishlist {
            return .statusSaved
        } else {
            return .mist
        }
    }
}

#Preview {
    ZStack {
        Color.abyss.ignoresSafeArea()

        VStack {
            Spacer()
            SitePreviewCard(
                site: DiveSite(
                    id: "preview",
                    name: "Blue Hole",
                    location: "Dahab, Egypt",
                    latitude: 28.57,
                    longitude: 34.54,
                    region: "Red Sea",
                    averageDepth: 25,
                    maxDepth: 130,
                    averageTemp: 24,
                    averageVisibility: 30,
                    difficulty: .advanced,
                    type: .reef,
                    description: nil,
                    wishlist: true,
                    visitedCount: 0,
                    tags: ["famous", "deep"]
                ),
                onTap: { print("Tapped") },
                onDismiss: { print("Dismissed") }
            )
            .padding(.bottom, 100)
        }
    }
}
