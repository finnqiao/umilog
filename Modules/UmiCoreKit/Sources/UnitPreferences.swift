import Foundation

/// User preferences for measurement units.
/// Stored via @AppStorage for persistence across sessions.
public enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius = "°C"
    case fahrenheit = "°F"

    public var id: String { rawValue }

    public func display(from celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return celsius * 9.0 / 5.0 + 32.0
        }
    }

    public func toCelsius(from value: Double) -> Double {
        switch self {
        case .celsius: return value
        case .fahrenheit: return (value - 32.0) * 5.0 / 9.0
        }
    }
}

public enum DistanceUnit: String, CaseIterable, Identifiable {
    case meters = "m"
    case feet = "ft"

    public var id: String { rawValue }

    public func display(from meters: Double) -> Double {
        switch self {
        case .meters: return meters
        case .feet: return meters * 3.28084
        }
    }

    public func toMeters(from value: Double) -> Double {
        switch self {
        case .meters: return value
        case .feet: return value / 3.28084
        }
    }
}

/// Keys for @AppStorage
public enum UnitPreferenceKeys {
    public static let temperatureUnit = "preferred_temperature_unit"
    public static let distanceUnit = "preferred_distance_unit"
}
