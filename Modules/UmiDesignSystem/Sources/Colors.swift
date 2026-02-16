import SwiftUI

public extension Color {
    // MARK: - Core Underwater Palette (Ocean Blue Theme)
    static let abyss = Color(hex: "0A2342")       // Deep ocean blue (was nearly black)
    static let midnight = Color(hex: "0D3B66")    // Rich midnight blue
    static let trench = Color(hex: "1A4068")      // Medium ocean depth
    static let ocean = Color(hex: "1E5688")       // Ocean blue
    static let lagoon = Color(hex: "2D7FBF")
    static let reef = Color(hex: "5EEAD4")
    static let amber = Color(hex: "F59E0B")
    static let danger = Color(hex: "EF4444")
    static let foam = Color(hex: "E6ECF4")
    static let mist = Color(hex: "95A3B8")
    static let kelp = Color(hex: "1B3353")
    static let glass = Color(.sRGB, red: 8.0/255.0, green: 13.0/255.0, blue: 25.0/255.0, opacity: 0.62)

    // MARK: - Core Underwater Palette (Light)
    static let sand = Color(hex: "F3F8FF")
    static let shore = Color(hex: "EAF4FF")
    static let drift = Color(hex: "D7E9FB")
    static let ocean600 = Color(hex: "1E4B7A")
    static let lagoon500 = Color(hex: "2D7FBF")
    static let foam900 = Color(hex: "0B1220")
    static let mist700 = Color(hex: "586174")

    // MARK: - Status & Difficulty Colors
    static let statusLogged = reef
    static let statusSaved = Color(hex: "60A5FA")
    static let statusPlanned = amber
    static let statusDanger = danger

    // MARK: - Resy-Style Water Depth Ramp
    static let waterSurface = Color(hex: "08141A")   // Deepest dark (new background)
    static let waterShallow = Color(hex: "0B2B33")   // Shallow water tint
    static let waterMid = Color(hex: "0A2238")       // Mid-depth water
    static let waterDeep = Color(hex: "0A0F2A")      // Deep water (indigo)
    static let landBase = Color(hex: "141816")       // Land mass fill

    // MARK: - Resy-Style Pin States
    static let pinDefault = Color(hex: "35C2E0")     // Cool cyan - undiscovered
    static let pinVisited = Color(hex: "2FD7B8")     // Green-teal - logged dives
    static let pinFavorite = Color(hex: "F2C14E")    // Gold - wishlist/saved

    // MARK: - Site Type Accents
    static let reefAccent = Color(hex: "2BAA9B")     // Muted aqua-green
    static let wreckAccent = Color(hex: "C98B2B")    // Muted amber
    static let hazardAccent = Color(hex: "FF8A3D")   // Orange warning

    static let difficultyBeginner = Color(hex: "3DDC97")
    static let difficultyIntermediate = Color(hex: "60A5FA")
    static let difficultyAdvanced = Color(hex: "FBBF24")
    static let difficultyExpert = danger

    // MARK: - Legacy Aliases
    static let oceanBlue = lagoon
    static var diveTeal: Color { reef }
    static let seaGreen = Color(hex: "16A34A")
    static let divePurple = Color(hex: "9333EA")
    static let coralRed = danger
    @available(*, deprecated, renamed: "waterDeep", message: "Use Resy-style waterDeep instead")
    static let waterDeepLegacy = midnight
    static let waterAccent = ocean

    // MARK: - Semantic Helpers
    static var primary: Color { lagoon }
    static var secondary: Color { reef }

    static var textPrimaryOnDark: Color { foam }
    static var textSecondaryOnDark: Color { mist }

    // MARK: - Helper
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview("Color Palette") {
    VStack(spacing: 16) {
        Group {
            ColorSwatch(color: .lagoon, name: "Lagoon")
            ColorSwatch(color: .reef, name: "Reef")
            ColorSwatch(color: .amber, name: "Amber")
            ColorSwatch(color: .mist, name: "Mist")
            ColorSwatch(color: .glass, name: "Glass")
        }
    }
    .padding()
}

private struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text("Sample text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
