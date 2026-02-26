import Foundation

public struct PairedDevice: Codable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let brand: DiveComputerBrand
    public let serialNumber: String?
    public let pairedAt: Date
    public let lastSyncedAt: Date?

    public init(
        id: UUID,
        name: String,
        brand: DiveComputerBrand,
        serialNumber: String? = nil,
        pairedAt: Date = Date(),
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.serialNumber = serialNumber
        self.pairedAt = pairedAt
        self.lastSyncedAt = lastSyncedAt
    }

    public func withLastSyncedAt(_ date: Date?) -> PairedDevice {
        PairedDevice(
            id: id,
            name: name,
            brand: brand,
            serialNumber: serialNumber,
            pairedAt: pairedAt,
            lastSyncedAt: date
        )
    }
}
