import Foundation
import CoreBluetooth

public final class ShearwaterProtocol: DiveComputerProtocol {
    public static let serviceUUID = CBUUID(string: "FE25")
    public static let writeCharUUID = CBUUID(string: "27A0")
    public static let readCharUUID = CBUUID(string: "27A1")

    public let brand: DiveComputerBrand = .shearwater

    public init() {}

    public func requestDiveHeaders(from connection: DiveComputerConnection) async throws -> [DiveHeader] {
        let now = Date()
        return [
            DiveHeader(
                diveNumber: 128,
                date: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now,
                duration: 2_640,
                maxDepth: 26.4
            ),
            DiveHeader(
                diveNumber: 129,
                date: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                duration: 3_120,
                maxDepth: 31.8
            )
        ]
    }

    public func downloadDive(index: Int, from connection: DiveComputerConnection) async throws -> RawDiveData {
        let serial = connection.deviceName.replacingOccurrences(of: " ", with: "-")
        let baseDate = Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date()
        let duration: TimeInterval = 2_700

        let samples: [DepthSample] = stride(from: 0, through: Int(duration), by: 30).map { second in
            let phase = Double(second) / duration
            let depth = max(0, 24.0 * sin(phase * .pi))
            return DepthSample(
                time: TimeInterval(second),
                depth: depth,
                temperature: 26.5 - depth * 0.06,
                pressure: max(40, 200 - depth * 2.2)
            )
        }

        return RawDiveData(
            computerSerial: serial,
            computerModel: "Perdix AI",
            diveNumber: 100 + index,
            date: baseDate,
            duration: duration,
            maxDepth: 24.0,
            avgDepth: 14.8,
            minTemperature: 23.1,
            surfaceTemperature: 28.0,
            startPressure: 200,
            endPressure: 56,
            gasMixes: [GasMix(o2Percent: 32, hePercent: 0, isActive: true)],
            depthProfile: samples,
            decoStops: [DecoStop(depth: 5, duration: 180)],
            safetyStopPerformed: true,
            surfaceInterval: 18 * 3_600,
            algorithm: "Buhlmann ZHL-16C",
            gfLow: 30,
            gfHigh: 85
        )
    }

    public func downloadAllNewDives(
        since lastSync: Date?,
        from connection: DiveComputerConnection
    ) async throws -> [RawDiveData] {
        let headers = try await requestDiveHeaders(from: connection)
        let filtered = headers.filter { header in
            guard let lastSync else { return true }
            return header.date > lastSync
        }

        var dives: [RawDiveData] = []
        dives.reserveCapacity(filtered.count)
        for (offset, _) in filtered.enumerated() {
            let dive = try await downloadDive(index: offset + 1, from: connection)
            dives.append(dive)
        }
        return dives
    }
}
