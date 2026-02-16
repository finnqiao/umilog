import SwiftUI
import UmiDB
import UmiDesignSystem

/// A dive site image view that loads from bundle assets with type-based gradient placeholder fallback.
///
/// The component attempts to load an image from the bundle with the naming convention
/// `site_{id}`. If no image is found, it falls back to a gradient placeholder with
/// an appropriate icon based on the site type.
///
/// ## Usage
/// ```swift
/// SiteImage(siteId: "blue_corner_wall", siteType: .reef, size: 56)
/// ```
///
/// ## Adding Images
/// Place images in `Resources/SiteImages/` with naming convention `site_{siteId}.jpg`
public struct SiteImage: View {
    let siteId: String
    let siteType: DiveSite.SiteType
    let size: CGFloat
    var cornerRadius: CGFloat = 8
    var siteName: String?

    public init(
        siteId: String,
        siteType: DiveSite.SiteType,
        size: CGFloat,
        cornerRadius: CGFloat = 8,
        siteName: String? = nil
    ) {
        self.siteId = siteId
        self.siteType = siteType
        self.size = size
        self.cornerRadius = cornerRadius
        self.siteName = siteName
    }

    private var accessibilityDescription: String {
        let hasImage = UIImage(named: "site_\(siteId)") != nil
        let typeDescription = siteTypeAccessibilityDescription
        if let name = siteName {
            return hasImage ? "Photo of \(name), \(typeDescription) dive site" : "\(typeDescription) dive site placeholder for \(name)"
        } else {
            return hasImage ? "Photo of \(typeDescription) dive site" : "\(typeDescription) dive site placeholder"
        }
    }

    private var siteTypeAccessibilityDescription: String {
        switch siteType {
        case .reef: return "reef"
        case .wreck: return "wreck"
        case .cave: return "cave"
        case .wall: return "wall"
        case .shore: return "shore"
        case .drift: return "drift"
        }
    }

    public var body: some View {
        Group {
            if let uiImage = UIImage(named: "site_\(siteId)") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Gradient placeholder based on site type
                placeholderGradient
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel(accessibilityDescription)
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: siteTypeIcon)
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))
        )
    }

    private var gradientColors: [Color] {
        switch siteType {
        case .reef:
            return [Color.reef.opacity(0.9), Color.lagoon.opacity(0.5)]
        case .wreck:
            return [Color.amber.opacity(0.9), Color.amber.opacity(0.4)]
        case .cave:
            return [Color.trench, Color.abyss]
        case .wall:
            return [Color.ocean, Color.lagoon.opacity(0.6)]
        case .shore:
            return [Color.difficultyBeginner.opacity(0.8), Color.lagoon.opacity(0.4)]
        case .drift:
            return [Color.lagoon, Color.ocean.opacity(0.6)]
        }
    }

    private var siteTypeIcon: String {
        switch siteType {
        case .reef:
            return "water.waves"
        case .wreck:
            return "ferry.fill"
        case .cave:
            return "mountain.2.fill"
        case .wall:
            return "square.stack.3d.up.fill"
        case .shore:
            return "beach.umbrella.fill"
        case .drift:
            return "wind"
        }
    }
}

// MARK: - Site Assets Helper

/// Utility for discovering site images in the bundle.
public enum SiteAssets {
    /// Check if a site has an image in the bundle.
    public static func hasImage(for siteId: String) -> Bool {
        UIImage(named: "site_\(siteId)") != nil
    }
}

#if DEBUG
struct SiteImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Site Type Placeholders")
                .font(.headline)
                .foregroundStyle(Color.foam)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                VStack(spacing: 4) {
                    SiteImage(siteId: "test", siteType: .reef, size: 80)
                    Text("Reef").font(.caption).foregroundStyle(Color.mist)
                }
                VStack(spacing: 4) {
                    SiteImage(siteId: "test", siteType: .wreck, size: 80)
                    Text("Wreck").font(.caption).foregroundStyle(Color.mist)
                }
                VStack(spacing: 4) {
                    SiteImage(siteId: "test", siteType: .cave, size: 80)
                    Text("Cave").font(.caption).foregroundStyle(Color.mist)
                }
                VStack(spacing: 4) {
                    SiteImage(siteId: "test", siteType: .wall, size: 80)
                    Text("Wall").font(.caption).foregroundStyle(Color.mist)
                }
                VStack(spacing: 4) {
                    SiteImage(siteId: "test", siteType: .shore, size: 80)
                    Text("Shore").font(.caption).foregroundStyle(Color.mist)
                }
                VStack(spacing: 4) {
                    SiteImage(siteId: "test", siteType: .drift, size: 80)
                    Text("Drift").font(.caption).foregroundStyle(Color.mist)
                }
            }
        }
        .padding()
        .background(Color.abyss)
        .previewLayout(.sizeThatFits)
    }
}
#endif
