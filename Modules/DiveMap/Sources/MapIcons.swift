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
}
