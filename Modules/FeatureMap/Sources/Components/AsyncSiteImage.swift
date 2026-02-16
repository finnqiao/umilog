import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiCoreKit

/// Async dive site image that loads from CDN with caching and gradient fallback.
///
/// Attempts to load in this order:
/// 1. Bundle asset (`site_{id}`)
/// 2. Memory/disk cache
/// 3. CDN fetch
/// 4. Type-based gradient placeholder (fallback)
///
/// ## Usage
/// ```swift
/// AsyncSiteImage(
///     siteId: "Q123456",
///     siteType: .reef,
///     imageURL: URL(string: "https://media.umilog.app/sites/Q123456/thumb.webp"),
///     size: 56
/// )
/// ```
public struct AsyncSiteImage: View {
    let siteId: String
    let siteType: DiveSite.SiteType
    let imageURL: URL?
    let size: CGFloat
    var cornerRadius: CGFloat = 8
    var siteName: String?

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    public init(
        siteId: String,
        siteType: DiveSite.SiteType,
        imageURL: URL?,
        size: CGFloat,
        cornerRadius: CGFloat = 8,
        siteName: String? = nil
    ) {
        self.siteId = siteId
        self.siteType = siteType
        self.imageURL = imageURL
        self.size = size
        self.cornerRadius = cornerRadius
        self.siteName = siteName
    }

    private var accessibilityDescription: String {
        let hasImage = loadedImage != nil || UIImage(named: "site_\(siteId)") != nil
        let typeDescription = siteTypeAccessibilityDescription
        if isLoading {
            return siteName != nil ? "Loading photo of \(siteName!)" : "Loading dive site photo"
        }
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
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else if isLoading {
                placeholderGradient
                    .overlay(
                        ProgressView()
                            .tint(Color.white.opacity(0.7))
                            .scaleEffect(0.8)
                    )
            } else {
                placeholderGradient
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel(accessibilityDescription)
        .task(id: siteId) {
            await loadImage()
        }
    }

    private func loadImage() async {
        // 1. Check bundle first (backward compatibility with bundled assets)
        if let bundleImage = UIImage(named: "site_\(siteId)") {
            loadedImage = bundleImage
            return
        }

        // 2. Load from cache or network via ImageCacheService
        isLoading = true
        loadedImage = await ImageCacheService.shared.image(for: siteId, url: imageURL)
        isLoading = false
    }

    // MARK: - Placeholder

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

// MARK: - Convenience Initializer

extension AsyncSiteImage {
    /// Initialize with a SiteLite and optional media URL string.
    public init(site: SiteLite, mediaURL: String?, size: CGFloat, cornerRadius: CGFloat = 8) {
        self.init(
            siteId: site.id,
            siteType: DiveSite.SiteType(rawValue: site.type) ?? .reef,
            imageURL: mediaURL.flatMap { URL(string: $0) },
            size: size,
            cornerRadius: cornerRadius,
            siteName: site.name
        )
    }

    /// Initialize with a DiveSite and optional media URL.
    public init(site: DiveSite, mediaURL: URL?, size: CGFloat, cornerRadius: CGFloat = 8) {
        self.init(
            siteId: site.id,
            siteType: site.type,
            imageURL: mediaURL,
            size: size,
            cornerRadius: cornerRadius,
            siteName: site.name
        )
    }
}

#if DEBUG
struct AsyncSiteImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Async Site Images")
                .font(.headline)
                .foregroundStyle(Color.foam)

            HStack(spacing: 16) {
                // No URL = gradient fallback
                AsyncSiteImage(
                    siteId: "test_reef",
                    siteType: .reef,
                    imageURL: nil,
                    size: 80
                )

                AsyncSiteImage(
                    siteId: "test_wreck",
                    siteType: .wreck,
                    imageURL: nil,
                    size: 80
                )

                AsyncSiteImage(
                    siteId: "test_cave",
                    siteType: .cave,
                    imageURL: nil,
                    size: 80
                )
            }

            Text("With loading (simulated)")
                .font(.caption)
                .foregroundStyle(Color.mist)
        }
        .padding()
        .background(Color.abyss)
        .previewLayout(.sizeThatFits)
    }
}
#endif
