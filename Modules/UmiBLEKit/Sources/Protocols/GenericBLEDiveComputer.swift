import Foundation

public enum DiveComputerProtocolError: Error {
    case unsupported
}

public final class GenericBLEDiveComputer: DiveComputerProtocol {
    public let brand: DiveComputerBrand = .unknown

    public init() {}

    public func requestDiveHeaders(from connection: DiveComputerConnection) async throws -> [DiveHeader] {
        _ = connection
        return []
    }

    public func downloadDive(index: Int, from connection: DiveComputerConnection) async throws -> RawDiveData {
        _ = index
        _ = connection
        throw DiveComputerProtocolError.unsupported
    }

    public func downloadAllNewDives(
        since lastSync: Date?,
        from connection: DiveComputerConnection
    ) async throws -> [RawDiveData] {
        _ = lastSync
        _ = connection
        return []
    }
}
