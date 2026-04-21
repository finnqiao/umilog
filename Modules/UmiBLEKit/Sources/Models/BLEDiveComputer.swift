import Foundation

public enum DiveComputerBrand: String, Codable, CaseIterable {
    case shearwater
    case suunto
    case garmin
    case unknown

    public var displayName: String {
        switch self {
        case .shearwater: return "Shearwater"
        case .suunto: return "Suunto"
        case .garmin: return "Garmin"
        case .unknown: return "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .shearwater: return "water.waves"
        case .suunto: return "figure.open.water.swim"
        case .garmin: return "location.north.line"
        case .unknown: return "dot.radiowaves.left.and.right"
        }
    }
}

public struct BLEDiveComputer: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let brand: DiveComputerBrand
    public let rssi: Int
    public let isPaired: Bool

    public init(
        id: UUID,
        name: String,
        brand: DiveComputerBrand,
        rssi: Int,
        isPaired: Bool
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.rssi = rssi
        self.isPaired = isPaired
    }
}

public struct SyncProgress: Hashable {
    public let stage: String
    public let fractionCompleted: Double

    public init(stage: String, fractionCompleted: Double) {
        self.stage = stage
        self.fractionCompleted = min(1.0, max(0.0, fractionCompleted))
    }
}
