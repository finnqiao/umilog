import Foundation
import GRDB

public enum GearCategory: String, Codable, CaseIterable, DatabaseValueConvertible {
    case regulator
    case bcd
    case computer
    case tank
    case wetsuit
    case drysuit
    case fins
    case mask
    case light
    case camera
    case spoolReel = "spool_reel"
    case smb
    case other

    public var defaultServiceIntervalMonths: Int? {
        switch self {
        case .regulator, .bcd, .tank, .drysuit:
            return 12
        case .computer:
            return 18
        case .light:
            return 6
        case .wetsuit, .fins, .mask, .camera, .spoolReel, .smb, .other:
            return nil
        }
    }

    public var displayName: String {
        switch self {
        case .bcd:
            return "BCD"
        case .smb:
            return "SMB"
        case .spoolReel:
            return "Spool/Reel"
        default:
            return rawValue.capitalized
        }
    }

    public var systemImage: String {
        switch self {
        case .regulator:
            return "gauge.with.dots.needle.bottom.50percent"
        case .bcd:
            return "figure.open.water.swim"
        case .computer:
            return "applewatch"
        case .tank:
            return "cylinder"
        case .wetsuit, .drysuit:
            return "tshirt"
        case .fins:
            return "figure.open.water.swim"
        case .mask:
            return "eyes"
        case .light:
            return "flashlight.on.fill"
        case .camera:
            return "camera"
        case .spoolReel:
            return "circle.dotted"
        case .smb:
            return "sos"
        case .other:
            return "wrench.and.screwdriver"
        }
    }
}

public struct GearItem: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let category: GearCategory
    public let brand: String?
    public let model: String?
    public let serialNumber: String?
    public let purchaseDate: Date?
    public let lastServiceDate: Date?
    public let nextServiceDate: Date?
    public let serviceIntervalMonths: Int?
    public let notes: String?
    public let isActive: Bool
    public let totalDiveCount: Int
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        category: GearCategory,
        brand: String? = nil,
        model: String? = nil,
        serialNumber: String? = nil,
        purchaseDate: Date? = nil,
        lastServiceDate: Date? = nil,
        nextServiceDate: Date? = nil,
        serviceIntervalMonths: Int? = nil,
        notes: String? = nil,
        isActive: Bool = true,
        totalDiveCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.brand = brand
        self.model = model
        self.serialNumber = serialNumber
        self.purchaseDate = purchaseDate
        self.lastServiceDate = lastServiceDate
        self.nextServiceDate = nextServiceDate
        self.serviceIntervalMonths = serviceIntervalMonths ?? category.defaultServiceIntervalMonths
        self.notes = notes
        self.isActive = isActive
        self.totalDiveCount = totalDiveCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension GearItem: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "gear_items"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let category = Column(CodingKeys.category)
        static let brand = Column(CodingKeys.brand)
        static let model = Column(CodingKeys.model)
        static let serialNumber = Column(CodingKeys.serialNumber)
        static let purchaseDate = Column(CodingKeys.purchaseDate)
        static let lastServiceDate = Column(CodingKeys.lastServiceDate)
        static let nextServiceDate = Column(CodingKeys.nextServiceDate)
        static let serviceIntervalMonths = Column(CodingKeys.serviceIntervalMonths)
        static let notes = Column(CodingKeys.notes)
        static let isActive = Column(CodingKeys.isActive)
        static let totalDiveCount = Column(CodingKeys.totalDiveCount)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

extension GearItem {
    public static let diveGear = hasMany(DiveGear.self)
    public static let dives = hasMany(DiveLog.self, through: diveGear, using: DiveGear.dive)
}
