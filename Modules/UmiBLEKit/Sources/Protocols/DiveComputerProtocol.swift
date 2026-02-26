import Foundation

public struct DiveHeader: Codable, Hashable, Identifiable {
    public let id: String
    public let diveNumber: Int
    public let date: Date
    public let duration: TimeInterval
    public let maxDepth: Double

    public init(
        id: String = UUID().uuidString,
        diveNumber: Int,
        date: Date,
        duration: TimeInterval,
        maxDepth: Double
    ) {
        self.id = id
        self.diveNumber = diveNumber
        self.date = date
        self.duration = duration
        self.maxDepth = maxDepth
    }
}

public protocol DiveComputerProtocol {
    var brand: DiveComputerBrand { get }

    func requestDiveHeaders(from connection: DiveComputerConnection) async throws -> [DiveHeader]
    func downloadDive(index: Int, from connection: DiveComputerConnection) async throws -> RawDiveData
    func downloadAllNewDives(
        since lastSync: Date?,
        from connection: DiveComputerConnection
    ) async throws -> [RawDiveData]
}
