import Foundation
import GRDB

public struct DiveProfileSample: Codable, Hashable {
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

public struct DiveProfile: Codable, Identifiable, FetchableRecord, PersistableRecord, Hashable {
    public enum Source: String, Codable, CaseIterable, DatabaseValueConvertible {
        case shearwater
        case suunto
        case garmin
        case manual
        case importFile = "import_file"
        case unknown
    }

    public static let databaseTableName = "dive_profiles"

    public let id: String
    public let diveId: String
    public let samples: Data
    public let sampleIntervalSec: Int?
    public let sampleCount: Int
    public let source: Source
    public let computerSerial: String?
    public let computerModel: String?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        diveId: String,
        samples: Data,
        sampleIntervalSec: Int? = nil,
        sampleCount: Int,
        source: Source = .unknown,
        computerSerial: String? = nil,
        computerModel: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.diveId = diveId
        self.samples = samples
        self.sampleIntervalSec = sampleIntervalSec
        self.sampleCount = sampleCount
        self.source = source
        self.computerSerial = computerSerial
        self.computerModel = computerModel
        self.createdAt = createdAt
    }

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let diveId = Column(CodingKeys.diveId)
        static let samples = Column(CodingKeys.samples)
        static let sampleIntervalSec = Column(CodingKeys.sampleIntervalSec)
        static let sampleCount = Column(CodingKeys.sampleCount)
        static let source = Column(CodingKeys.source)
        static let computerSerial = Column(CodingKeys.computerSerial)
        static let computerModel = Column(CodingKeys.computerModel)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    public static func encodeSamples(_ samples: [DiveProfileSample]) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(samples)
    }

    public static func decodeSamples(from data: Data) throws -> [DiveProfileSample] {
        let decoder = JSONDecoder()
        return try decoder.decode([DiveProfileSample].self, from: data)
    }
}

extension DiveProfile {
    public static let dive = belongsTo(DiveLog.self)
}
