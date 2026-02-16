import SwiftUI
import UmiDB
import UmiDesignSystem

struct RecentlyViewedSiteCard: View {
    let site: RecentlyViewedSite
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                SiteImage(
                    siteId: site.id,
                    siteType: site.type,
                    size: 140,
                    cornerRadius: 12,
                    siteName: site.name
                )

                Text(site.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)

                Text(site.location)
                    .font(.caption)
                    .foregroundStyle(Color.mist)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(site.type.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.lagoon)

                    Text(depthText)
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                }
            }
            .frame(width: 160, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(site.name), \(site.location)")
    }

    private var depthText: String {
        site.maxDepth > 0 ? "\(Int(site.maxDepth))m" : "--m"
    }
}

#if DEBUG
struct RecentlyViewedSiteCard_Previews: PreviewProvider {
    static var previews: some View {
        RecentlyViewedSiteCard(
            site: RecentlyViewedSite(
                id: "test",
                name: "USS Liberty",
                location: "Tulamben, Bali",
                region: "Bali",
                type: .wreck,
                difficulty: .beginner,
                maxDepth: 30,
                viewedAt: Date()
            ),
            action: {}
        )
        .padding()
        .background(Color.midnight)
        .previewLayout(.sizeThatFits)
    }
}
#endif
