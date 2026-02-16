import UIKit
import UmiDesignSystem

// MARK: - Map Theme Configuration
// This file centralizes all map styling configuration.
// Edit values here to change the map's appearance without touching MapVC.swift.

public struct MapTheme {

    // MARK: - Color Palette
    // CUSTOMIZE: Edit these to change the map color scheme
    public struct Colors {
        // Base map colors (Resy-style underwater depth ramp)
        public static var background: UIColor { .umiWaterSurface }  // #08141A
        public static var water: UIColor { .umiWaterDeep }          // #0A0F2A
        public static var stroke: UIColor { .umiWaterSurface }

        // Site markers by difficulty (kept for filtering)
        public static var beginner: UIColor { .umiDifficultyBeginner }
        public static var intermediate: UIColor { .umiDifficultyIntermediate }
        public static var advanced: UIColor { .umiDifficultyAdvanced }
        public static var expert: UIColor { .umiDifficultyExpert }
        public static var `default`: UIColor { .umiPinDefault }     // #35C2E0

        // Resy-style pin states (based on user activity, not difficulty)
        public static var pinDefault: UIColor { .umiPinDefault }    // #35C2E0 - Undiscovered
        public static var pinVisited: UIColor { .umiPinVisited }    // #2FD7B8 - Logged dives
        public static var pinFavorite: UIColor { .umiPinFavorite }  // #F2C14E - Wishlist/saved

        // Status glows (for logged/saved/planned sites)
        public static var logged: UIColor { .umiPinVisited }        // Green-teal glow
        public static var saved: UIColor { .umiPinFavorite }        // Gold glow
        public static var planned: UIColor { .umiStatusPlanned }    // Amber glow
        public static var defaultGlow: UIColor { .umiPinDefault.withAlphaComponent(0.2) }

        // Site type accents
        public static var reefOverlay: UIColor { .umiReefAccent }   // #2BAA9B
        public static var wreckOverlay: UIColor { .umiWreckAccent } // #C98B2B
        public static var hazardOverlay: UIColor { .umiHazardAccent } // #FF8A3D

        // Cluster colors - teal for consistency with pin default
        public static var clusterFill: UIColor { .umiPinDefault }   // #35C2E0
        public static var clusterStroke: UIColor { .white }
        public static var clusterText: UIColor { .umiWaterSurface } // Dark text on light cluster

        // Selection highlight
        public static var selectionRing: UIColor { .umiFoam }
    }

    // MARK: - Typography
    // CUSTOMIZE: Edit these to change fonts used on the map
    public struct Typography {
        public static var clusterFont = "HelveticaNeue-Bold"
        public static var clusterFontSize: CGFloat = 13
        public static var labelFont = "HelveticaNeue-Medium"
        public static var labelFontSize: CGFloat = 12
    }

    // MARK: - Sizing
    // CUSTOMIZE: Edit these to change marker and cluster sizes
    public struct Sizing {
        // Zoom level → marker radius mapping
        // Keys are zoom levels, values are radii in points
        public static var markerRadiusStops: [Double: Double] = [
            5: 4,    // World view - tiny dots
            8: 7,    // Regional - small circles
            12: 12,  // City-level - medium
            16: 18   // Street-level - large, easy to tap
        ]

        // Cluster count → radius mapping
        // Keys are point counts, values are radii in points
        public static var clusterRadiusStops: [Int: Double] = [
            2: 24,    // Small cluster (2-9 sites)
            10: 32,   // Medium cluster (10-49 sites)
            50: 40,   // Large cluster (50-99 sites)
            100: 48   // Huge cluster (100+ sites)
        ]

        // Glow effect settings
        public static var glowBlur: CGFloat = 0.8
        public static var glowRadiusMultiplier: CGFloat = 3.0  // Glow radius = marker radius * this

        // Stroke widths
        public static var markerStrokeWidth: CGFloat = 1.5
        public static var clusterStrokeWidth: CGFloat = 2.5
        public static var selectionStrokeWidth: CGFloat = 3.0
    }

    // MARK: - Animation
    // CUSTOMIZE: Edit these to change the feel of map interactions
    public struct Animation {
        // Selection animation
        public static var selectionDuration: TimeInterval = 0.4
        public static var selectionDamping: CGFloat = 0.8
        public static var selectionInitialVelocity: CGFloat = 0.5

        // Cluster expansion animation
        public static var clusterExpandDuration: TimeInterval = 0.5

        // Haptics
        public static var enableHaptics = true
        public static var selectionHapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium
        public static var clusterHapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    }

    // MARK: - Features
    // CUSTOMIZE: Toggle map features on/off
    public struct Features {
        public static var showDifficultyColors = true      // Color markers by difficulty level
        public static var showStatusGlows = true           // Show glow rings around logged/saved sites
        public static var showClusterCounts = true         // Show number inside cluster circles
        public static var enableZoomResponsiveSizing = true // Markers scale with zoom level
        public static var enableSpringAnimations = true    // Use spring physics for camera moves
    }

    // MARK: - Clustering
    // CUSTOMIZE: Edit these to change clustering behavior
    public struct Clustering {
        public static var clusterRadius: Int = 80          // Pixels within which points cluster (increased for better grouping)
        public static var maxClusterZoom: Double = 12      // Stop clustering at this zoom level
        public static var minPointsToCluster: Int = 2      // Minimum points to form a cluster
    }
}
