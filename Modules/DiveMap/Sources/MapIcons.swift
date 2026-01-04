import UIKit

// MARK: - Map Icon Configuration
// This file centralizes all map icon configuration.
// Edit values here to swap icons without touching MapVC.swift.
//
// Note: Currently using circle layers. To use custom icons:
// 1. Add image assets to DiveMapAssets.xcassets
// 2. Uncomment the symbol layer code in MapVC.swift
// 3. Update icon names here to match asset names

public struct MapIcons {

    // MARK: - Icon Asset Names
    // CUSTOMIZE: Edit to change which icons are used
    // These should match asset names in DiveMapAssets.xcassets
    public static var siteGeneric = "dive-site-generic"
    public static var siteReef = "dive-site-reef"
    public static var siteWreck = "dive-site-wreck"
    public static var siteWall = "dive-site-wall"
    public static var siteCave = "dive-site-cave"
    public static var siteShore = "dive-site-shore"
    public static var siteDrift = "dive-site-drift"
    public static var cluster = "dive-cluster"
    public static var selected = "dive-selected"

    // MARK: - Icon Sizing by Zoom Level
    // CUSTOMIZE: Edit to change how icons scale with zoom
    public static var iconScaleStops: [Double: Double] = [
        8: 0.6,   // Zoomed out - smaller icons
        12: 0.8,  // Medium zoom
        16: 1.0   // Zoomed in - full size
    ]

    // MARK: - Icon Rendering Options
    public struct Options {
        public static var allowOverlap = true        // Allow icons to overlap slightly
        public static var ignorePlacement = false    // Don't avoid other symbols
        public static var rotateWithMap = false      // Icons stay upright when map rotates
        public static var anchorPosition = "center"  // Where the icon anchors to its coordinate
    }

    // MARK: - Icon Tinting
    // When using monochrome icons, these determine the tint color by site type
    public struct Tints {
        public static var reef: UIColor { .umiReef }
        public static var wreck: UIColor { .umiAmber }
        public static var wall: UIColor { .umiOcean }
        public static var cave: UIColor { .umiDanger }
        public static var shore: UIColor { .umiDifficultyBeginner }
        public static var `default`: UIColor { .umiLagoon }
    }

    // MARK: - Helper to map site kind to icon name
    public static func iconName(for kind: String) -> String {
        switch kind.lowercased() {
        case "reef": return siteReef
        case "wreck": return siteWreck
        case "wall": return siteWall
        case "cave", "cavern": return siteCave
        case "shore", "beach": return siteShore
        case "drift": return siteDrift
        default: return siteGeneric
        }
    }

    // MARK: - SF Symbol Mappings
    // Maps site types to SF Symbols for rendering custom icons
    public struct SFSymbols {
        /// Get the SF Symbol name for a given site type.
        /// Falls back to mappin.circle.fill for unknown types.
        public static func symbol(for type: String) -> String {
            switch type.lowercased() {
            case "reef":
                return "leaf.fill"
            case "wreck":
                return "ferry.fill"
            case "wall":
                return "rectangle.3.group.fill"
            case "cave", "cavern":
                return "mountain.2.fill"
            case "shore", "beach":
                if #available(iOS 17.0, *) {
                    return "beach.umbrella.fill"
                }
                return "sun.horizon.fill"
            case "drift":
                return "wind"
            default:
                return "mappin.circle.fill"
            }
        }

        // Cluster icon
        public static var cluster: String { "circle.grid.3x3.fill" }

        // Selected marker highlight
        public static var selected: String { "circle.fill" }
    }

    // MARK: - Animation Configuration
    public struct AnimationConfig {
        // Selection pulse animation
        public static var selectionPulseDuration: TimeInterval = 0.6
        public static var selectionPulseScale: CGFloat = 1.3
        public static var selectionFinalScale: CGFloat = 1.2

        // Cluster bounce animation
        public static var bounceStaggerDelay: TimeInterval = 0.05
        public static var bounceDuration: TimeInterval = 0.4
        public static var bounceOffsetY: CGFloat = -20
    }
}
