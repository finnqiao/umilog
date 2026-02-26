import Foundation
import GRDB

public enum CertAgency: String, Codable, CaseIterable, DatabaseValueConvertible {
    case padi = "PADI"
    case ssi = "SSI"
    case naui = "NAUI"
    case bsac = "BSAC"
    case cmas = "CMAS"
    case gue = "GUE"
    case tdi = "TDI"
    case iantd = "IANTD"
    case other = "Other"

    public var displayName: String { rawValue }

    public var commonLevels: [String] {
        switch self {
        case .padi:
            return [
                "Open Water Diver",
                "Advanced Open Water Diver",
                "Rescue Diver",
                "Divemaster",
                "Instructor"
            ]
        case .ssi:
            return [
                "Open Water Diver",
                "Advanced Adventurer",
                "Stress & Rescue",
                "Dive Guide",
                "Instructor"
            ]
        case .naui:
            return [
                "Scuba Diver",
                "Advanced Scuba Diver",
                "Master Scuba Diver",
                "Instructor"
            ]
        case .bsac:
            return [
                "Ocean Diver",
                "Sports Diver",
                "Dive Leader",
                "Advanced Diver",
                "Instructor"
            ]
        case .cmas:
            return [
                "One Star Diver",
                "Two Star Diver",
                "Three Star Diver",
                "One Star Instructor"
            ]
        case .gue:
            return [
                "Recreational Diver 1",
                "Recreational Diver 2",
                "Fundamentals",
                "Tech 1"
            ]
        case .tdi:
            return [
                "Advanced Nitrox",
                "Decompression Procedures",
                "Intro to Tech",
                "Extended Range"
            ]
        case .iantd:
            return [
                "Advanced Nitrox Diver",
                "Technical Diver",
                "Advanced Recreational Trimix",
                "Instructor"
            ]
        case .other:
            return []
        }
    }
}

public struct Certification: Codable, Identifiable, Hashable {
    public let id: String
    public let agency: CertAgency
    public let agencyOther: String?
    public let level: String
    public let certNumber: String?
    public let certDate: Date?
    public let expiryDate: Date?
    public let instructorName: String?
    public let instructorNumber: String?
    public let divesAtCert: Int?
    public let cardImageFront: String?
    public let cardImageBack: String?
    public let notes: String?
    public let isPrimary: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        agency: CertAgency,
        agencyOther: String? = nil,
        level: String,
        certNumber: String? = nil,
        certDate: Date? = nil,
        expiryDate: Date? = nil,
        instructorName: String? = nil,
        instructorNumber: String? = nil,
        divesAtCert: Int? = nil,
        cardImageFront: String? = nil,
        cardImageBack: String? = nil,
        notes: String? = nil,
        isPrimary: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.agency = agency
        self.agencyOther = agencyOther
        self.level = level
        self.certNumber = certNumber
        self.certDate = certDate
        self.expiryDate = expiryDate
        self.instructorName = instructorName
        self.instructorNumber = instructorNumber
        self.divesAtCert = divesAtCert
        self.cardImageFront = cardImageFront
        self.cardImageBack = cardImageBack
        self.notes = notes
        self.isPrimary = isPrimary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Certification: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "certifications"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let agency = Column(CodingKeys.agency)
        static let agencyOther = Column(CodingKeys.agencyOther)
        static let level = Column(CodingKeys.level)
        static let certNumber = Column(CodingKeys.certNumber)
        static let certDate = Column(CodingKeys.certDate)
        static let expiryDate = Column(CodingKeys.expiryDate)
        static let instructorName = Column(CodingKeys.instructorName)
        static let instructorNumber = Column(CodingKeys.instructorNumber)
        static let divesAtCert = Column(CodingKeys.divesAtCert)
        static let cardImageFront = Column(CodingKeys.cardImageFront)
        static let cardImageBack = Column(CodingKeys.cardImageBack)
        static let notes = Column(CodingKeys.notes)
        static let isPrimary = Column(CodingKeys.isPrimary)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}
