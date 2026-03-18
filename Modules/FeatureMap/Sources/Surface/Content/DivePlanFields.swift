import Foundation

/// Optional dive planning fields for a planned site in a trip.
struct DivePlanFields {
    var targetDepth: Double?
    var plannedBottomTime: Double?
    var gasMix: GasMix = .air
    var surfaceInterval: Double?

    enum GasMix: String, CaseIterable, Identifiable {
        case air = "Air"
        case ean32 = "EAN32"
        case ean36 = "EAN36"

        var id: String { rawValue }
    }
}
