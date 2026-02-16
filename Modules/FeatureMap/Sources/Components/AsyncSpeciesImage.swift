import SwiftUI
import UmiDB
import UmiCoreKit

/// An async species image view that loads from bundle, cache, or network.
///
/// The component uses a 3-tier loading strategy:
/// 1. Bundle asset (species_{id})
/// 2. Memory/disk cache via ImageCacheService
/// 3. Network fetch from thumbnailUrl
///
/// Falls back to category-based SF Symbol with gradient if no image is available.
public struct AsyncSpeciesImage: View {
    let speciesId: String
    let category: WildlifeSpecies.Category
    let thumbnailUrl: URL?
    let size: CGFloat
    var seen: Bool = false
    var speciesName: String?

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var hasAttemptedLoad = false

    public init(
        speciesId: String,
        category: WildlifeSpecies.Category,
        thumbnailUrl: URL?,
        size: CGFloat,
        seen: Bool = false,
        speciesName: String? = nil
    ) {
        self.speciesId = speciesId
        self.category = category
        self.thumbnailUrl = thumbnailUrl
        self.size = size
        self.seen = seen
        self.speciesName = speciesName
    }

    private var accessibilityDescription: String {
        let hasImage = loadedImage != nil
        let categoryDescription = categoryAccessibilityDescription
        if isLoading {
            return speciesName != nil ? "Loading photo of \(speciesName!)" : "Loading \(categoryDescription) photo"
        }
        if let name = speciesName {
            return hasImage ? "Photo of \(name)" : "\(categoryDescription) icon for \(name)"
        } else {
            return hasImage ? "Photo of \(categoryDescription)" : "\(categoryDescription) icon"
        }
    }

    private var categoryAccessibilityDescription: String {
        switch category {
        case .fish: return "fish"
        case .coral: return "coral"
        case .mammal: return "marine mammal"
        case .invertebrate: return "invertebrate"
        case .reptile: return "reptile"
        }
    }

    public var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                loadingPlaceholder
            } else {
                categoryFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(accessibilityDescription)
        .task(id: speciesId) {
            await loadImage()
        }
    }

    // MARK: - Image Loading

    private func loadImage() async {
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true

        // 1. Check bundle first (for common species fallbacks)
        if let bundled = UIImage(named: "species_\(speciesId)") {
            loadedImage = bundled
            return
        }

        // 2. Try cache/network via ImageCacheService
        guard thumbnailUrl != nil else { return }

        isLoading = true
        defer { isLoading = false }

        // Use species_ prefix for cache keys to avoid collision with site images
        let cacheKey = "species_\(speciesId)"
        let image = await ImageCacheService.shared.image(for: cacheKey, url: thumbnailUrl)
        loadedImage = image
    }

    // MARK: - Fallback Views

    private var loadingPlaceholder: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.1))

            ProgressView()
                .scaleEffect(0.7)
        }
    }

    private var categoryFallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [categoryColor.opacity(0.3), categoryColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: categoryIcon)
                .font(.system(size: size * 0.4))
                .foregroundStyle(seen ? categoryColor : .gray)
        }
    }

    private var categoryIcon: String {
        switch category {
        case .fish:
            return "fish.fill"
        case .coral:
            return "sparkles"
        case .mammal:
            return "hare.fill"
        case .invertebrate:
            return "ladybug.fill"
        case .reptile:
            return "tortoise.fill"
        }
    }

    private var categoryColor: Color {
        switch category {
        case .fish:
            return .blue
        case .coral:
            return .orange
        case .mammal:
            return .purple
        case .invertebrate:
            return .pink
        case .reptile:
            return .green
        }
    }
}

#if DEBUG
struct AsyncSpeciesImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                AsyncSpeciesImage(
                    speciesId: "whale_shark",
                    category: .fish,
                    thumbnailUrl: nil,
                    size: 80,
                    seen: true
                )
                AsyncSpeciesImage(
                    speciesId: "manta_ray",
                    category: .fish,
                    thumbnailUrl: nil,
                    size: 80,
                    seen: false
                )
            }
            HStack(spacing: 20) {
                AsyncSpeciesImage(
                    speciesId: "green_turtle",
                    category: .reptile,
                    thumbnailUrl: nil,
                    size: 80,
                    seen: true
                )
                AsyncSpeciesImage(
                    speciesId: "giant_clam",
                    category: .invertebrate,
                    thumbnailUrl: nil,
                    size: 80,
                    seen: true
                )
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
