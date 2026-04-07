import SwiftUI
import UmiCoreKit
import UmiDB
import UmiDesignSystem

/// Horizontal scrollable carousel of compact site cards for the peek detent.
/// Shows the nearest 3 sites for quick access without expanding the sheet.
struct HorizontalSiteCarousel: View {
    // MARK: - Properties

    let sites: [DiveSite]
    var onSiteTap: (DiveSite) -> Void
    var onSeeAll: (() -> Void)?

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(sites.prefix(3)) { site in
                    CompactSiteCard(site: site)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.soft()
                            onSiteTap(site)
                        }
                }

                if sites.count > 3, let onSeeAll {
                    Button(action: onSeeAll) {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.lagoon)
                            Text("See all")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.mist)
                        }
                        .frame(width: 80)
                        .frame(maxHeight: .infinity)
                        .background(Color.trench.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Compact Site Card

/// A compact card view for displaying site info in the horizontal carousel.
private struct CompactSiteCard: View {
    let site: DiveSite

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: siteTypeIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.reef.opacity(0.8))
                Text(site.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)
            }

            Text(site.location)
                .font(.caption)
                .foregroundStyle(Color.mist)
                .lineLimit(1)

            HStack(spacing: 6) {
                DifficultyBadge(difficulty: site.difficulty)

                Text("\(Int(site.maxDepth))m")
                    .font(.caption2)
                    .foregroundStyle(Color.mist)
            }
        }
        .padding(12)
        .frame(width: 170)
        .background(Color.trench)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(site.name), \(site.location), \(site.difficulty.rawValue) difficulty, max depth \(Int(site.maxDepth)) meters")
    }

    private var siteTypeIcon: String {
        switch site.type {
        case .reef: return "leaf.fill"
        case .wreck: return "ferry.fill"
        case .wall: return "rectangle.portrait.fill"
        case .cave: return "mountain.2.fill"
        case .shore: return "beach.umbrella.fill"
        case .drift: return "wind"
        }
    }
}

// MARK: - Difficulty Badge

/// Small difficulty indicator badge.
private struct DifficultyBadge: View {
    let difficulty: DiveSite.Difficulty

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.foam)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(difficultyColor)
            .clipShape(Capsule())
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .beginner:
            return Color.difficultyBeginner
        case .intermediate:
            return Color.difficultyIntermediate
        case .advanced:
            return Color.difficultyAdvanced
        }
    }
}

#if DEBUG
struct HorizontalSiteCarousel_Previews: PreviewProvider {
    static var sampleSites: [DiveSite] {
        [
            DiveSite(
                id: "1",
                name: "Blue Corner",
                location: "Palau",
                latitude: 7.0,
                longitude: 134.0,
                region: "Micronesia",
                averageDepth: 25,
                maxDepth: 35,
                averageTemp: 28,
                averageVisibility: 30,
                difficulty: .advanced,
                type: .wall
            ),
            DiveSite(
                id: "2",
                name: "USS Liberty",
                location: "Tulamben, Bali",
                latitude: -8.0,
                longitude: 115.0,
                region: "Indonesia",
                averageDepth: 20,
                maxDepth: 30,
                averageTemp: 27,
                averageVisibility: 20,
                difficulty: .beginner,
                type: .wreck
            ),
            DiveSite(
                id: "3",
                name: "Manta Point",
                location: "Nusa Penida",
                latitude: -8.5,
                longitude: 115.5,
                region: "Indonesia",
                averageDepth: 15,
                maxDepth: 20,
                averageTemp: 26,
                averageVisibility: 25,
                difficulty: .intermediate,
                type: .reef
            )
        ]
    }

    static var previews: some View {
        HorizontalSiteCarousel(
            sites: sampleSites,
            onSiteTap: { _ in }
        )
        .padding(.vertical)
        .background(Color.midnight)
        .previewLayout(.sizeThatFits)
    }
}
#endif
