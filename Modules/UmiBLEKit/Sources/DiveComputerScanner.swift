import Foundation
import CoreBluetooth

public struct DiveComputerScanner {
    public static let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FE25")
    ]

    public init() {}

    public func brand(
        from peripheralName: String?,
        serviceUUIDs: [CBUUID]
    ) -> DiveComputerBrand {
        let normalizedName = (peripheralName ?? "").lowercased()
        if normalizedName.contains("shearwater") || serviceUUIDs.contains(CBUUID(string: "FE25")) {
            return .shearwater
        }
        if normalizedName.contains("suunto") {
            return .suunto
        }
        if normalizedName.contains("garmin") || normalizedName.contains("descent") {
            return .garmin
        }
        return .unknown
    }

    public func makeDevice(
        from peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber,
        isPaired: Bool
    ) -> BLEDiveComputer {
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let brand = brand(from: peripheral.name, serviceUUIDs: services)
        return BLEDiveComputer(
            id: peripheral.identifier,
            name: peripheral.name ?? "Unknown Device",
            brand: brand,
            rssi: rssi.intValue,
            isPaired: isPaired
        )
    }
}
