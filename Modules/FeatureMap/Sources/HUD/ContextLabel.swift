import SwiftUI
import UmiDesignSystem
import UmiDB

/// A context-aware status label for the map HUD.
/// Shows relevant information based on the current mode.
struct ContextLabel: View {
    let mode: MapUIMode
    let siteCount: Int
    let isFiltered: Bool
    let siteName: String?

    init(mode: MapUIMode, siteCount: Int, isFiltered: Bool, siteName: String? = nil) {
        self.mode = mode
        self.siteCount = siteCount
        self.isFiltered = isFiltered
        self.siteName = siteName
    }

    var body: some View {
        if let text = labelText {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.foam.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.glass)
                        .overlay(
                            Capsule()
                                .stroke(Color.foam.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    private var labelText: String? {
        switch mode {
        case .explore(let ctx):
            if isFiltered || ctx.filterLens != nil {
                return "Filtered: \(siteCount)"
            }
            return "\(siteCount) sites nearby"

        case .inspectSite:
            if let name = siteName {
                return name
            }
            return nil

        case .filter, .search:
            // Hidden during filter/search modes
            return nil
        }
    }
}

#Preview("Explore") {
    ZStack {
        Color.abyss
        VStack(spacing: 20) {
            ContextLabel(
                mode: .explore(ExploreContext()),
                siteCount: 42,
                isFiltered: false
            )
            ContextLabel(
                mode: .explore(ExploreContext(filterLens: .saved)),
                siteCount: 8,
                isFiltered: true
            )
            ContextLabel(
                mode: .inspectSite(SiteInspectionContext(siteId: "test", returnContext: ExploreContext())),
                siteCount: 0,
                isFiltered: false,
                siteName: "Blue Corner"
            )
        }
    }
}
