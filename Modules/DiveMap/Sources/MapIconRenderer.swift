import UIKit
import UmiDesignSystem

/// Renders SF Symbols as tinted UIImages for use in MapLibre symbol layers.
/// Pre-renders all icon variants at style load time for optimal performance.
public final class MapIconRenderer {
    private var imageCache: [String: UIImage] = [:]

    public init() {}

    // MARK: - Public API

    /// Render an SF Symbol as a tinted UIImage suitable for MapLibre.
    /// - Parameters:
    ///   - symbol: SF Symbol name (e.g., "leaf.fill")
    ///   - color: Tint color for the icon
    ///   - size: Point size for rendering
    /// - Returns: Rendered and tinted UIImage
    public func renderIcon(
        symbol: String,
        color: UIColor,
        size: CGFloat = 24
    ) -> UIImage {
        let key = "\(symbol)-\(color.hexString)-\(size)"
        if let cached = imageCache[key] { return cached }

        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        guard let sfImage = UIImage(systemName: symbol, withConfiguration: config) else {
            return fallbackIcon(size: size, color: color)
        }

        let tinted = sfImage.withTintColor(color, renderingMode: .alwaysOriginal)
        imageCache[key] = tinted
        return tinted
    }

    /// Pre-render all icon variants for a given site type across all difficulty levels.
    /// Returns a dictionary mapping icon names to rendered images.
    /// - Parameter siteType: The site type to render icons for
    /// - Returns: Dictionary of icon name → UIImage
    public func prerenderAllVariants(for siteType: String) -> [String: UIImage] {
        let symbol = MapIcons.SFSymbols.symbol(for: siteType)
        var variants: [String: UIImage] = [:]

        for difficulty in Difficulty.allCases {
            let color = difficultyColor(difficulty)
            let name = "dive-\(siteType.lowercased())-\(difficulty.rawValue.lowercased())"
            variants[name] = renderIcon(symbol: symbol, color: color)
        }

        // Also render a default variant
        let defaultName = "dive-\(siteType.lowercased())-other"
        variants[defaultName] = renderIcon(symbol: symbol, color: MapTheme.Colors.default)

        return variants
    }

    /// Pre-render all icons for all site types and difficulties.
    /// Call this once when the map style loads.
    /// - Returns: Dictionary of all icon name → UIImage mappings
    public func prerenderAllIcons() -> [String: UIImage] {
        var allIcons: [String: UIImage] = [:]

        let siteTypes = ["reef", "wreck", "wall", "cave", "shore", "drift", "generic"]
        for siteType in siteTypes {
            let variants = prerenderAllVariants(for: siteType)
            allIcons.merge(variants) { _, new in new }
        }

        // Render cluster icon
        allIcons["dive-cluster"] = renderIcon(
            symbol: "circle.grid.3x3.fill",
            color: MapTheme.Colors.clusterFill,
            size: 32
        )

        // Render selected highlight icon (larger, with glow-like effect)
        allIcons["dive-selected"] = renderIcon(
            symbol: "circle.fill",
            color: MapTheme.Colors.selectionRing,
            size: 28
        )

        return allIcons
    }

    // MARK: - Private Helpers

    private func fallbackIcon(size: CGFloat, color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { context in
            color.setFill()
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
        }
    }

    private func difficultyColor(_ difficulty: Difficulty) -> UIColor {
        switch difficulty {
        case .beginner:
            return MapTheme.Colors.beginner
        case .intermediate:
            return MapTheme.Colors.intermediate
        case .advanced:
            return MapTheme.Colors.advanced
        case .expert:
            return MapTheme.Colors.expert
        }
    }

    // MARK: - Difficulty Enum (local copy for icon rendering)

    public enum Difficulty: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
    }
}

// MARK: - UIColor Helper

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
