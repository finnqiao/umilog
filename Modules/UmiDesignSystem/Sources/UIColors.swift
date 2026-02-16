import UIKit
import SwiftUI

// MARK: - UIColor Bridge for MapLibre
// Why: MapLibre uses UIKit/UIColor, but our design system is SwiftUI Color-based.
// This bridge ensures consistency without duplication.
// The 'umi' prefix prevents namespace collisions with system UIColors.

public extension UIColor {
    // MARK: - Core Underwater Palette (Dark-first)
    // CUSTOMIZE: Edit these to change the base map color scheme
    static let umiAbyss = UIColor(Color.abyss)           // #0A0F1F - Deepest dark
    static let umiMidnight = UIColor(Color.midnight)     // #0D2239 - Dark blue
    static let umiTrench = UIColor(Color.trench)         // #132A45 - Medium dark
    static let umiOcean = UIColor(Color.ocean)           // #1E4B7A - Ocean blue
    static let umiLagoon = UIColor(Color.lagoon)         // #2D7FBF - Primary blue
    static let umiReef = UIColor(Color.reef)             // #5EEAD4 - Teal accent
    static let umiAmber = UIColor(Color.amber)           // #F59E0B - Warning/planned
    static let umiDanger = UIColor(Color.danger)         // #EF4444 - Error/expert
    static let umiFoam = UIColor(Color.foam)             // #E6ECF4 - Light text
    static let umiMist = UIColor(Color.mist)             // #95A3B8 - Secondary text
    static let umiKelp = UIColor(Color.kelp)             // #1B3353 - Dark accent

    // MARK: - Status Colors
    // CUSTOMIZE: Edit these to change how logged/saved/planned sites appear
    static let umiStatusLogged = UIColor(Color.statusLogged)     // Reef teal
    static let umiStatusSaved = UIColor(Color.statusSaved)       // #60A5FA - Blue
    static let umiStatusPlanned = UIColor(Color.statusPlanned)   // Amber

    // MARK: - Difficulty Colors
    // CUSTOMIZE: Edit these to change difficulty level indicators
    static let umiDifficultyBeginner = UIColor(Color.difficultyBeginner)         // #3DDC97 - Green
    static let umiDifficultyIntermediate = UIColor(Color.difficultyIntermediate) // #60A5FA - Blue
    static let umiDifficultyAdvanced = UIColor(Color.difficultyAdvanced)         // #FBBF24 - Yellow
    static let umiDifficultyExpert = UIColor(Color.difficultyExpert)             // #EF4444 - Red

    // MARK: - Resy-Style Water Depth Ramp
    static let umiWaterSurface = UIColor(Color.waterSurface)   // #08141A - Deepest dark
    static let umiWaterShallow = UIColor(Color.waterShallow)   // #0B2B33 - Shallow water
    static let umiWaterMid = UIColor(Color.waterMid)           // #0A2238 - Mid-depth
    static let umiWaterDeep = UIColor(Color.waterDeep)         // #0A0F2A - Deep water
    static let umiLandBase = UIColor(Color.landBase)           // #141816 - Land fill

    // MARK: - Resy-Style Pin States
    static let umiPinDefault = UIColor(Color.pinDefault)       // #35C2E0 - Undiscovered
    static let umiPinVisited = UIColor(Color.pinVisited)       // #2FD7B8 - Logged dives
    static let umiPinFavorite = UIColor(Color.pinFavorite)     // #F2C14E - Wishlist

    // MARK: - Site Type Accents
    static let umiReefAccent = UIColor(Color.reefAccent)       // #2BAA9B - Reef overlay
    static let umiWreckAccent = UIColor(Color.wreckAccent)     // #C98B2B - Wreck marker
    static let umiHazardAccent = UIColor(Color.hazardAccent)   // #FF8A3D - Hazard warning

    // MARK: - Legacy Aliases
    static let umiOceanBlue = umiLagoon
    static let umiDiveTeal = umiReef
}
