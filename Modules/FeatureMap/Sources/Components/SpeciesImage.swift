import SwiftUI
import UmiDB

/// A species image view that loads from bundle assets with category-based fallback.
///
/// The component attempts to load an image from the bundle with the naming convention
/// `species_{id}`. If no image is found, it falls back to a category-appropriate SF Symbol.
///
/// ## Usage
/// ```swift
/// SpeciesImage(speciesId: "whale_shark", category: .fish, size: 80)
/// ```
public struct SpeciesImage: View {
    let speciesId: String
    let category: WildlifeSpecies.Category
    let size: CGFloat
    var seen: Bool = false

    public init(
        speciesId: String,
        category: WildlifeSpecies.Category,
        size: CGFloat,
        seen: Bool = false
    ) {
        self.speciesId = speciesId
        self.category = category
        self.size = size
        self.seen = seen
    }

    public var body: some View {
        Group {
            if let uiImage = UIImage(named: "species_\(speciesId)") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback to category icon
                ZStack {
                    Circle()
                        .fill(seen ? categoryColor.opacity(0.2) : Color.gray.opacity(0.1))

                    Image(systemName: categoryIcon)
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(seen ? categoryColor : .gray)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
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
