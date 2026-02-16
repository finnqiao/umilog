import SwiftUI
import UmiDB
import UmiCoreKit

/// A species image view that loads from bundle, network, or falls back to category icon.
///
/// The component uses a 3-tier loading strategy when thumbnailUrl is provided:
/// 1. Bundle asset (species_{id})
/// 2. Memory/disk cache via ImageCacheService
/// 3. Network fetch from thumbnailUrl
///
/// Falls back to category-based SF Symbol if no image is available.
///
/// ## Usage
/// ```swift
/// SpeciesImage(speciesId: "whale_shark", category: .fish, size: 80)
/// SpeciesImage(speciesId: "whale_shark", category: .fish, thumbnailUrl: url, size: 80)
/// ```
public struct SpeciesImage: View {
    let speciesId: String
    let category: WildlifeSpecies.Category
    let thumbnailUrl: URL?
    let size: CGFloat
    var seen: Bool = false
    var speciesName: String?

    public init(
        speciesId: String,
        category: WildlifeSpecies.Category,
        size: CGFloat,
        seen: Bool = false,
        speciesName: String? = nil
    ) {
        self.speciesId = speciesId
        self.category = category
        self.thumbnailUrl = nil
        self.size = size
        self.seen = seen
        self.speciesName = speciesName
    }

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

    public var body: some View {
        // Use AsyncSpeciesImage for async loading when URL is available
        // or when we want consistent loading behavior
        AsyncSpeciesImage(
            speciesId: speciesId,
            category: category,
            thumbnailUrl: thumbnailUrl,
            size: size,
            seen: seen,
            speciesName: speciesName
        )
    }
}

// MARK: - Species Assets Helper

/// Utility for discovering species reference images in the bundle.
public enum SpeciesAssets {
    /// Get all reference image names for a species.
    ///
    /// Looks for images with the naming convention:
    /// - `species_{id}` (primary image)
    /// - `species_{id}_ref1`, `species_{id}_ref2`, etc. (reference photos)
    ///
    /// - Parameter speciesId: The species identifier
    /// - Returns: Array of image names that exist in the bundle
    public static func referenceImages(for speciesId: String) -> [String] {
        var images: [String] = []

        // Check primary image
        let primary = "species_\(speciesId)"
        if UIImage(named: primary) != nil {
            images.append(primary)
        }

        // Check numbered references (ref1, ref2, etc.)
        for i in 1...5 {
            let name = "species_\(speciesId)_ref\(i)"
            if UIImage(named: name) != nil {
                images.append(name)
            } else {
                // Stop checking if we hit a gap
                break
            }
        }

        return images
    }

    /// Check if a species has any images in the bundle.
    public static func hasImage(for speciesId: String) -> Bool {
        UIImage(named: "species_\(speciesId)") != nil
    }
}

#if DEBUG
struct SpeciesImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Fallback examples (no images in bundle yet)
            HStack(spacing: 20) {
                SpeciesImage(speciesId: "unknown_fish", category: .fish, size: 80, seen: true)
                SpeciesImage(speciesId: "unknown_coral", category: .coral, size: 80, seen: false)
                SpeciesImage(speciesId: "unknown_mammal", category: .mammal, size: 80, seen: true)
            }
            HStack(spacing: 20) {
                SpeciesImage(speciesId: "unknown_inv", category: .invertebrate, size: 80, seen: true)
                SpeciesImage(speciesId: "unknown_rep", category: .reptile, size: 80, seen: false)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
