import Foundation
import CoreLocation

public struct GasMix: Codable, Hashable {
    public let o2Percent: Double
    public let hePercent: Double
    public let switchDepth: Double?
    public let isActive: Bool

    public init(
        o2Percent: Double,
        hePercent: Double = 0,
        switchDepth: Double? = nil,
        isActive: Bool = true
    ) {
        self.o2Percent = o2Percent
        self.hePercent = hePercent
        self.switchDepth = switchDepth
        self.isActive = isActive
    }
}

public struct DepthSample: Codable, Hashable {
    public let time: TimeInterval
    public let depth: Double
    public let temperature: Double?
    public let pressure: Double?

    public init(
        time: TimeInterval,
        depth: Double,
        temperature: Double? = nil,
        pressure: Double? = nil
    ) {
        self.time = time
        self.depth = depth
        self.temperature = temperature
        self.pressure = pressure
    }
}

public struct DecoStop: Codable, Hashable {
    public let depth: Double
    public let duration: TimeInterval

    public init(depth: Double, duration: TimeInterval) {
        self.depth = depth
        self.duration = duration
    }
}

public struct RawDiveData: Codable, Hashable {
    public let computerSerial: String
    public let computerModel: String?
    public let diveNumber: Int
    public let date: Date
    public let duration: TimeInterval
    public let maxDepth: Double
    public let avgDepth: Double?
    public let minTemperature: Double
    public let surfaceTemperature: Double?
    public let startPressure: Double?
    public let endPressure: Double?
    public let gasMixes: [GasMix]
    public let depthProfile: [DepthSample]
    public let decoStops: [DecoStop]?
    public let safetyStopPerformed: Bool
    public let surfaceInterval: TimeInterval?
    public let algorithm: String?
    public let gfLow: Int?
    public let gfHigh: Int?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        computerSerial: String,
        computerModel: String? = nil,
        diveNumber: Int,
        date: Date,
        duration: TimeInterval,
        maxDepth: Double,
        avgDepth: Double? = nil,
        minTemperature: Double,
        surfaceTemperature: Double? = nil,
        startPressure: Double? = nil,
        endPressure: Double? = nil,
        gasMixes: [GasMix] = [],
        depthProfile: [DepthSample] = [],
        decoStops: [DecoStop]? = nil,
        safetyStopPerformed: Bool = false,
        surfaceInterval: TimeInterval? = nil,
        algorithm: String? = nil,
        gfLow: Int? = nil,
        gfHigh: Int? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.computerSerial = computerSerial
        self.computerModel = computerModel
        self.diveNumber = diveNumber
        self.date = date
        self.duration = duration
        self.maxDepth = maxDepth
        self.avgDepth = avgDepth
        self.minTemperature = minTemperature
        self.surfaceTemperature = surfaceTemperature
        self.startPressure = startPressure
        self.endPressure = endPressure
        self.gasMixes = gasMixes
        self.depthProfile = depthProfile
        self.decoStops = decoStops
        self.safetyStopPerformed = safetyStopPerformed
        self.surfaceInterval = surfaceInterval
        self.algorithm = algorithm
        self.gfLow = gfLow
        self.gfHigh = gfHigh
        self.latitude = latitude
        self.longitude = longitude
    }

    public var location: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
