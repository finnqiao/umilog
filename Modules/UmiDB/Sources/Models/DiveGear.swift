import Foundation
import GRDB

public struct DiveGear: Codable, FetchableRecord, PersistableRecord, Hashable {
    public static let databaseTableName = "dive_gear"

    public let diveId: String
    public let gearId: String

    public init(diveId: String, gearId: String) {
        self.diveId = diveId
        self.gearId = gearId
    }

    public enum Columns {
        static let diveId = Column(CodingKeys.diveId)
        static let gearId = Column(CodingKeys.gearId)
    }
}

extension DiveGear {
    public static let dive = belongsTo(DiveLog.self)
    public static let gear = belongsTo(GearItem.self)
}
